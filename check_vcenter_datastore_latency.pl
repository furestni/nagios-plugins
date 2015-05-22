#!/usr/bin/perl -w
#
# Auswertung Performance per ESX Host und datastore
#
# based on 
# viperformance.pl - Retrieves performance counters from a host.
# # Copyright (c) 2007 VMware, Inc.  All rights reserved.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";
use lib '/usr/lib/vmware-vcli/apps';
use List::Util qw( sum max );
use VMware::VIRuntime;
use AppUtil::HostUtil;
use AppUtil::VMUtil;

$Util::script_version = "1.0";

sub retrieve_performance($);
sub getConfigFile($);

sub avg { sum(@_)/@_ }

my %vc;
my %ptotal;
my $opt_samples = 30; ## 5 min = 30
my $opt_debug = 0;
my $opt_verbose = 0;

my %opts = (
   'datacenter' => {
	type => "=s",
	help => "name of the datacenter",
	required => 1,
   },
   'cluster' => {
      type => "=s",
      help => "Name of the cluster",
      required => 1,
   },
#   'countertype' => {
#      type => "=s",
#      help => "Counter type [cpu | mem | net | disk | sys]",
#      required => 1,
#   },
   'interval' => {
      type => "=i",
      help => "Interval in seconds",
      required => 0,
   },
#   'instance' => {
#      type => "=s",
#      help => "Name of instance to query",
#      required => 0,
#   },
#   'samples' => {
#      type => "=s",
#      help => "Number of samples to retrieve",
#      required => 0,
#      default => 10,
#   },
   'out' => {
      type => "=s",
      help => "Name of file to hold output",
      required => 0,
   },
);

sub getInstanceFile($) {
        my ($fn) = @_;
        my %i;
        open (IF, "<$fn") || die "Instance file not found\n";

        while (<IF>) {
                chomp;
                my ($id,$nickname,$other) = split(':');
                $i{$id}{'nickname'} = $nickname;
        }
        close (IF);
#	print Dumper \%i ;
	
        return %i;
}



%vc = getConfigFile ('/usr/lib64/nagios/plugins/check_vcenter_datastore_latency.cluster');
my %instanceInfo = getInstanceFile('/usr/lib64/nagios/plugins/check_vcenter_datastore_latency.instance');


Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

my $all_counters;

#
# Show Config Info:
#

print Dumper \%vc if ($opt_debug);

# Wir holen die Performance Informationen für alle Hosts 
my $esxhost;
if (!defined($vc{Opts::get_option('datacenter')})) {
	
	die "Unknown Datacenter:".Opts::get_option('datacenter');
}

if (!defined($vc{Opts::get_option('datacenter')}{Opts::get_option('cluster')})) {

	die "Unknown Cluster: ".Opts::get_option('cluster');
}


Util::connect();


foreach $esxhost (sort(@{$vc{Opts::get_option('datacenter')}{Opts::get_option('cluster')}})) {
	print "Processing: $esxhost\n" if ($opt_verbose);
	retrieve_performance($esxhost);
}



print_log ("\nSUMMARY") if ($opt_verbose);
print_log ("=" x 80) if ($opt_verbose);

### OK - DISABLED - used% = 91.6%, limit = 102400.00 GB, free = 8606.90 GB, used = 93793.10 GB | used%= 91.6% ; QuotaTotal=102400.000G ; QuotaFree=8606.900G ; QuotaUsage=93793.100G
#
my @lines;
my $j;
my $k1;
my $v;
my $line;
my @al;
my $icinga;
my $valname;
foreach $j (keys(%ptotal)) {
	foreach $k1 (keys(%{$ptotal{$j}})) {

        	$line = sprintf ("%-30s %-50s %-20s:", Opts::get_option('cluster'), $j, $k1);
		$valname = join (":", $k1, $j);
		$valname =~ s/ /_/;



		foreach $v (@{$ptotal{$j}{$k1}}) {
			$line .= sprintf (" %4d",$v);
		}

	
	          
		$line.=sprintf ("   avg: %5.1f   max: %5s", avg(@{$ptotal{$j}{$k1}}), max(@{$ptotal{$j}{$k1}}));


                push (@lines, $line);

		$icinga .= sprintf ("%s=%.5fs ", $valname, avg(@{$ptotal{$j}{$k1}})/1000);
	}
}

foreach (sort(@lines)) {
        print_log($_) if ($opt_verbose);
}

print_log (sprintf ("OK - %s graph only | %s", Opts::get_option('cluster'), $icinga));




#print Dumper \%ptotal;

Util::disconnect();

sub retrieve_config() {
	my $c = Vim::find_entity_view(view_type => "HostSystem"
	)

}
sub retrieve_performance($) {
	my ($hostname) = @_;

   my $host = Vim::find_entity_view(view_type => "HostSystem",
                                    filter => {'name' => $hostname});
   if (!defined($host)) {
      Util::trace(0,"Host ".$hostname." not found.\n");
      return;
   }

	#open (OUT,  ">$hostname-HostSystem");
	#print OUT Dumper \$host;
	#close (OUT);

   my $perfmgr_view = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
   
   my @perf_metric_ids = get_perf_metric_ids(perfmgr_view=>$perfmgr_view,
                                             host => $host,
                                             type => 'datastore'); ## Opts::get_option('countertype'));

	#open (OUT,  ">$hostname-metric");
	#print OUT Dumper \@perf_metric_ids;
	#close (OUT);

 
   my $perf_query_spec;
   if(defined Opts::get_option('interval')) {
      $perf_query_spec = PerfQuerySpec->new(entity => $host,
                                            metricId => @perf_metric_ids,
                                            'format' => 'csv',
                                            intervalId => Opts::get_option('interval'),
                                            maxSample => $opt_samples) ;
   }
   else {
      my $intervals = get_available_intervals(perfmgr_view => $perfmgr_view,
                                              host => $host);
      $perf_query_spec = PerfQuerySpec->new(entity => $host,
                                            metricId => @perf_metric_ids,
                                            'format' => 'csv',
                                            intervalId => shift @$intervals,
                                            maxSample => $opt_samples);
   }

   if(defined Opts::get_option('out')) {
      my $filename = Opts::get_option('out')."-".Opts::get_option('cluster')."-".$hostname;
      open(OUTFILE, ">$filename");
   }
   my $perf_data;
   eval {
       $perf_data = $perfmgr_view->QueryPerf( querySpec => $perf_query_spec);
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidArgument') {
            Util::trace(0,"Specified parameters are not correct");
         }
      }
      return;
   }
   if (! @$perf_data) {
      Util::trace(0,"Either Performance data not available for requested period "
                    ."or instance is invalid\n");
      my $intervals = get_available_intervals(perfmgr_view=>$perfmgr_view,
                                           host => $host);
      Util::trace(0,"\nAvailable Intervals\n");
      foreach(@$intervals) {
         Util::trace(0,"Interval " . $_ . "\n");
      }
      return;
   }

	
   foreach (@$perf_data) {
      print_log("Performance data for: " . $host->name . "\n") if ($opt_verbose);
      my $time_stamps = $_->sampleInfoCSV;
	$time_stamps =~ s/,20,/,/g;
	$time_stamps =~ s/^20,//;
	$time_stamps =~ s/T/ /g;
	$time_stamps =~ s/Z//g;

      my $values = $_->value;
      my @outlines = ();
      foreach (@$values) {
		if (($_->id->counterId == 144) || ($_->id->counterId == 145)) {
		#if (($_->id->counterId == 578) || ($_->id->counterId == 579)) {
			my $txt1 = defined($instanceInfo{$_->id->instance}{'nickname'}) ? $instanceInfo{$_->id->instance}{'nickname'} : $_->id->instance;
		         #print_counter_info($_->id->counterId, $_->id->instance);
		         # time stamp not required at the moment: print_log($txt1.",".$all_counters->{$_->id->counterId}->nameInfo->label."," . $time_stamps);
		         my $t1 = sprintf ("%-30s %-50s %-20s:", $host->name, $txt1, $all_counters->{$_->id->counterId}->nameInfo->label);
			
			my @hval = split(',',$_->value);

			for my $h ( 0 .. $#hval ) {
				
				$ptotal{$txt1}{$all_counters->{$_->id->counterId}->nameInfo->label}[$h] = max(
											defined($ptotal{$txt1}{$all_counters->{$_->id->counterId}->nameInfo->label}[$h]) ? $ptotal{$txt1}{$all_counters->{$_->id->counterId}->nameInfo->label}[$h] : 0
											 , $hval[$h]
														);
				$t1.=sprintf (" %4d",$hval[$h]);
	
			}
#			foreach $val (split(',',$_->value)) {
#				$t1.=sprintf (" %4d",$val);
#
#				
#			}
			$t1.=sprintf ("   avg: %5.1f   max: %5s", avg(split(',',$_->value)), max(split(',',$_->value)));
			
			push (@outlines, $t1);

		} else {
			printf ("Id:%s Hint:%s\n", $_->id->counterId, $all_counters->{$_->id->counterId}->nameInfo->label) if ($opt_debug);
		}
	
      }
 	if ($opt_verbose) {
	foreach (sort(@outlines)) {
	print_log($_);
	}
	}


   }
}

sub print_counter_info {
   my ($counter_id, $instance) = @_;

   my $counter = $all_counters->{$counter_id};
   print_log("Counter: " . $counter->nameInfo->label);
   print_log("CounterID: " . $counter_id);
   if (defined $instance) {
      print_log("Instance : " . $instance);
   }
   print_log("Description: " . $counter->nameInfo->summary);
   print_log("Units: " . $counter->unitInfo->label);

}

sub get_perf_metric_ids {
   my %args = @_;
   my $perfmgr_view = $args{perfmgr_view};
   my $entity = $args{host};
   my $type = $args{type};

   my $counters;
   my @filtered_list;
   my $perfCounterInfo = $perfmgr_view->perfCounter;
   my $availmetricid = $perfmgr_view->QueryAvailablePerfMetric(entity => $entity);
   
   foreach (@$perfCounterInfo) {
      my $key = $_->key;
      $all_counters->{ $key } = $_;
      my $group_info = $_->groupInfo;
      if ($group_info->key eq $type) {
         $counters->{ $key } = $_;
      } 
   }
   
   foreach (@$availmetricid) {
      if (exists $counters->{$_->counterId}) {
         #push @filtered_list, $_;
         my $metric = PerfMetricId->new (counterId => $_->counterId,
                                          instance => '*');
         push @filtered_list, $metric;
      }
   }
   return \@filtered_list;
}

sub get_available_intervals {
   my %args = @_;
   my $perfmgr_view = $args{perfmgr_view};
   my $entity = $args{host};
   
   my $historical_intervals = $perfmgr_view->historicalInterval;
   my $provider_summary = $perfmgr_view->QueryPerfProviderSummary(entity => $entity);
   my @intervals;
   if ($provider_summary->refreshRate) {
      push @intervals, $provider_summary->refreshRate;
   }
   foreach (@$historical_intervals) {
      push @intervals, $_->samplingPeriod;
   }
   return \@intervals;
}

sub validate {
   my $valid = 1;
#   if (Opts::option_is_set('countertype')) {
#      my $ctype = Opts::get_option('countertype');
#      if(!(($ctype eq 'cpu') || ($ctype eq  'mem') || ($ctype eq 'net') || ($ctype eq 'datastore')
#         || ($ctype eq 'disk') || ($ctype eq 'sys'))) {
#         Util::trace(0,"counter type must be [cpu | mem | net | disk | sys]");
#         $valid = 0;
#      }
#   }
   if (Opts::option_is_set('out')) {
     my $filename = Opts::get_option('out');
     if ((length($filename) == 0)) {
        Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
        $valid = 0;
     }
     else {
        open(OUTFILE, ">$filename");
        if ((length($filename) == 0) ||
          !(-e $filename && -r $filename && -T $filename)) {
           Util::trace(0, "\n'$filename' Not Valid:\n$@\n");
           $valid = 0;
        }
     }
  }
  return $valid;
}

sub print_log {
   my ($prop) = @_;
   if (defined (Opts::get_option('out'))) {
      print OUTFILE  $prop."\n";
   }
   else {
      Util::trace(0, $prop." \n");
   }
}


#### Eigene Erweiterung #####

sub getConfigFile($){
        my ($fn) = @_;
        my %cfg;
        open (CF, "<$fn") || die "Configfile not found\n";

        while (<CF>) {
                chomp;
		next if (/^\s*#/);
                my ($dc,$cluster,$host) = split(':');
                push (@{$cfg{$dc}{$cluster}}, $host);
        }
        close (CF);
        return %cfg;
}


__END__

## bug 217605

=head1 NAME

viperformance.pl - Retrieves performance counters from a host.

=head1 SYNOPSIS

 viperformance.pl [options]

=head1 DESCRIPTION

This VI Perl command-line utility provides an interface to retrieve
performance counters from the specified host. Performance counters
shows these primary attributes: CPU Usage, Memory Usage, Disk I/O Usage,
Network I/O Usage, and System Usage.

=head1 OPTIONS

=over

=item B<Host>

Required. Name of the host.

=item B<countertype>

Required. Counter type [cpu | mem | net | disk | sys].

=item B<interval>

Optional. Interval in seconds. 

=item B<samples>

Optional. Number of samples to retrieve. Default: 10

=item B<instance>

Optional. Name of instance to query. Default: Aggregate of all instance.
          Specify '*' for all the instances.

=item B<out>

Optional. Name of the filename to hold the output.

=back

=head1 EXAMPLES
