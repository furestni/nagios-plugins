#!/usr/bin/perl
# ============================================================================
# 
# ============================================================================
use strict;
use warnings;
use lib '/usr/local/lib/vmware-vcli/apps';
use lib '/usr/lib/vmware-vcli/apps';
use VMware::VIRuntime;
use VMware::VILib;
use Time::HiRes qw( time );
use List::Util qw( sum );

# ---
# --- Global Variables
# ---
my $t0;					# for timing purposes only
my %opts = ( 				# Define additional options
	'esx' => {
		type => "=s",
		help => "List of ESX hosts to query",
		required => 1,
	},
	'datastore' => { 
		type => "=s",
		help => "List of Datastores to query",
		required => 1,
	},
	'summary' => {
		type => "=s",
		help => "Display Text",
		required => 0,
	},
	'w' => {
		type => '=i',
		help => "Warning in ms",
		required => 1,
	},
	'c' => {
		type => '=i',
		help => "Critical in ms",
		required => 1,
	}
);
my $host_view;				# All ESX hosts object
my $perfmgr_view;			# Global performance manager object
my $host_ref;				# reference to one ESX host object
my @perf_metric_ids;			# array of performance metrics filter objects
my $perf_data;				# reference to performance data object
my @opt_datastore;			# Array of datastores
my @opt_esx;				# Array of ESX
my $opt_debug = 0;			# to show or not to show: debugging messages
# ---
# --- Subroutines
# ---
sub avg	{
	return sum(@_)/@_;
}


sub genPerfMetricIdArray() {
	# no options
	my @a;
	foreach (qw/144 145/) { # @@@ use 182 183 if 144 145 does not work. How to switch automatically?
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

@opt_datastore = split (',', Opts::get_option('datastore'));
@opt_esx = split (',', Opts::get_option('esx'));

Util::connect();

$t0 = time();
$host_view = Vim::find_entity_views(view_type => 'HostSystem');
printf ("[INFO] find_entity_views HostSystem: %.3fs\n", time()-$t0) if ($opt_debug);


$t0 = time();
$perfmgr_view = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
printf ("[INFO] get perfmgr_view: %.3fs\n", time()-$t0) if ($opt_debug);

$t0 = time();
@perf_metric_ids = genPerfMetricIdArray();
printf ("[INFO] generate filter object: %.3fs\n", time()-$t0) if ($opt_debug);


my %latency_values;

foreach $host_ref (@$host_view) {
	next unless (grep {$_ eq $host_ref->name} @opt_esx);	# skip current ESX if not in query list

	printf "[INFO] Processing ESX host %s (%s)\n", $host_ref->name, $host_ref->summary->config->product->fullName if ($opt_debug); 

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
				Util::trace(0,"Specified parameters are not correct");
			}
		}
		next;
	}
	if (! @$perf_data) {
		Util::trace(0,"Either Performance data not available for requested period or instance is invalid\n");
		next;
	}
	printf ("[INFO] Query performance: %.3fs\n", time()-$t0) if ($opt_debug);

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
			if (grep { $_ eq $dsname } @opt_datastore) {
				printf "%s --- %s --- %s --- %s --> %8.3f\n",
					$v_ref->id->counterId eq "144" ? 'Read latency' : 'Write latency',
					$v_ref->id->instance, 
					$dsname,
					$v_ref->value,
					avg(split(',',$v_ref->value)) if ($opt_debug);
				
				if (defined($latency_values{$v_ref->id->counterId})) {
					$latency_values{$v_ref->id->counterId} = join(',', ($v_ref->value,$latency_values{$v_ref->id->counterId}));
				} else {
					$latency_values{$v_ref->id->counterId} = $v_ref->value;
				}
			}
		}
	}
	printf ("[INFO] show latency info: %.3fs\n\n\n", time()-$t0) if ($opt_debug);
}

# Summary:
# --------
print "=" x 132, "\n" if ($opt_debug);
my $average_latency;
my $latency_type;
my $exit_code = -1;
my @i_performance;
my @i_status;

foreach my $l_ref (sort(keys(%latency_values))) {
	$average_latency = avg(split(',',$latency_values{$l_ref}));
	$latency_type = $l_ref eq "144" ? 'Read' : 'Write';


	printf "%s --- %s --- %s --> %8.3f\n",
		$latency_type,	
		join(',',@opt_datastore),
		$latency_values{$l_ref},
		$average_latency if ($opt_debug);

	push (@i_performance, sprintf "%s=%.5fs", $latency_type, $average_latency/1000);	

	if ($average_latency > Opts::get_option('c')) {
		printf "Critical: %s > %i ms (%8.3f)\n",
			$latency_type,
			Opts::get_option('c'),
			$average_latency if ($opt_debug);

		# Criticals first in the list:
		unshift (@i_status, sprintf "(%s CRITITCAL %.3fms > %ims)",
			$latency_type,
			$average_latency,
			Opts::get_option('c')
		);
		$exit_code = 2 unless $exit_code > 2;

	} elsif ($average_latency > Opts::get_option('w')) {
		printf "Warning: %s > %i ms (%8.3f)\n",
			$latency_type,
			Opts::get_option('w'),
			$average_latency if ($opt_debug);

		# Warnings to to end:
		push (@i_status, sprintf "(%s WARNING %.3fms > %ims)",
			$latency_type,
			$average_latency,
			Opts::get_option('w')
		);
		$exit_code = 1 unless $exit_code > 1;

	} else {
		printf "OK: %s = %8.3f\n",
			$latency_type,
			$average_latency if ($opt_debug);

		# no stats

		$exit_code = 0 unless $exit_code > 0;
	}
}

# return 
#
$exit_code = 3 if ($exit_code < 0);
push (@i_status, "") if ($exit_code == 0);
push (@i_status, "UNKNOWN") if ($exit_code == 3);

my @exit_txt = qw (OK WARNING CRITICAL UNKNOWN);
printf "Latency %s %s | %s\n",
 	$exit_txt[$exit_code],
	join (' ', @i_status),
	join (' ', @i_performance);
	
# logout
Vim::logout();

print "EXIT CODE=",$exit_code,"\n";
exit ($exit_code);

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}
