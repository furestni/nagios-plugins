#!/usr/bin/perl
# ============================================================================
# get_vcenter_data.pl
# ============================================================================
use strict;
use warnings;
use lib '/usr/local/lib/vmware-vcli/apps';
use lib '/usr/lib/vmware-vcli/apps';
use VMware::VIRuntime;
use VMware::VILib;
use Time::HiRes qw( time );
use List::Util qw( sum );
use Storable qw (lock_store);
# ---
# --- Global Variables
# ---
my $t0;					# for timing purposes only
my $exit_code = -1;
my @exit_txt = qw (OK WARNING CRITICAL UNKNOWN);
my @get_status = ();
my %opts = (
   'filename' => {
      type => "=s",
      help => "Name of file to hold output",
      required => 0,
   },
); 				# Define additional options
my $host_view;				# All ESX hosts object
my $perfmgr_view;			# Global performance manager object
my $host_ref;				# reference to one ESX host object
my @perf_metric_ids;			# array of performance metrics filter objects
my @perf_metric_ids_51;		# ... for version 5.1
my @perf_metric_ids_55;		# ... for version 5.5
my $perf_data;				# reference to performance data object
my $opt_debug = 0;			# to show or not to show: debugging messages
my %esx_data;				# datastructure for esx-data
my $file_esx_data = "/tmp/esx-data.dat"; # file name for esx data 
my $file_path = "/var/cache/icinga2/vcenter_data/"; # ensure this path exists with correct permissions
# ---
# --- Subroutines
# ---
sub avg	{
	return sum(@_)/@_;
}

sub genPerfMetricIdArray(@) {
    my @ids = @_;
	my @a;
	foreach (@ids) {
		push @a,PerfMetricId->new (counterId => $_, instance => '*');
	}
	return @a;
}


# ============================================================================
# === MAIN                                                                 ===
# ============================================================================

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

$t0 = time();
$host_view = Vim::find_entity_views(view_type => 'HostSystem');
printf ("[INFO] find_entity_views HostSystem: %.3fs\n", time()-$t0) if ($opt_debug);


$t0 = time();
$perfmgr_view = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
printf ("[INFO] get perfmgr_view: %.3fs\n", time()-$t0) if ($opt_debug);

$t0 = time();
@perf_metric_ids_51 = genPerfMetricIdArray(qw(144 145));
@perf_metric_ids_55 = genPerfMetricIdArray(qw(182 183));
printf ("[INFO] generate filter object: %.3fs\n", time()-$t0) if ($opt_debug);

foreach $host_ref (@$host_view) {

	printf "[INFO] Processing ESX host %s (%s)\n", $host_ref->name, $host_ref->summary->config->product->fullName if ($opt_debug); 

	if ($host_ref->summary->config->product->fullName =~ m/ESXi 5\.5/) {
		@perf_metric_ids = @perf_metric_ids_55;
	} else {
		@perf_metric_ids = @perf_metric_ids_51;
	}

	my $perf_query_spec = PerfQuerySpec->new(	entity => $host_ref,
							metricId => \@perf_metric_ids,
							'format' => 'csv',
							intervalId => 20,
							maxSample => 20
						);

	$t0 = time();
	eval {
		$perf_data = $perfmgr_view->QueryPerf( querySpec => $perf_query_spec);
	};
	if ($@) {
		if (ref($@) eq 'SoapFault') {
			if (ref($@->detail) eq 'InvalidArgument') {
				push (@get_status, "Specified parameters are not correct");
				$exit_code = 3 if ($exit_code < 3);
			}
		}
		next;
	}
	if (! @$perf_data) {
		push (@get_status,"Performance data not available for ".$host_ref->name);
		$exit_code = 3 if ($exit_code < 3);
		next;
	}
	printf ("[INFO] Query performance: %.3fs\n", time()-$t0) if ($opt_debug);
	$exit_code = 0 if ($exit_code < 0);
	$t0 = time();
	foreach my $p_ref (@$perf_data) {
		my $time_stamps = $p_ref->sampleInfoCSV;
		print  "Sample info : " . $time_stamps . "\n" if ($opt_debug);
		my $values = $p_ref->value;
		foreach my $v_ref (@$values) {
			# Search Datastore Info
			my $dsname = "not found";
			foreach my $ds (@{$host_ref->config->fileSystemVolume->mountInfo}) {
				my $ds_type = $ds->volume->type;
				my $uuid = $v_ref->id->instance;
				if ($ds_type eq "NFS") {
					$dsname = $ds->volume->remoteHost . ":" . $ds->volume->remotePath if ($ds->mountInfo->path =~ m/$uuid$/);
				} elsif ($ds_type eq "VMFS") {
					$dsname = $ds->volume->name if ($ds->volume->uuid eq $v_ref->id->instance);
				}
			}
			printf "%s --- %s --- %s --- %s \n",
				(($v_ref->id->counterId eq "144") || ($v_ref->id->counterId eq "182")) ? 'Read latency' : 'Write latency',
				$v_ref->id->instance, 
				$dsname,
				$v_ref->value if ($opt_debug);
			
			$esx_data{$host_ref->name}{'datastore'}{$dsname}{$v_ref->id->counterId} = $v_ref->value;
		}
	}
	printf ("[INFO] show latency info: %.3fs\n\n\n", time()-$t0) if ($opt_debug);
}

# Summary:
# --------
#
#print Dumper \%esx_data;

lock_store \%esx_data, "$file_esx_data";

if (defined(Opts::get_option('filename'))) {
	lock_store \%esx_data, "$file_path".Opts::get_option('filename');
}

$exit_code = 3 if ($exit_code < 0); # set to unknown if exit_code was not changed
push (@get_status, "");

printf "vcenter data collection %s %s\n",
 	$exit_txt[$exit_code],
	join (' ', @get_status);
	
# logout
Vim::logout();

print "EXIT CODE=",$exit_code,"\n" if ($opt_debug);

exit ($exit_code);

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}
