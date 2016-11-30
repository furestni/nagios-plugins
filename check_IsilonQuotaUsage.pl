#!/usr/bin/perl
# ============================================================================
# check_IsilonQuotaUsage.pl
# ---------------------------
# 
# ============================================================================

use REST::Client;
use JSON;
use MIME::Base64;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use warnings;
use strict;

# ----------------------------------------------------------------------------
# Global Vars
# ----------------------------------------------------------------------------
my %opt;
my $quota_ref;
my $msg = "?";
my $rc = 3;

# fetch data from isilon using REST API
# -------------------------------------
sub fetchData($$$$) {
    my ($isilon, $path, $auth, $debug) = @_;
    my $headers = {Accept => 'application/json', Authorization => 'Basic ' . $auth};
    my $client = REST::Client->new({ host => $isilon });

    $client->GET($path, $headers);

	print $client->responseCode,"\n",$client->responseContent(),"\n" if ($debug);
    return (
        $client->responseCode,
        $client->responseCode == 200 ? from_json($client->responseContent()) : undef
    );
}


########
# MAIN #
########

GetOptions (
    "isilon=s"		=> \$opt{'isilon'},
    "user=s"		=> \$opt{'user'},
    "pass=s"		=> \$opt{'pass'},
    "auth=s"		=> \$opt{'auth'},
    "path=s"		=> \$opt{'path'},
    "c|critical=i"	=> \$opt{'critical'},
    "w|warning=i"	=> \$opt{'warning'},
    "a|advisory=i"  => \$opt{'advisory'},
    "verbose"		=> \$opt{'verbose'},
    "debug" 		=> \$opt{'debug'},
    "help|?"		=> \$opt{'help'},
    "man"			=> \$opt{'man'},
) or pod2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

unless (defined($opt{'isilon'})) {
        print "--isilon is required\n";
        exit 3;
}
$opt{'isilon'} = 'https://isilon-'.$opt{'isilon'}.'.media.int:8080' if (grep  { $opt{'isilon'} eq $_ } qw(ix o m cu01));

$opt{'isilon'} = "https://".$opt{'isilon'} unless ($opt{'isilon'} =~ m/^https/);
$opt{'isilon'} = $opt{'isilon'}.":8080" unless ($opt{'isilon'} =~ m/:8080$/);

unless (( (defined($opt{'user'}) && defined($opt{'pass'})) || defined($opt{'auth'}))) {
        print '--user ' unless (defined($opt{'user'}));
        print '--pass ' unless (defined($opt{'pass'}));
        print 'or --auth ' unless (defined($opt{'user'}) && defined($opt{'pass'}));
        print "required\n" ;
        exit 3;
}

unless (defined($opt{'path'})) {
	print "--path is required\n";
	exit 3;
}

# set defaults
# ------------
$opt{'warning'} = 80 unless (defined($opt{'warning'}));
$opt{'critical'} = 90 unless (defined($opt{'critical'}));

# input checks
# ------------
foreach (qw(warning critical advisory)) {
	next unless defined($opt{$_});
	if (($opt{$_} < 0) || ($opt{$_} > 100)) {
		print $_." has to be between 0 and 100\n";
		exit 3;
	}
}

if ($opt{'critical'} < $opt{'warning'}) {
	print "critical has to be higher than warning.\n";
	exit 3;
}

unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
}

# get the data
# ------------

$quota_ref = fetchData($opt{'isilon'}, '/platform/1/quota/quotas', $opt{'auth'}, $opt{'debug'});

if (defined($quota_ref)) {

	# in case we do not find a quota matchin the path...
	$msg = "path has no quota defined.";
	$rc = 3;

	# let's find it...
	foreach my $k (@{$quota_ref->{'quotas'}}) {
		next unless ($k->{'path'} eq $opt{'path'});
	
		if ((defined($k->{'thresholds'}{'hard'})) || (defined($k->{'thresholds'}{'soft'}))) {
			my $limit = defined($k->{'thresholds'}{'hard'}) ? $k->{'thresholds'}{'hard'} : $k->{'thresholds'}{'soft'};
			if ($limit > 0) {
				# set the warning and critial according to advisory limit (if defined)
				if (defined ($k->{'thresholds'}{'advisory'}) && defined($opt{'advisory'})) {
					$opt{'warning'} = 100 / $limit * $k->{'thresholds'}{'advisory'};
					$opt{'critical'} = 100 / $limit * ($k->{'thresholds'}{'advisory'} + (($limit - $k->{'thresholds'}{'advisory'}) * ($opt{'advisory'} / 100)));
					if (defined($opt{'verbose'})) {
						printf "Advisory: Quota=%.1f GB AdvisoryQuota=%.1f GB Delta=%.1f GB\n", $limit/1024/1024/1024, $k->{'thresholds'}{'advisory'}/1024/1024/1024, ($limit-$k->{'thresholds'}{'advisory'})/1024/1024/1024 ;
						printf "Advisory: warning=%.4f%% critical=%.4f%%\n", $opt{'warning'}, $opt{'critical'};
					}
				}
				my $usagePct = 100 / $limit * $k->{'usage'}{'logical'};
				$msg = sprintf "used=%.1f%% (w:%.1f%% c:%.1f%%), limit=%.1f GB, used=%.1f GB, free=%.1f GB | used=%.1f%% QuotaTotal=%dB QuotaUsage=%dB QuotaFree=%dB",
					$usagePct,
					$opt{'warning'},
					$opt{'critical'},
					$limit/1024/1024/1024,
					$k->{'usage'}{'logical'}/1024/1024/1024,
					($limit - $k->{'usage'}{'logical'})/1024/1024/1024,
					$usagePct,
					$limit,
					$k->{'usage'}{'logical'},
					$limit - $k->{'usage'}{'logical'};
		
				$rc = ($usagePct >= $opt{'critical'}) ? 2 : ($usagePct >= $opt{'warning'}) ? 1 : 0;
			} else {
				$msg = "Quota is 0 ?!?";
				$rc = 3;
			}
		} else {
			$msg = "path has no hard or soft limit set.";
			$rc = 3;
		}
	}
} else {
   $msg = "something went wrong while fetching data from the Isilon REST API...";
   $rc = 3;
}


print $msg, "\n";
printf "exit code = %d\n", $rc if ($opt{'verbose'});
exit $rc;

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}


__END__

=head1 NAME

check_IsilonQuotaUsage.pl -- check Isilon Quota Usage using the REST API

=head1 SYNOPSIS

	check_IsilonQuotaUsage.pl [options]
	Options:
		--isilon        IP/name of Isilon
		--user          user name for authentification
		--pass          password for authentification
		--auth          pass-though auth string
		--path          path of quota to be checked
		--critical=n    n in percent for critical level
		--warning=n     n in percent for warning level
		--advisory=n    use advisory limit for warning and n to calculate critical
		--verbose       verbose, what else?
		--debug         show REST API output
		--help          brief help message
		--man           full documentation

=head1 OPTIONS

=over 8

=item B<--isilon>

IP/name of Isilon

=item B<--user>

user name for authentification

=item B<--pass>

password for authentification

=item B<--auth>

pass-though auth string

=item B<--path>

path of quota to be checked

=item B<--critical>

integer value between 0 and 100 in percent for critical level - must be above warning level. Default is 90.

=item B<--warning>

integer value between 0 and 100 in percent for warning level - must be below critical level. Default is 80.

=item B<--advisory n>

Use the advisory limit defined in the Quota settings on the Isilon to dynamically calculate the warning and critical percentage. n is a value between 0 and 100 in percent for critical level calculation:

Dynamic warning level: The advisory limit itself is used to calculate the warning level.

Dynamic critical level: The delta of hard limit and advisory limit is taken into consideration. If this delta is used more than n% this is considered critical.

If no advisory limit is set on the isilon (e.g. soft quota) this option is ignored and the levels given with --warning and --critial or the defaults are used.

=item B<--verbose>

verbose mode - shows some more information.

=item B<--debug>

debug mode for prining REST output

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<icheck_IsilonQuotaUsage.pl> get the quota information from the Isilon using the REST API and perform some check for warning and critial usage levels.
Optionally the advisory limit set on Isilon Smart Quotas can be used to have a more flexible trigger level.

=cut

