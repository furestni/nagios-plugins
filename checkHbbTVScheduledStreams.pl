#!/usr/bin/perl
# ============================================================================
# Check HbbTV Scheduled Streams
# -----------------------------
#
# ============================================================================
use Getopt::Long;
use Pod::Usage;
use REST::Client;
use JSON;
use MIME::Base64; 
use Data::Dumper;
use POSIX qw(strftime);
use URI::Escape;
use warnings;
use strict;

# ----------------------------------------------------------------------------
# Global Vars
# ----------------------------------------------------------------------------
my @now = localtime;
my $tsNow;
my %opt;
my $msg = "?";
my $rc = 3;
my $result_code;
my $resultMsg = "UNKNOWN";
my $schedule_ref;
my $apiOpt_ref;

# ----------------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------------
$opt{'debug'} = 0;
$opt{'verbose'} = 0;
$opt{'livevonly'} = 0;
$opt{'scheduleDays'} = 1;

# time to "YYYY-MM-DDTHH:MM:SS+ZZ:ZZ" format
# ------------------------------------------
sub genTimeStr(@) {
    my @t = @_;

    my ($tz,$ts);

    $tz = strftime ("%z", @t);
    $ts = strftime ("%FT%T", @t);
    $tz =~ s/(\d\d)(\d\d)/$1:$2/; # TZ Format from 0000 to 00:00

    return $ts.$tz;
}

# check if current time is withing event schedule
# -----------------------------------------------
sub isEventNow($$$) {
    my ($eventStart,$eventEnd,$timeNow) = @_;

    return (($timeNow ge $eventStart) && ($timeNow lt $eventEnd));
}

# Fetch JSON Data from URL
# -------------------------------------
sub fetchJSONData($$$$$$) {
	my ($server,$path,$options,$user,$passwd,$debug) = @_;

	my $headers;
	my $paramStr = "";
	my @param;

	$headers->{"Accept"} = 'application/json';
	if (defined($user) && defined($passwd)) {
		$headers->{"Authorization"} = 'Basic ' . encode_base64($user . ':' . $passwd);
	}

	if (defined($options)) {
		foreach my $k (keys($options)) {
			push @param, sprintf "%s=%s", $k, uri_escape($options->{$k});
		}
		$paramStr = "?".join("&", @param);
	}

	printf "Get Data from: %s\n", $server.$path.$paramStr if ($debug);

	my $client = REST::Client->new({ host => $server });

	$client->GET($path.$paramStr, $headers);

	print $client->responseCode,"\n",$client->responseContent(),"\n" if ($debug);

	return (
		$client->responseCode,
		$client->responseCode == 200 ? from_json($client->responseContent()) : undef
	);
}

# Check Stream is online on Edge Server
# -------------------------------------
sub checkStreamStatus($$$) {
	my ($server,$path,$debug) = @_;

	my $headers;
	$headers->{"Accept"} = '*/*';

	my $client = REST::Client->new({ host => $server });

	$client->GET($path, $headers);

	print $client->responseCode,"\n",$client->responseContent(),"\n" if ($debug);

	return ($client->responseCode);
}

# list Events 
# -----------
sub listEvents($) {
	my ($events) = @_;
	my $state = "";

	if ($opt{'livevonly'} == 0) {
		printf "Event(s) Scheduled: %d\n", scalar @{$events};
	} else {
		if (scalar @{$events} > 0) {
			printf "Event(s) currently live: %d\n", scalar @{$events};
		} else {
			print "No Events live at the moment.\n";
		}
	}
	foreach my $e (@{$events}) {

		if (defined($e->{'checkIsNowOnline'})) {
			$state = $e->{'checkIsNowOnline'} ? "Live" : "Scheduled";
			$state .= defined($e->{'checkResult'}) ? ", ".$e->{'checkResult'} : "";
		} 
		printf "%s - %s %-55s %s %-50s %s\n",
			$e->{'startDate'},
			$e->{'endDate'},
			$e->{'encoder'},
			$e->{'businessUnit'},
			$e->{'title'},
			$state
	}
}

# generate Icinga Result Line with perf data and return code
# ----------------------------------------------------------
sub icingaResult($) {
	my ($events) = @_;

	my $eventsScheduled = 0;
	my $eventsLive = 0;
	my $eventStreamOnline = 0;
	my %perf;
	my @perfList;
	my @missing;
	my @live;
	my $result;

	$eventsScheduled = scalar @{$events};
	foreach my $e (@{$events}) {
		$perf{$e->{'checkStream'}} = 0 unless defined($perf{$e->{'checkStream'}}); # do not overwrite if same stream is scheduled later again...
		if ($e->{'checkIsNowOnline'}) {
			$eventsLive++;
			$perf{$e->{'checkStream'}}++;
			push @live, $e->{'checkStream'};
			if ($e->{'checkResult'} eq "Online") {
				$eventStreamOnline++;
				$perf{$e->{'checkStream'}}++;
			} else {
				push @missing, $e->{'checkStream'};
			}
		}
	}

	# Prepare Perf Data:
	foreach my $p (keys(%perf)) {
		push @perfList, sprintf("%s=%s",$p,$perf{$p});
	}
	push @perfList, sprintf("%s=%s", "scheduled", $eventsScheduled) if ($opt{'livevonly'} == 0);
	push @perfList, sprintf("%s=%s", "live", $eventsLive);
	push @perfList, sprintf("%s=%s", "online", $eventStreamOnline);

	# Output
	$result = "";
	if ($opt{'livevonly'} == 0) {
		$result = sprintf("%d event%s scheduled in the next %d day%s, ",
			$eventsScheduled,
			$eventsScheduled != 1 ? "s" : "",
			$opt{'scheduleDays'},
			$opt{'scheduleDays'} != 1 ? "s" : ""
		);
	}
	$result .= sprintf("%d event%s currently live %s, %d stream%s online on %s: %s | %s\n",
		$eventsLive,
		$eventsLive != 1 ? "s" : "",
		scalar @live == 0 ? "" : "(".join(" ", @live).")",
		$eventStreamOnline,
		$eventStreamOnline != 1 ? "s" : "",
		$opt{'streamserver'},
		$eventsLive == $eventStreamOnline ? "OK" : "Missing Stream(s):".join(" ", @missing),
		join(" ", @perfList)
	);

	return (
		$eventsLive == $eventStreamOnline ? 0 : 1,
		$result
	); 
}

# add required information to events
# ----------------------------------
sub addCheckInformation($$) {
	my ($events,$streamserver) = @_;

	foreach my $e (@{$events}) {
		$e->{'checkPath'}=$e->{'encoder'};
		$e->{'checkPath'}=~s!http://[^/]+/!/check/!;
		$e->{'checkPath'}=~ m/(stream.+)\.ts/;
		$e->{'checkStream'}=$1;

		$e->{'checkHost'}=$streamserver;
	}
	
	return $events;
}

# check events using information in event list
# --------------------------------------------
sub checkEvents($$) {
	my ($events,$tsNow) = @_;

	my $httpcode;

	foreach my $e (@{$events}) {

		$httpcode = checkStreamStatus ($e->{'checkHost'}, $e->{'checkPath'}, $opt{'debug'});

		$e->{'checkResult'} = $httpcode == 200 ? "Online" : $httpcode == 404 ? "Offline" : "Error";
		$e->{'checkIsNowOnline'} = isEventNow($e->{'startDate'}, $e->{'endDate'}, $tsNow);

		printf "Check %s %s returned %s and Stream is %s\n",
			$e->{'checkHost'},
			$e->{'checkPath'},
			$e->{'checkResult'},
			$e->{'checkIsNowOnline'} ? "Online" : "Offline" if $opt{'debug'};

	}
	return $events;
}


########
# MAIN #
########

GetOptions (
	"apiserver=s"	=> \$opt{'apiserver'},
	"apiuser=s"     => \$opt{'apiuser'},
	"apipass=s"     => \$opt{'apipass'},
	"streamserver=s"=> \$opt{'streamserver'},
	"path=s"        => \$opt{'path'},
	"verbose"       => \$opt{'verbose'},
	"liveonly!"		=> \$opt{'livevonly'},
	"scheduleDays=i"=> \$opt{'scheduleDays'},
	"debug"         => \$opt{'debug'},
	"help|?"        => \$opt{'help'},
	"man"           => \$opt{'man'},
) or pod2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

foreach my $o (qw(apiserver path streamserver)) {
	unless (defined($opt{$o})) {
		printf "--%s is required\n", $o;
		$rc = 1;
	}
}
exit 3 if $rc <3;

$tsNow = genTimeStr(@now);

$apiOpt_ref->{'from'} = $opt{'livevonly'} == 1 ? genTimeStr(localtime(time+60)) : $tsNow;
$apiOpt_ref->{'to'}   = $opt{'livevonly'} == 1 ? genTimeStr(localtime(time+300)) : genTimeStr(localtime(time+(60*60*24*$opt{'scheduleDays'})));
$apiOpt_ref->{'isLiveOnly'} = $opt{'livevonly'} == 1 ? "true" : "false";


($result_code, $schedule_ref) = fetchJSONData (
	$opt{'apiserver'}, 
	$opt{'path'},
	$apiOpt_ref,
	defined ($opt{'apiuser'}) ? $opt{'apiuser'} : undef,
	defined ($opt{'apipass'}) ? $opt{'apipass'} : undef,
	$opt{'debug'}
);

if ($result_code != 200) {
	$resultMsg = sprintf("status code %s from %s\n", $result_code, $opt{'apiserver'}.$opt{'path'});
	$rc = 3;
} else {
	listEvents ($schedule_ref) if $opt{'debug'};
	my $result = checkEvents(addCheckInformation($schedule_ref, $opt{'streamserver'}),$tsNow);

	listEvents($result) if $opt{'verbose'};

	#print to_json($result);
	print Dumper (\$result) if $opt{'debug'};

	($rc, $resultMsg) = icingaResult($result);
}

# Results:
print $resultMsg;
exit  $rc;

__END__

=head1 NAME

checkHbbTVScheduledStreams.pl -- check Scheduled HbbTV Streams

=head1 SYNOPSIS

 checkHbbTVScheduledStreams.pl [options]
 Options:
      --apiserver     API Servername for Schedulde (http://...)
      --path          API Path for Schedule
      --streamserver  Edge Server to check (IP/NAME)
      --scheduleDays  Days to check if there is something scheduled
      --livevonly     show only live events
      --user          user name for authentification
      --pass          password for authentification
      --verbose       verbose, what else?
      --debug         show REST API output
      --help          brief help message
      --man           full documentation

=head1 OPTIONS

=over 8

=item B<--apiserver>

API Servername for Schedulde (http://...)

=item B<--path>

API Path for Schedule

=item B<--livevonly>

show/check only live events
start time is now+60s end time+300s
if the stream is about the end it will not be checked.
scheduled events are not considered

=item B<--user>

user name for authentification (optional)

=item B<--pass>

password for authentification (optional)

=item B<--streamserver>

Edge Server to check (IP/NAME)

=item B<--scheduleDays>

Days to check if there is something scheduled.

=item B<--verbose>

Show the Schedule with test results in a table

=item B<--debug>

Some more Information for debugging only

=back

=head1 DESCRIPTION

checkHbbTVScheduledStreams.pl fetches scheduled streaming events an checks on a given edge streaming server that the stream is online, if it should be.

Output is for icinga with variable performance information about the streams scheduled with their status:
stream:
	0 = scheduled
	1 = live
	2 = live+online

	if the sum of live and online is not the same the return code is 1 and missing streams are listed instead of "OK".

e. g.
12 event(s) scheduled in the next 7 day(s), 0 currently live, 0 stream(s) online on 146.159.94.155: OK | stream21a=0 stream15=0 stream06=0 stream20a=0 stream14=0 stream20b=0 scheduled=12 live=0 online=0

=cut
