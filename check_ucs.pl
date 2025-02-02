#!/usr/bin/perl
# UCS SNMP Monitoring
# by Petr Havlicek
# Created 23rd March 2012
# Script for SNMP monitoring Cisco UCS servers

# Version 2.0.2 23rd January 2013
# - Minor bug fixes

# Version 2.0.1 - 22nd January 2013
# - Added some user input checks
# - Object name comapring case insensitive

# Version 2.0 - 4th January 2013
# - Complete re-design of internal functionality
# - Now first step is getting sub-tree
# - Second step is getting descriptions for all OID in sub-tree
# - Third is filter sub tree by specific description
# - Last step is getting results state for specific OIDs

# Version 1.3 - 16th November 2012
# - Add support for checking faults

# Version 1.2 - 21st August 2012
# - Based on OID prefix for specific device => No manual OID specification
# - Using manual prefix definitation
# - Remove PSU Temperature test
# - Bugfixes

# Version: 1.1.1 - 7th August 2012
# - Monitoring fan modules insteed individuals fans

# Version: 1.1 - 18th June 2012
# - Add support for prinitg description of monitored objects
# - Minor bugfixes

use Getopt::Std;
use Net::SNMP qw(oid_base_match);
use strict;

# Constants for tests prefixes
use constant {
	CT	=> ".1.3.6.1.4.1.9.9.719.1.15.7.1.33",
	CI	=> ".1.3.6.1.4.1.9.9.719.1.15.30.1.25",
	F	=> ".1.3.6.1.4.1.9.9.719.1.15.13.1.7",
	PO	=> ".1.3.6.1.4.1.9.9.719.1.15.56.1.7",
	FS	=> ".1.3.6.1.4.1.9.9.719.1.1.1.1.20",
};

# Constants for NAGIOS status code
use constant {
	NAGIOS_OK	=> 0,
	NAGIOS_WARNING	=> 1,
	NAGIOS_CRITICAL	=> 2,
	NAGIOS_UNKNOWN	=> 3,
};

our($opt_h, $opt_H, $opt_C, $opt_T, $opt_N);
getopts('hH:C:T:N:');


# User input checks
if($opt_h) { print_help(); exit; }
if($opt_H eq "") { print_help(); print "Missing host address (-H)\n"; exit; }
if($opt_C eq "") { print_help(); print "Missing SNMP community (-C)\n"; exit; }
if($opt_T eq "") { print_help(); print "Missing test type (-T)\n"; exit; }
if($opt_T ne "fs") {
	if($opt_N eq "") { print_help(); print "Missing object name (-N)\n"; exit; }
}

my $host = $opt_H;
my $community = $opt_C;
my $type = $opt_T;
my $name = $opt_N;

# Select correct object prefix
if($type eq "fs") { $name = " "; }

# Test definitation
my $test="";
my $oid_prefix = "";

if($type eq "ct") {
	$test = "Temperature";
	$oid_prefix = CT; }
elsif($type eq "ci") {
	$test = "IOCard";
	$oid_prefix = CI; }
elsif($type eq "f") {
	$test= "Fan";
	$oid_prefix = F; }
elsif($type eq "po") {
	$test = "PSU"; 
	$oid_prefix = PO; }
elsif($type eq "fs") {
        $test = "Faults";
        $oid_prefix = FS; }

my $oid = $oid_prefix;

# Get informations via SNMP
(my $session,my $error) = Net::SNMP->session( Hostname => $host, Version => '2', Community => $community );
if (!defined $session){
	printf "Connection Error: %s.\n", $error;
	exit NAGIOS_UNKNOWN;
}

# Get OID for whole subtree
my @oids_all;
my $response;
while (defined($session->get_next_request($oid))) {
	$response = ($session->var_bind_names)[0];
	if(!oid_base_match($oid_prefix, $response)) { last; }
	push @oids_all, $response;
	$oid = $response;
}

# Get descriptions
my $get;
my @descs;
foreach (@oids_all) {
	$oid = $_;
	if($type eq "fs") { $oid =~ s/\d+(\.\d{5,8})$/11\1/; }
	else { $oid =~ s/\d+(\.\d{5,8})$/2\1/; }
	$get = $session->get_request("$oid");
	if (!defined $get) {
		printf "SNMP Error: %s.\n at OID: $_\n", $session->error();
		$session->close();
		exit NAGIOS_UNKNOWN;
	}
	push(@descs, $get->{$oid});
}

# Filter relevant information
my @descriptions;
my @oids;
for(my $i = 0; $i < @descs; $i++) {
	if(@descs[$i] =~ /$name/i) {
		push(@descriptions, @descs[$i]);
		push(@oids, @oids_all[$i]);
	}
}

# Get results for selected host
my @results;
for (my $i = 0; $i < @descriptions; $i++)  {
        $oid = @oids[$i]; 
	$get = $session->get_request("$oid");
        if (!defined $get) {
                printf "SNMP Error: %s.\n at OID: $_\n", $session->error();
                $session->close();
                exit NAGIOS_UNKNOWN;
        }
        push(@results, $get->{$oid});
}
$session->close;
	
if(int(@results) eq 0) {
	print "No OID match! Check your -H and -N or -T\n";
	exit NAGIOS_UNKNOWN;
}
# Validation results
my $exit_state = NAGIOS_OK;
my $output = "Problem with $test at";
if($type eq "fs") { $output = "Faults found!\n"; }

for (my $i=0; $i < @results; $i++) {
	if($type eq "fs") {
		if($results[$i] > 4) {
			$exit_state = NAGIOS_CRITICAL;
			$output .= " " . $descriptions[$i] . "\n";
		}
		next;
	}
	if($results[$i] < 1) {
		if(($type eq "po") || ($exit_state == NAGIOS_CRITICAL)) { $exit_state = NAGIOS_CRITICAL; }
		else { $exit_state= NAGIOS_WARNING; }
		$output .= " " . $descriptions[$i];
	}
	elsif($results[$i] > 1) {
		$exit_state = NAGIOS_CRITICAL;
		$output .= " " . $descriptions[$i];
	}
}
if($exit_state == NAGIOS_OK) { print int(@results). " objects OK\n"; }
else { print "$output.\n"; }
exit $exit_state;

sub print_help {
	print "Nagios plugin for monitoring Cisco UCS systems\n";
	print "Created 2012 by Petr Havlicek\n";
	print "\nUSAGE: -H <HOST_IP> -C <COMMUNITY> -T <TYPE> -N <OBJECT_NAME>\n";
        print "\nTypes:\n";
        print "\t ct - Chassis Temperature\n";
        print "\t ci - Chassis IOCard Status\n";
        print "\t f - Fans Status\n";
        print "\t po - PSUs Operate Status\n";
        print "\t fs - Faults Summary (Dont need -N)\n";
        print "\n";
	print "Fabric Interconnects support only these test: f, po\n";
	print "Object name examples: switch, switch-A, switch-B, chassis-1, chassis-10\n";
	print "\n";
}

