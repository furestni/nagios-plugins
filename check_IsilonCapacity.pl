#!/usr/bin/perl
# ============================================================================
# check Isilon capacity
# --------------------------------
# https://isilon:8080/platform/1/storagepool/storagepools
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
my $opt_user;
my $opt_pass;
my $opt_auth;
my %opt;

# Defaults
$opt{'critical'} = 90;
$opt{'warning'} = 80;

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
GetOptions (
    "isilon=s"  => \$opt_isilon,
    "user=s"    => \$opt_user,
    "pass=s"    => \$opt_pass,
    "auth=s"    => \$opt_auth,
    "verbose"   => \$opt_verbose,
    "debug"     => \$opt{'debug'},
    "warning=i" => \$opt{'warning'},
    "critical=i"=> \$opt{'critical'},
    "help|?"    => \$opt_help,
    "man"       => \$opt_man,
) or pos2usage(2);

pod2usage(1) if $opt_help;
pod2usage(-exitval => 0, -verbose => 2) if $opt_man;


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

my ($rc, $status) = fetchData ($opt_isilon, '/platform/1/storagepool/storagepools', $opt_auth);

unless ($status) {
	print "Unknown - Response Code = ".$rc."\n";
	exit 3;
}

my $rcicinga = -1;
my @poolinfo;
my @perfinfo;

foreach my $storpool (@{$status->{'storagepools'}}) {
		# some shortcuts
		my $poolname = $storpool->{'name'};
		my $usableCapacity = $storpool->{'usage'}{'total_bytes'} - $storpool->{'usage'}{'virtual_hot_spare_bytes'};
		my $availableCapacity = $storpool->{'usage'}{'avail_bytes'};
		my $usedPercentage = 100-(100/$usableCapacity*$availableCapacity);
		my $state = "ERR";

		# Verbose output
		if ($opt_verbose) {
			printf "StoragePool: %s\n", $poolname;
			printf "    Capacity:     %8.1f TB    Usable Capacity: %8.1f TB\n", $storpool->{'usage'}{'total_bytes'}/1024/1024/1024/1024, $usableCapacity/1024/1024/1024/1024;
			printf "    Free:         %8.1f TB    Avail:           %8.1f TB\n", $storpool->{'usage'}{'free_bytes'}/1024/1024/1024/1024, $storpool->{'usage'}{'avail_bytes'}/1024/1024/1024/1024;
			printf "    Hot Spare:    %8.1f TB    Used:            %8.1f TB\n", $storpool->{'usage'}{'virtual_hot_spare_bytes'}/1024/1024/1024/1024, ($usableCapacity-$availableCapacity)/1024/1024/1024/1024;
            printf "                                                  %8.1f %%\n\n", $usedPercentage;
		}

		# Debug output
		if ($opt{'debug'}) {
			printf "Dump StoragePool: %s\n", $poolname;
			print Dumper \$storpool, "\n\n";
		}

		# Icinga Logic
		if ($usedPercentage >= $opt{'critical'}) {
			$state = "Critical";
			$rcicinga = 2 unless ($rcicinga > 0);
		} elsif ($usedPercentage >= $opt{'warning'}) {
			$state = "Warning";
			$rcicinga = 1 unless ($rcicinga > 0);
		} else {
			$state = "OK";
			$rcicinga = 0 unless ($rcicinga > 0);
		}

		# Icinga output preparation
		push @poolinfo, sprintf("%s=%.1f%% (%s)",
			$poolname,
			$usedPercentage,
			$state		
		);
		$poolname =~ s/-/_/g; # just in case...
		push @perfinfo, sprintf("%s_%s=%d", $poolname, 'usableCapacity', $usableCapacity);
		push @perfinfo, sprintf("%s_%s=%d", $poolname, 'availableCapacity', $availableCapacity);
		push @perfinfo, sprintf("%s_%s=%d%%", $poolname, 'usedPercentage', $usedPercentage);
}

if ($rcicinga == -1) {
	print "Storage Pool Information not available.\n";
	exit 3;
} else {
	print join(' ', @poolinfo), ' | ', join (' ', @perfinfo), "\n";
	exit $rcicinga;
}

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}

__END__

=head1 NAME

Isilon Storage Capacity

=head1 SYNOPSIS

check_IsilonCapacity.pl [options]

  Options:

  --isilon        hostname for REST API

  --user=name     username
  --pass=pass     password
  or
  --auth=token    authtoken

  --verbose       be verbose
  --debug         be very verbose
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

   Show detailed capacity information

=item B<--debug>
   
   Print Debugging Information

=item B<--help>

   Print a brief help message and exits.

=item B<--man>
   Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_IsilonCapacity.pl> is fetching the storage pool capacity information using the isilon REST-API and return ok, warning, critical according to the warning and critical levels given.

=cut
