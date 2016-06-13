#!/usr/bin/perl
# ============================================================================
# check_solidfire_api.pl
# ------------------------------
# 13.06.2016 Michael Pospiezsynski, SWISS TXT 
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
my %checks = (
				'perform_check_Volume_Stats', \&perform_check_Volume_Stats,
			 );
my $msg = "?";
my $rc = 3;

# fetch data from server using REST API
# -------------------------------------
sub fetchSolidfireData($$$$) {
    my ($server, $path, $req, $auth) = @_;
    my $client = REST::Client->new({ host => $server });
	$client->addHeader("Content-Type", "application/json");
	$client->addHeader("Authorization", "Basic ".$auth);


	$client->POST($path, to_json($req));

	if ($opt{'verbose'}) {
		print "---------\n";
		printf ("Server: %s\nRequest:\n%s\nPath:   %s\n", $server, to_json($req), $path);
	 	print "---------\n";
		printf "Return Code: %s\n", $client->responseCode;
		print "Content:\n";
		print $client->responseContent();
		print "\n---------\n";
	}

    return (
        $client->responseCode,
        $client->responseCode == 200 ? from_json($client->responseContent()) : undef
    );
}



# check implementation
# --------------------
sub perform_check_Volume_Stats() {

	my $rc = 3;
    my $msg = "unknown";
	my $v = 0;

	unless (defined($opt{'param'})) {
		$msg="option --param required";
		return ($rc, $msg);
	} else {
		$v = $opt{'param'} + 0;
		if (($v < 0) || ($v > 65535)) {
			$msg="volumeID out of range";
			return ($rc, $msg);
		}
	}
	

	my $req =
       {
            'method' => 'GetVolumeStats',
            'params' => {
                'volumeID' => $v
            },
            'id' => 1,
       };

	my ($http_rc, $data_ref) = fetchSolidfireData($opt{'mvip'}.":".$opt{'port'}, '/json-rpc/8.4', $req, $opt{'auth'});

	# get more information, same volume ID:
	$req->{'method'} = 'GetVolumeEfficiency';
	$req->{'id'}++;
	
	my ($http_rc2, $data_ref2) = fetchSolidfireData($opt{'mvip'}.":".$opt{'port'}, '/json-rpc/8.4', $req, $opt{'auth'});

	if (defined($data_ref) && defined($data_ref2)) {

		if ($opt{'verbose'}) {
			print Dumper ($data_ref);			
			print Dumper ($data_ref2);
		}
			
	

		if ($opt{'verbose'}) {
			printf "Volume ID: %s\n", $data_ref->{'result'}{'volumeStats'}{'volumeID'};
			printf "actualIOPS: %d\n", $data_ref->{'result'}{'volumeStats'}{'actualIOPS'};
			printf "latency: %.3fms\n", $data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000;
			printf "readLatency: %.3fms\n", $data_ref->{'result'}{'volumeStats'}{'readLatencyUSec'}/1000;
			printf "writeLatency: %.3fms\n", $data_ref->{'result'}{'volumeStats'}{'writeLatencyUSec'}/1000;
			printf "throttle: %s\n", $data_ref->{'result'}{'volumeStats'}{'throttle'};
			printf "volumeUtilization: %.3f\n", $data_ref->{'result'}{'volumeStats'}{'volumeUtilization'};
		
			printf "compression: %.3f\n", $data_ref2->{'result'}{'compression'};
			printf "deduplication: %.3f\n", $data_ref2->{'result'}{'deduplication'};
			printf "thinProvisioning: %.3f\n", $data_ref2->{'result'}{'thinProvisioning'};
		}
	
	
		$msg = sprintf
			"actualIOPS=%d usedCapacity=%.2f%% volumeUtilization=%.1f%% latency=%.3fms readLatency=%.3fms writeLatency=%.3fms compression=%.3f deduplication=%.3f thinProvisioning=%.3f throttle=%s",
	        $data_ref->{'result'}{'volumeStats'}{'actualIOPS'},
			100/($data_ref->{'result'}{'volumeStats'}{'volumeSize'}/4096)*$data_ref->{'result'}{'volumeStats'}{'nonZeroBlocks'},
	        $data_ref->{'result'}{'volumeStats'}{'volumeUtilization'}*100,
	        $data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000,
	        $data_ref->{'result'}{'volumeStats'}{'readLatencyUSec'}/1000,
	        $data_ref->{'result'}{'volumeStats'}{'writeLatencyUSec'}/1000,
	        $data_ref2->{'result'}{'compression'},
	        $data_ref2->{'result'}{'deduplication'},
	        $data_ref2->{'result'}{'thinProvisioning'},
	        $data_ref->{'result'}{'volumeStats'}{'throttle'}
			. " | " .
			sprintf 
			"actualIOPS=%d usedCapacity=%.2f%% volumeUtilization=%.1f%% latency=%.6fs readLatency=%.6fs writeLatency=%.6fs compression=%.3f deduplication=%.3f thinProvisioning=%.3f throttle=%s", 
			$data_ref->{'result'}{'volumeStats'}{'actualIOPS'},
			100/($data_ref->{'result'}{'volumeStats'}{'volumeSize'}/4096)*$data_ref->{'result'}{'volumeStats'}{'nonZeroBlocks'},
			$data_ref->{'result'}{'volumeStats'}{'volumeUtilization'}*100,
			$data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000/1000,
			$data_ref->{'result'}{'volumeStats'}{'readLatencyUSec'}/1000/1000,
			$data_ref->{'result'}{'volumeStats'}{'writeLatencyUSec'}/1000/1000,
			$data_ref2->{'result'}{'compression'},
			$data_ref2->{'result'}{'deduplication'},
			$data_ref2->{'result'}{'thinProvisioning'},
			$data_ref->{'result'}{'volumeStats'}{'throttle'}
		;

		$rc = 0;
	
	} else {
		$msg = "Error";
		$rc = 3;
	}	

	
	return ($rc, $msg);

}

########
# MAIN #
########

GetOptions (
    "mvip=s"		=> \$opt{'mvip'},
	"port=i"        => \$opt{'port'},
    "user=s"		=> \$opt{'user'},
    "pass=s"		=> \$opt{'pass'},
    "auth=s"		=> \$opt{'auth'},
    "check=s"		=> \$opt{'check'},
    "param=s"		=> \$opt{'param'},
    "verbose"		=> \$opt{'verbose'},
    "help|?"		=> \$opt{'help'},
    "man"			=> \$opt{'man'},
) or pod2usage(2);

#
# check options
#
pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

unless (defined($opt{'mvip'})) {
        print "--mvip is required\n";
        exit 3;
}
$opt{'mvip'} = "https://".$opt{'mvip'} unless ($opt{'mvip'} =~ m!^http[s?]://!);

unless (( (defined($opt{'user'}) && defined($opt{'pass'})) || defined($opt{'auth'}))) {
        print '--user ' unless (defined($opt{'user'}));
        print '--pass ' unless (defined($opt{'pass'}));
        print 'or --auth ' unless (defined($opt{'user'}) && defined($opt{'pass'}));
        print "required\n" ;
        exit 3;
}

unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
		$opt{'auth'} =~ s/\n//;
}

unless (defined($opt{'port'})) {
	$opt{'port'} = 443; # default
}

unless (defined($opt{'check'})) {
	print "--check is required\n";
	exit 3;
} elsif (! grep  { $opt{'check'} eq $_ } keys %checks) {
	print "selected check is not implemented.\n";
	exit 3;
} else {
	printf "run check: %s\n", $opt{'check'} if ($opt{'verbose'});

	($rc, $msg) = &{$checks{$opt{'check'}}};


}

# result of check

print $msg, "\n";
printf "exit code = %d\n", $rc if ($opt{'verbose'});
exit $rc;

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}


__END__

=head1 NAME

check_solidfire_api.pl -- check Solidfire using REST API

=head1 SYNOPSIS

	check_solidfire_api.pl [options]
	Options:
		--mvip          IP/name MVIP of Solidfire Cluster
		--port          port number
		--user          user name for authentification
		--pass          password for authentification
		--auth          pass-through auth string
		--check         name of check to be executed
		--verbose       verbose, what else?
		--help          brief help message
		--man           full documentation

=head1 OPTIONS

=over 8

=item B<--mvip>

IP/name Solidfire cluster MVIP

=item B<--port>

Port number, default 443

=item B<--user>

user name for authentification

=item B<--pass>

password for authentification

=item B<--auth>

pass-though auth string

=item B<--check>

name of check to be executed

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_solidfire_api.pl> execute the specified check using the REST API
=cut

