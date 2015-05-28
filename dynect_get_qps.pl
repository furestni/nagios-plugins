#!/usr/bin/perl

use RRD::Simple;
use JSON::XS;
use LWP::UserAgent;
use Statistics::Descriptive;
use Try::Tiny;
use Getopt::Long;
&Getopt::Long::config('bundling');

my $user;
my $password;
my $time=24;


usage_and_exit() unless
    GetOptions("h|help"           => \$opt_h,
               "u|user=s"    => \$user,
               "p|password=s"      => \$password,
               "t|time=i"     => \$time,
               );

usage_and_exit() if not $user or not $password;

sub login {

  # First lets setup the HTTP request for the session
  my $session_uri = 'https://api2.dynect.net/REST/Session';
  my $session_json = '{"customer_name": "SWISSTXT", "user_name": "'.$user.'", "password": "'.$password.'"}';
  my $session_req = HTTP::Request->new( 'POST', $session_uri );
  $session_req->header( 'Content-Type' => 'application/json' );
  $session_req->content( $session_json );

  # Now create a LWP agent and make the request
  my $session_lwp = LWP::UserAgent->new;
  $session_res = $session_lwp->request( $session_req );

  # decode the return json
  $session_output = decode_json($session_res->content);
  return $session_output;
}

sub logout {
  my $session = shift();
  # First lets setup the HTTP request for the session
  my $session_uri = 'https://api2.dynect.net/REST/Session';
  my $session_req = HTTP::Request->new( 'DELETE', $session_uri );
  $session_req->header( 'Content-Type' => 'application/json', 'Auth-Token' => $session->{data}->{token} );
  $session_req->content( $session_json );

  # Now create a LWP agent and make the request
  my $session_lwp = LWP::UserAgent->new;
  $session_res = $session_lwp->request( $session_req );

  # decode the return json
  $session_output = decode_json($session_res->content);
  return $session_output;
}


sub getdata($) {
  my $listing_uri = shift();

  my $listing_req = HTTP::Request->new( 'GET', $listing_uri );
  $listing_req->header( 'Content-Type' => 'application/json', 'Auth-Token' => $session_output->{'data'}->{'token'} );

  # Now create a LWP agent and make the request
  my $listing_lwp = LWP::UserAgent->new;
  $listing_res = $listing_lwp->request( $listing_req );

  # decode the return json
  $listing_output = decode_json($listing_res->content);
  return $listing_output;
}

sub get_qps {
  my $qps_uri = shift();
  $date_end = time();
  $date_start = $date_end - (3600 * $time) - 300;
#  $date_start = $date_end - (3600 * 24 * 2) - 300;
#  $date_start = $date_end - (3600) - 300;

  my $qps_req = HTTP::Request->new( 'POST', $qps_uri);
  #my $qps_json = '{"start_ts": "' . $date_start . '", "end_ts": "' . $date_end . '", "breakdown":["zones"]}';
  my $qps_json = '{"start_ts": "' . $date_start . '", "end_ts": "' . $date_end . '"}';
  $qps_req->header( 'Content-Type'=> 'application/json', 'Auth-Token' => $session_output->{'data'}->{'token'} );
  $qps_req->content($qps_json);

  # Now create a LWP agent and make the request
  my $qps_lwp = LWP::UserAgent->new;
  $qps_res = $qps_lwp->request( $qps_req );

  # decode the return json
  # $qps_output = decode_json($qps_res->content);
  # return $qps_output;
  try {
    $qps_output = decode_json($qps_res->content);
  } catch {
    print "Error fetching data from Dyn!";
    exit(3);
  };
  return $qps_output;
}

sub usage_and_exit
{
    print "Check_dynect_get_qps.pl\n";
    print "Usage: $0 -u username -p password [ options ]\n\n";
    print "Options:\n";
    print " -t time in hours\n";
    print "   Get QPS for the last n hours.\n";

    exit STATUS_UNKNOWN;
}

# login
#
my $session = login();
# if we did not succeed, print that and return
if($session->{'status'} ne 'success')
{
        print "Error on return from session connect";
        exit(1);
}

my $zones = get_qps('https://api2.dynect.net/REST/QPSReport/');
# if we did not succeed, print that and return
if($zones->{'status'} ne 'success')
{
        print "Error on return from zones";
        exit(1);
}

%date_hash = ();
foreach $zone_x ($zones->{'data'}) {
  foreach $zone_y (keys %$zone_x) {
    foreach $time_1 ($zone_x->{$zone_y}) {
      open my($fh), "<", \$time_1 or die "no data $!";
      while (<$fh>) {
        chomp();
        my ($time, $count) = split(/,/);
        $date_hash{$time} = $count if ($time =~ /\d\d/);
      }
    }
  }
}



#print $key . ":" . $date_hash{$key}/300;

my $myqps = 0;
my $warnlimit = $ARGV[0] || 90;
my $errorlimit = $ARGV[1] || 100;
my $indexnum = 0;

$stat = Statistics::Descriptive::Full->new();

#my $filename = "/tmp/test_qps.rrd";
my $filename = "/usr/local/pnp4nagios/var/perfdata/dyn_qps/dyn_qps.rrd";
my $my_size = scalar keys %date_hash;
foreach $date (sort keys %date_hash) {
  if ($indexnum < $my_size) {
    if (!-e $filename) {
      my $rrd = RRD::Simple->new(file => $filename);
      my @period = qw(day week month year 3years mrtg);
      $rrd->create($period[5], dnsreq => "GAUGE");
      $rrd->update($date,dnsreq => $date_hash{$date}/300);
      $stat->add_data($date_hash{$date}/300);
      $myqps += $date_hash{$date};
    }
    else {
       my $rrd = RRD::Simple->new(file => $filename);
       if ($rrd->last($filename) < $date) {
         $rrd->update($date,dnsreq => $date_hash{$date}/300);
      }
      $stat->add_data($date_hash{$date}/300);
      $myqps += $date_hash{$date};
    }
  }
  $indexnum++;
#  print $date . ":" . $date_hash{$date}/300 . "\n";
}

logout($session);

if ($stat->percentile(95) > $errorlimit) {
  print "QPS limit reached! " . sprintf("%.2f", $stat->percentile(95)) . " > " . $errorlimit;
  exit (1);
}
elsif ($stat->percentile(95) > $warnlimit) {
  print "QPS limit almost reached! " . sprintf("%.2f", $stat->percentile(95)) . " > " . $warnlimit;
  exit (1);
}
else {
  print "QPS import erfolgreich! 95 Percentile: " . sprintf("%.2f", $stat->percentile(95)) . " < " . $errorlimit;
  exit(0);
}
