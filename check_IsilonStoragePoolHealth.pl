#!/usr/bin/perl
# ============================================================================
# check Isilon Storage Pool health
# --------------------------------
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
# Options
# ----------------------------------------------------------------------------
my $opt_isilon;
my $opt_verbose;
my $opt_help;
my $opt_man;
my $opt_warning;
my $opt_critical;
my $opt_user;
my $opt_pass;
my $opt_auth;

GetOptions (
	"isilon=s"	=> \$opt_isilon,
	"user=s"	=> \$opt_user,
	"pass=s"	=> \$opt_pass,
	"auth=s"	=> \$opt_auth,
	"verbose"  	=> \$opt_verbose,
	"warning=i"	=> \$opt_warning,
	"critical=i"	=> \$opt_critical,
	"help|?"	=> \$opt_help,
	"man"		=> \$opt_man,
) or pos2usage(2);

pod2usage(1) if $opt_help;
pod2usage(-exitval => 0, -verbose => 2) if $opt_man;

# -------------------------------------
# fetch data from isilon using REST API
# -------------------------------------
sub fetchData {
	my ($isilon, $path, $auth) = @_;

	my $headers = {Accept => 'application/json', Authorization => 'Basic ' . $auth};
	my $client = REST::Client->new({ host => $isilon });

	$client->GET($path, $headers);
	
	return ($client->responseCode,
		$client->responseCode == 200 ? from_json($client->responseContent()) : undef);
}

	
# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
#
unless (defined($opt_isilon)) {
	print "--isilon is required\n";
	exit 3;
}
$opt_isilon = 'https://isilon-'.$opt_isilon.'.media.int:8080' if (grep  { $opt_isilon eq $_ } qw(ix o m cu01));

unless (( (defined($opt_user) && defined($opt_pass)) || defined($opt_auth))) {
	print '--user ' unless (defined($opt_user));
	print '--pass ' unless (defined($opt_pass));
	print 'or --auth ' unless (defined($opt_user) && defined($opt_pass));
	print "required\n" ;
	exit 3;
}

unless ($opt_auth) {
	$opt_auth = encode_base64($opt_user . ':' . $opt_pass);
}


my ($rc, $status) = fetchData ($opt_isilon, '/platform/1/storagepool/status', $opt_auth);


unless ($status) {
	print "Unknown - Response Code = ".$rc."\n";
	exit 3;
}

my $restriping = 0;
my $smartfailed = 0;
my $down = 0;
my $rcicinga = 3;
my @disklist;
my @flags;

if (@{$status->{'unhealthy'}}) {
	foreach my $k (@{$status->{'unhealthy'}}) {
		print "Unhealthy Disks reported:\n", "=" x 80, "\n" if ($opt_verbose);
		foreach my $a (@{$k->{'affected'}}) {
			printf "Node:%2d   Bay:%2d   restriping:%-5s   smartfailed:%-5s   down:%-5s\n", 
				$a->{'device'}{'lnn'},	
				$a->{'device'}{'bay'}, 
				$a->{'restriping'},
				$a->{'smartfailed'},
				$a->{'down'} if ($opt_verbose);
			$restriping++  if ($a->{'restriping'});
			$smartfailed++ if ($a->{'smartfailed'});
			$down++        if ($a->{'down'});
		}

		# collect all flags
		foreach (@{$k->{'health_flags'}}) {
			push (@flags, $_);
		}
		
		# in verbose mode print pool information and member list
		if ($opt_verbose) {
			print "\nPools affected:\n", "=" x 80;
			printf "\nPool: %s   id: %s   nodepool_id: %s   protection_policy: %s\n",
				$k->{'diskpool'}{"id"},
				$k->{'diskpool'}{"name"},
				$k->{'diskpool'}{"nodepool_id"},
				$k->{'diskpool'}{"protection_policy"};

		        foreach my $d (@{$k->{'diskpool'}{'drives'}}) {
	                	push (@disklist, sprintf "Node %3s Bay %02s\n", $d->{'lnn'}, $d->{'bay'});
	        	}

			foreach (sort(@disklist)) { print }

			printf "Flags: %s\n", join(",",@{$k->{'health_flags'}});
		}
	}
	printf "WARNING: restriping=%d smartfailed=%s down=%d flags=%s\n", 
			$restriping,
                        $smartfailed,
                        $down,
			join (',', @flags);
	$rcicinga = 1;

} else {
	print "OK\n";
	$rcicinga = 0;
}

exit $rcicinga;

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}

__END__

=head1 NAME

Isilon Storage Pool health check

=head1 SYNOPSIS

check_IsilonStoragePoolHealth.pl [options]

	Options:

	--isilon	URL for Isilon REST-API 

	--user=name 	username
	--pass=pass 	password 
	or
	--auth=token 	authtoken 
	
	--verbose	be verbose
	--help          help
	--man           man page


=head1 OPTIONS

=over 8

=item B<--isilon>

   URL for Isilon REST-API like https://isilon:8080
   o, m, ix, cu01 can be used as shortcut

=item B<--user>

   Username for Authentification

=item B<--pass>

   Password for Authentification

=item B<--auth>

   Authentification Token 1:1 used

=item B<--verbose>

   Print Debugging Information

=item B<--help>

   Print a brief help message and exits.

=item B<--man>
   Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_IsilonStoragePoolHealth.pl> is fetching the storage pool health state from the isilon REST-API and return OK if no problem is found and a WARNING if disks are in smartfailed state.

Known Feature: Failed disks which are not longer configured in the pool are not detected unless the health flag is indicating a problem. At this stage an event is logged in the isilon and normally a ticket to EMC is generated.

=cut

