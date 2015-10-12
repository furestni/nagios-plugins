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
sub fetchData($$$) {
    my ($isilon, $path, $auth) = @_;
    my $headers = {Accept => 'application/json', Authorization => 'Basic ' . $auth};
    my $client = REST::Client->new({ host => $isilon });

    $client->GET($path, $headers);

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
    "verbose"		=> \$opt{'verbose'},
    "help|?"		=> \$opt{'help'},
    "man"			=> \$opt{'man'},
) or pos2usage(2);

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
foreach (qw(warning critical)) {
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

$quota_ref = fetchData($opt{'isilon'}, '/platform/1/quota/quotas', $opt{'auth'});

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
				my $usagePct = 100 / $limit * $k->{'usage'}{'logical'};
				$msg = sprintf "used=%5.1f%%, limit=%.1f GB, used=%.1f GB, free=%.1f GB | used=%.1f%% QuotaTotal=%dB QuotaFree=%dB QuotaUsage=%dB",
					$usagePct,
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
   $msg = "something went wrong while fetching data from the REST API...";
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
		--critical      in percent for critical level
		--warning       in percent for warning level
		--verbose       verbose, what else?
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

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<icheck_IsilonQuotaUsage.pl> get the quota information from the Isilon using the REST API and perform some check for warning and critial usage levels.

=cut

