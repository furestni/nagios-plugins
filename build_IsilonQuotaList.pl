#!/usr/bin/perl
# ============================================================================
# build_IsilonQuotaList.pl
# ------------------------
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

# ----------------------------------------------------------------------------
# Subroutines
# ----------------------------------------------------------------------------

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
	"isilon=s"	=> \$opt{'isilon'},
	"user=s"	=> \$opt{'user'},
	"pass=s"	=> \$opt{'pass'},
	"auth=s"	=> \$opt{'auth'},
	"file=s"	=> \$opt{'file'},
	"verbose"	=> \$opt{'verbose'},
	"help|?"	=> \$opt{'help'},
	"man"		=> \$opt{'man'},
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

unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
}

if (defined($opt{'file'})) {
	open STDOUT, ">", $opt{'file'} or die "$0: open: $!";
}


$quota_ref = fetchData($opt{'isilon'}, '/platform/1/quota/quotas', $opt{'auth'});



print "isilon_quota_paths:\n";

foreach my $k (@{$quota_ref->{'quotas'}}) {
	next unless ((defined($k->{'thresholds'}{'hard'})) || (defined($k->{'thresholds'}{'soft'})));

	print "  - path: ", $k->{'path'}, "\n";

}


BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}


__END__

=head1 NAME

build_IsilonQuotaList.pl returns a YAML list of Isilon Shares having a Quota (Soft- or Hard Linit)

=head1 SYNOPSIS

  build_IsilonQuotaList.pl [options]

  Options:
    --isilon       IP or Name of Isilon Cluster
    --user         user name for authentification
    --pass         password for authentification
    --auth         authentification pass-though
    --file         write quota path list to file
    --verbose      be verbose, what else?
    --help         brief help message
    --man          full documentation

=head1 OPTIONS

=over 8

=item B<--isilon>

IP or Name of Isilon Cluster

=item B<--user>

user name for authentification

=item B<--pass>

password for authentification

=item B<--auth>

authentification pass-though

=item B<--file>

write quota path list to file

=item B<--verbose>

verbose, for debugging.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<build_IsilonQuotaList.pl> fetches the quota list from the isilon cluster using the REST API and build a list of pathes in YAML for configuration purpose.

=cut


