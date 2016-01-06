#!/usr/bin/perl
# ============================================================================
# check_IsilonAuthADList.pl
# -------------------------
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
my $ads_ref;
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
    "name=s"		=> \$opt{'name'},
    "verbose"		=> \$opt{'verbose'},
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

unless (defined($opt{'name'})) {
	print "--name is required\n";
	exit 3;
}

# input checks
# ------------
unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
}

# get the data
# ------------

$ads_ref = fetchData($opt{'isilon'}, '/platform/1/auth/providers/ads', $opt{'auth'});

if (defined($ads_ref)) {

	# in case we do not find ...
	$msg = "unknown";
	$rc = 3;


	# let's find it...
	foreach my $k (@{$ads_ref->{'ads'}}) {
		next unless ($k->{'id'} eq $opt{'name'});
		$msg = sprintf "%s: Authentication=%s Status=%s Site=%s", $k->{'id'}, $k->{'authentication'},$k->{'status'},$k->{'site'};

		if ($k->{'status'} ne "online") {
			$rc = 2;
		} elsif ($k->{'authentication'} ne "true") {
			$rc = 2;
		} else {
			$rc = 0;
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

check_IsilonAuthADList.pl -- check Isilon AD List

=head1 SYNOPSIS

	check_IsilonQuotaUsage.pl [options]
	Options:
		--isilon        IP/name of Isilon
		--user          user name for authentification
		--pass          password for authentification
		--auth          pass-though auth string
		--name          name of AD to be checked
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

=item B<--name>

name of AD to be checked

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_IsilonAuthADList.pl> check Isilon AD List using the REST API and perform a check for authentification used and status online
=cut

