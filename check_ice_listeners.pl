#!/usr/bin/perl

use strict;
use Getopt::Long;
use lib "/usr/lib/nagios/plugins";
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

my $stream = "/m/drs1/aacp_96";
my $uptime = '0 days';
my $listeners = 0;
my $sources = 0;
my $line = "";
my $newline = "";
my $listeners = 0;
my $sources = 0;
my $flag = 0;
my $output = "";
my $perfdata = "";
my $totallisteners = 0;
my $pass;
my $user;
my $hostname;

GetOptions(
        "H=s" => \$hostname, 
        "p=s" => \$pass,
        "u=s" => \$user
) or print_help();

my $staturl = "http://" . $hostname . "/admin/stats.xml";

#get listeners
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => $staturl);
$req->authorization_basic($user, $pass);
my $stats = $ua->request($req)->as_string;
my $stats2 = $ua->request($req);

if(!$stats2->is_success){
   print $stats2->content ."\n";
   exit 1;
}

my @page = split(/<source mount/, $stats);

foreach $line (@page) {
  if (($line =~ /<listeners>/) && $line !~ /icemaster\@localhost/) {
    ($sources,$newline) = (split(/">/, (split(/="/, $line))[1]));
    $listeners = (split(/<\/listeners>/, (split(/<listeners>/, $newline))[1]))[0];
    $totallisteners += $listeners;
    $output .= $sources . ": " . $listeners . " ";
    $sources =~ s/\//_/g;
    $perfdata .= $sources . "=" . $listeners . ", ";
  }
}

my $noutput = "total listeners = " . $totallisteners . " | total_listeners=" . $totallisteners;
print $noutput . "\n";;


sub print_help {
        printf "Plugin to monitor icecast sessions \n";
        printf "\nUsage:\n";
        printf "   -H Hostname\n";
        printf "   -p Password\n";
        printf "   -u Username\n";
        exit $ERRORS{'OK'};
}

