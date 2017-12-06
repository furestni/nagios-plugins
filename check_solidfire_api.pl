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
				'perform_check_Cluster_Capacity', \&perform_check_Cluster_Capacity,
			 );
my $msg = "?";
my $rc = 3;

# ----------------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------------
$opt{'warnutil'} = 200;
$opt{'critutil'} = 300;
$opt{'warnlatency'} = 250;
$opt{'critlatency'} = 500;
$opt{'warncapacity'} = 80;
$opt{'critcapacity'} = 90;


# fetch data from server using REST API
# -------------------------------------
sub fetchSolidfireData($$$$) {
    my ($server, $path, $req, $auth) = @_;
    my $client = REST::Client->new({ host => $server });
	$client->addHeader("Content-Type", "application/json");
	$client->addHeader("Authorization", "Basic ".$auth);


	$client->POST($path, to_json($req));

	if ($opt{'debug'}) {
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
sub perform_check_Cluster_Capacity() {

	my $rc = 3;
	my $msg = "unknown";
	my @perfdata;

	# options for this check
	# $opt{'warncapacity'} and ${'critcapacity'} are set with defaults.

	my $req = {
		'method' => 'GetClusterFullThreshold',
		'params' => {},
		'id' => 1,
	};

	my ($http_rc, $data_ref) = fetchSolidfireData($opt{'mvip'}.":".$opt{'port'}, '/json-rpc/9.4', $req, $opt{'auth'});

    if (defined($data_ref->{'error'} )) {
        print "Error:\n", Dumper ($data_ref) if ($opt{'debug'});
        $rc = 3;
        $msg = sprintf ("Error %s: %s", $data_ref->{'error'}{'code'}, $data_ref->{'error'}{'message'});
    } else {
		if (defined($data_ref)) {
			if ($opt{'debug'}) {
				print Dumper ($data_ref);
			}

			# add some useful percent values
			$data_ref->{'result'}{'percentUsedOfFullCapacity'} = (100/$data_ref->{'result'}{'sumTotalClusterBytes'})*$data_ref->{'result'}{'sumUsedClusterBytes'};
			$data_ref->{'result'}{'percentUsedOfWarningThreshhold'} = (100/$data_ref->{'result'}{'stage3BlockThresholdBytes'})*$data_ref->{'result'}{'sumUsedClusterBytes'};
			$data_ref->{'result'}{'percentUsedOfCriticalThreshhold'} = (100/$data_ref->{'result'}{'stage4BlockThresholdBytes'})*$data_ref->{'result'}{'sumUsedClusterBytes'};

			# perfdata
			foreach my $k (qw/sumTotalClusterBytes sumUsedClusterBytes stage2BlockThresholdBytes stage3BlockThresholdBytes stage4BlockThresholdBytes stage5BlockThresholdBytes sumTotalMetadataClusterBytes sumUsedMetadataClusterBytes percentUsedOfFullCapacity percentUsedOfWarningThreshhold percentUsedOfCriticalThreshhold/) {
				push @perfdata, sprintf("%s=%d%s", $k, $data_ref->{'result'}{$k}, $k =~m/percent/ ? "%" : "");
			}

			if ($opt{'verbose'}) {
				print "\n\nData\n";
				printf "sumTotalClusterBytes:         %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'sumTotalClusterBytes'}/1000000000000, $data_ref->{'result'}{'sumTotalClusterBytes'}/1024/1024/1024/1024;
				printf "sumUsedClusterBytes:          %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'sumUsedClusterBytes'}/1000000000000, $data_ref->{'result'}{'sumUsedClusterBytes'}/1024/1024/1024/1024;
				printf "stage2BlockThresholdBytes:    %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'stage2BlockThresholdBytes'}/1000000000000, $data_ref->{'result'}{'stage2BlockThresholdBytes'}/1024/1024/1024/1024;
				printf "stage3BlockThresholdBytes:    %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'stage3BlockThresholdBytes'}/1000000000000, $data_ref->{'result'}{'stage3BlockThresholdBytes'}/1024/1024/1024/1024;
				printf "stage4BlockThresholdBytes:    %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'stage4BlockThresholdBytes'}/1000000000000, $data_ref->{'result'}{'stage4BlockThresholdBytes'}/1024/1024/1024/1024;
				printf "stage5BlockThresholdBytes:    %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'stage5BlockThresholdBytes'}/1000000000000, $data_ref->{'result'}{'stage5BlockThresholdBytes'}/1024/1024/1024/1024;
				printf "fullness:                     %s\n", $data_ref->{'result'}{'fullness'};
				printf "Percent Used till full:            %5.1f%%\n", $data_ref->{'result'}{'percentUsedOfFullCapacity'};
				printf "Percent Used till warning:         %5.1f%%\n", $data_ref->{'result'}{'percentUsedOfWarningThreshhold'};
				printf "Percent Used till critical:        %5.1f%%\n", $data_ref->{'result'}{'percentUsedOfCriticalThreshhold'};

				print "\n\nMetadata\n";
				printf "sumTotalMetadataClusterBytes: %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'sumTotalMetadataClusterBytes'}/1000000000000, $data_ref->{'result'}{'sumTotalMetadataClusterBytes'}/1024/1024/1024/1024;
				printf "sumUsedMetadataClusterBytes:  %8.2f TB   %8.2f TiB\n", $data_ref->{'result'}{'sumUsedMetadataClusterBytes'}/1000000000000, $data_ref->{'result'}{'sumUsedMetadataClusterBytes'}/1024/1024/1024/1024;
				printf "metadataFullness:             %s\n", $data_ref->{'result'}{'metadataFullness'};
				print "\n";
			}

            #### Logic for health-checks ####
            $rc = 0;

			$msg = sprintf("percent used of warning threshhold=%.1f%%", $data_ref->{'result'}{'percentUsedOfWarningThreshhold'});

			if ($data_ref->{'result'}{'percentUsedOfWarningThreshhold'} > $opt{'critcapacity'}) {
				$rc = 2;
				$msg .= " reached critical threshold";
			} elsif ($data_ref->{'result'}{'percentUsedOfWarningThreshhold'} > $opt{'warncapacity'}){
				$rc = 1;
				$msg .= " reached warning threshold";
			} else {
				$rc = 0;
			}

			$msg .= " | ". join (' ',@perfdata);

        } else {
           $msg = "Error";
		   $rc = 3;
	   }
   }
   return ($rc, $msg);

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

	if (defined($data_ref->{'error'} )) {
		print "Error:\n", Dumper ($data_ref) if ($opt{'verbose'} or $opt{'debug'});
		$rc = 3;
		$msg = sprintf ("Error %s: %s", $data_ref->{'error'}{'code'}, $data_ref->{'error'}{'message'});
	} else {

		# get more information, same volume ID:
		$req->{'method'} = 'GetVolumeEfficiency';
		$req->{'id'}++;
	
		my ($http_rc2, $data_ref2) = fetchSolidfireData($opt{'mvip'}.":".$opt{'port'}, '/json-rpc/8.4', $req, $opt{'auth'});

		if (defined($data_ref) && defined($data_ref2)) {

			if ($opt{'verbose'} && $opt{'debug'}) {
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
				"actualIOPS=%d usedCapacity=%.2f%% volumeUtilization=%.1f%% latency=%.3fms readLatency=%.3fms writeLatency=%.3fms compression=%.3f deduplication=%.3f thinProvisioning=%.3f",
		        $data_ref->{'result'}{'volumeStats'}{'actualIOPS'},
				100/($data_ref->{'result'}{'volumeStats'}{'volumeSize'}/4096)*$data_ref->{'result'}{'volumeStats'}{'nonZeroBlocks'},
		        $data_ref->{'result'}{'volumeStats'}{'volumeUtilization'}*100,
		        $data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000,
		        $data_ref->{'result'}{'volumeStats'}{'readLatencyUSec'}/1000,
		        $data_ref->{'result'}{'volumeStats'}{'writeLatencyUSec'}/1000,
		        $data_ref2->{'result'}{'compression'},
		        $data_ref2->{'result'}{'deduplication'},
		        $data_ref2->{'result'}{'thinProvisioning'},
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


			#### Logic for health-checks ####
			$rc = 0;
	        if ($data_ref->{'result'}{'volumeStats'}{'volumeUtilization'}*100 > $opt{'critutil'}) {
				$rc = 2;
				$msg = "Critical volumeUtilization - ".$msg;
			} elsif ($data_ref->{'result'}{'volumeStats'}{'volumeUtilization'}*100 > $opt{'warnutil'}) {
				$rc = 1;
				$msg = "Warning volumeUtilization - ".$msg;
			}
			if ($data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000 > $opt{'critlatency'}) {
				$rc = 2;
				$msg = "Critical latency - ".$msg;
			} elsif ($data_ref->{'result'}{'volumeStats'}{'latencyUSec'}/1000 > $opt{'warnlatency'}) {
				$rc = $rc > 1 ? $rc : 1;
				$msg = "Warning latency - ".$msg;
			}

	
		} else {
			$msg = "Error";
			$rc = 3;
		}	
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
    "warnutil=i"    => \$opt{'warnutil'},
    "critutil=i"    => \$opt{'critutil'},
    "warnlatency=i" => \$opt{'warnlatency'},
    "critlatency=i" => \$opt{'critlatency'},
	"warncapacity=i"=> \$opt{'warncapacity'},
	"critcapacity=i"=> \$opt{'critcapacity'},
    "verbose"		=> \$opt{'verbose'},
    "debug"			=> \$opt{'debug'},
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
		--warnutil		warning level for volumeUtilization
		--critutil      critical level for volumeUtilization
		--warnlatency   warning level for latency
		--critlatency   critical level for latency
		--verbose       verbose, what else?
        --debug         add more information (use with --verbose)
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

name of check to be executed:
	perform_check_Volume_Stats:     check and report volume statistics
    perform_check_Cluster_Capacity: check and report cluster capacity statistics

=item B<--warnutil>

warning level for volumeUtilization

=item B<--critutil>

critical level for volumeUtilization

=item B<--warnlatency>

warning level for latency

=item B<--critlatency>

critical level for latency

=item B<--warncapacity>

warning level for capacity: usage percentage of cluster warning threshhold, meaning if Solidfire reaches the warning threshhold this value would be 100%. Defauls to 80%.

=item B<--critcapacity>

critical level for capacity: usage percentage of cluster warning threshhold, meaning if Solidfire reaches the warning threshhold this value would be 100%. Defaults to 90%.

=item B<--verbose>

verbose mode for testing

=item B<--debug>

debug mode for testing and debugging, use with --verbose

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_solidfire_api.pl> execute the specified check using the REST API
=cut

