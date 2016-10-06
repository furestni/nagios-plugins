#!/usr/bin/perl
# ============================================================================
# check_datastore_latency.pl
# ============================================================================
use strict;
use warnings;
use Getopt::Long;
use List::Util qw( sum );
use Storable qw(lock_retrieve);
use Data::Dumper;

# ---
# --- Global Variables
# ---
my $opt_esx;
my $opt_datastore;
my $opt_filename;
my $opt_w;
my $opt_c;
my $opt_help;
my $opt_dummy;

my $host_key;				# key to one ESX host hash
my @perf_metric_ids;			# array of performance metrics filter objects
my $perf_data;				# reference to performance data object
my @list_datastore;			# Array of datastores
my @list_esx;				# Array of ESX
my $opt_debug = 0;			# to show or not to show: debugging messages
my $esx_data;                           # datastructure for esx-data
my $file_esx_data = "/tmp/esx-data.dat"; # file name for esx data 
my $file_path = "/var/cache/icinga2/vcenter_data/"; # ensure this path exists with correct permissions

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

sub app_usage {
        print STDERR <<EndOfUsage;
--esx host,...,host	List of ESX hosts to query
--datastore 		List of Datastores to query
--filename          File containing cached data from get_vcenter_data.pl
-w                      Warning in ms
-c                      Critical in ms

EndOfUsage
        exit 3;
}



# ============================================================================
# === MAIN                                                                 ===
# ============================================================================

&app_usage if (!GetOptions (
	"esx=s"       => \$opt_esx,
	"datastore=s" => \$opt_datastore,
    "filename=s"  => \$opt_filename,
	"w=i"         => \$opt_w,
	"c=i"         => \$opt_c,
	"help"        => \$opt_help,
	"config=s"    => \$opt_dummy,
	"server=s"    => \$opt_dummy,
	"username=s"  => \$opt_dummy,
	"password=s"  => \$opt_dummy,
	"debug!"      => \$opt_debug,
) or $opt_help );

if (defined($opt_filename)) {
	$file_esx_data = $file_path.$opt_filename;
}

unless (-f $file_esx_data) {
	printf "datafile %s not found\n", $file_esx_data;
	exit 3;
}

$esx_data = lock_retrieve($file_esx_data);
unless (defined($esx_data)) {
	print "NO DATA\n";
	exit 3;
}
print Dumper $esx_data if ($opt_debug);

unless (defined($opt_esx) && defined($opt_datastore)) {
	print "--esx is required " unless (defined($opt_esx));
	print "--datastore is required " unless (defined($opt_datastore));
	print "\n";
	exit 3;
}



@list_datastore = split (/,\s*/, $opt_datastore);
@list_esx = split (/,\s*/, $opt_esx);

my %latency_values;
my $host_view;

foreach my $esx_key (@list_esx) {
	printf "[INFO] Processing ESX host %s\n", $esx_key if ($opt_debug); 

	#### Datastructure hint:
	#### $esx_data{$host_ref->name}{'datastore'}{$dsname}{$v_ref->id->counterId} = $v_ref->value;

	if ($opt_debug) {
		foreach my $ds_key (keys(%{$esx_data->{$esx_key}{'datastore'}})) {
			printf "[INFO] host %s has datastore %s\n", $esx_key, $ds_key;
		}
	}

	foreach my $ds_key (@list_datastore) {
		foreach my $p_key (sort(keys(%{$esx_data->{$esx_key}{'datastore'}{$ds_key}}))) {
			printf "%s --- %s --- %s --> %8.3f\n",
				$p_key eq "144" ? 'Read latency' : 'Write latency',
				$ds_key,
				$esx_data->{$esx_key}{'datastore'}{$ds_key}{$p_key},
				avg(split(',', $esx_data->{$esx_key}{'datastore'}{$ds_key}{$p_key})) if ($opt_debug);

			if (defined($latency_values{$p_key})) {
				$latency_values{$p_key} = join(',', ($esx_data->{$esx_key}{'datastore'}{$ds_key}{$p_key},$latency_values{$p_key}));
			} else {
				$latency_values{$p_key} = $esx_data->{$esx_key}{'datastore'}{$ds_key}{$p_key};
			}
		}

	}
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
		join(',',@list_datastore),
		$latency_values{$l_ref},
		$average_latency if ($opt_debug);

	push (@i_performance, sprintf "%s=%.5fs", $latency_type, $average_latency/1000);	

	if ($average_latency > $opt_c ) {
		printf "Critical: %s > %i ms (%8.3f)\n",
			$latency_type,
			$opt_c, 
			$average_latency if ($opt_debug);

		# Criticals first in the list:
		unshift (@i_status, sprintf "(%s CRITITCAL %.3fms > %ims)",
			$latency_type,
			$average_latency,
			$opt_c
		);
		$exit_code = 2 unless $exit_code > 2;

	} elsif ($average_latency > $opt_w) {
		printf "Warning: %s > %i ms (%8.3f)\n",
			$latency_type,
			$opt_w,
			$average_latency if ($opt_debug);

		# Warnings to to end:
		push (@i_status, sprintf "(%s WARNING %.3fms > %ims)",
			$latency_type,
			$average_latency,
			$opt_w
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
	
print "EXIT CODE=",$exit_code,"\n";
exit ($exit_code);

