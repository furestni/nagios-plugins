#! /usr/bin/perl -w
#
# check_fortigate_session 
#
# nagios: +epn
###############
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
###############
# Bruderer Research GmbH
# Report bugs to: brudy@bruderer-research.com
#
# This plugin is based on the work of many people
###############

use strict;
use lib "/usr/lib/nagios/plugins";
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;
use Getopt::Long;
Getopt::Long::config('bundling');

my %max = (
	'30B' 	=> 5000,
	'50B' 	=> 25000,
	'60B' 	=> 70000,
	'60C' 	=> 400000,
	'100A'	=> 200000,
	'110C'	=> 400000,
	'100D'	=> 500000,
	'111C'	=> 400000,
	'200A'	=> 400000,
	'200B'	=> 500000,
	'224B'	=> 400000,
	'300A'	=> 400000,
	'400A'	=> 400000,
	'500A'	=> 400000,
	'310B'	=> 500000,
	'1000'	=> 1000000,
	'1000C'	=> 7000000,
	'3016B'	=> 2000000,
	'3040B'	=> 10000000,
	'NA'	=> 500000,
);

my $PROGNAME = "check_fortigate_session";
#my $oid = '.1.3.6.1.4.1.12356.1.10.0';
my $oid = '.1.3.6.1.4.1.12356.101.4.1.8.0';
my $typ =  '.1.3.6.1.2.1.47.1.2.1.1.2.1';
my $community = "public";
my $port = 161;
my $snmp_version = 2;
my $state = 'UNKNOWN';
my $answer = 'no data';
my @snmpoids;
my $hostname;
my $session;
my $error;
my $result;
my $current = 0;
my $opt_h;
my $opt_w;
my $opt_c;

$SIG{'ALRM'} = sub {
	print ("ERROR: No snmp response from $hostname (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

GetOptions(
	"w=i" => \$opt_w,        "warning=i"      => \$opt_w,
	"c=i" => \$opt_c,        "critical=i"     => \$opt_c,
	"h"   => \$opt_h,        "help"           => \$opt_h,
	"v=i" => \$snmp_version, "snmp_version=i" => \$snmp_version,
	"C=s" => \$community,    "community=s"    => \$community,
	"p=i" => \$port,         "port=i"         => \$port,
	"H=s" => \$hostname,     "hostname=s"     => \$hostname
) or print_help();

if ($opt_h) { print_help(); }

if (!utils::is_hostname($hostname)) { usage(); }

if ($snmp_version > 0 && $snmp_version < 3) {
	($session, $error) = Net::SNMP->session(
		-hostname  => $hostname,
		-community => $community,
		-port      => $port,
		-version   => $snmp_version);

	if (defined($session)) {
		push(@snmpoids,$typ);
		push(@snmpoids,$oid);
		if (defined($result = $session->get_request(@snmpoids))) {
			my ($device) = $result->{$typ} =~ /\s+Fortigate-(\S+)\s+v/;
			$device = "NA" if !$device;
			$opt_w = $max{$device} * 0.75 if !$opt_w;
			$opt_c = $max{$device} * 0.9 if !$opt_c;
			$current = $result->{$oid} if $result->{$oid};
			$current = $max{$device} if $result->{$oid} > $max{$device};
			$answer = sprintf("host '%s', sessions used: %d/%d |sessions=%d;%d;%d;%d\n",
			       $hostname,
			       $result->{$oid},
			       $max{$device},
			       $result->{$oid},
			       int($opt_w),
			       int($opt_c),
			       $max{$device},
			);
			if ( $result->{$oid} <= $opt_w ) {
				$state = 'OK';
			} elsif ( $result->{$oid} <= $opt_c ) {
				$state = 'WARNING';
			} else {
				$state = 'CRITICAL';
			}
		} 
	} 
	$session->close;
} else {
	print_help();
}

print ("$state: $answer");
exit $ERRORS{$state};

sub usage {
	printf "\nMissing arguments!\n";
	printf "\n";
	printf "usage: \n";
	printf "$PROGNAME -H <HOSTNAME> [-C <community>] [-w warning] [-c critical]\n";
	printf "For help, try: $PROGNAME -h \n";
	printf "Copyright (C) 2008 Peter Bruderer\n";
	printf "$PROGNAME comes with ABSOLUTELY NO WARRANTY\n";
	printf "This programm is licensed under the terms of the ";
	printf "GNU General Public License\n(check source code for details)\n";
	printf "\n\n";
	exit $ERRORS{'UNKNOWN'};
}

sub print_help {
	printf "$PROGNAME: Nagios plugin to monitor the session usage of a Fortinet firewall\n";
	printf "\nUsage:\n";
	printf "   -H (--hostname)   Hostname to query - (required)\n";
	printf "   -C (--community)  SNMP read community <- defaults to public,\n";
	printf "                     used with SNMP v1 and v2c\n";
        printf "   -w                integer threshold for warning level on sessions used <- defaults to 75% of maximum possible\n";
        printf "   -c                integer threshold for critical level on sessions used <- defaults to 90 % of maximum possible\n";
	printf "   -v (--snmp_version)  1 for SNMP v1\n";
	printf "                        2 for SNMP v2c (default)\n";
	printf "   -p (--port)       SNMP port (default 161)\n";
	printf "   -h (--help)       usage help \n\n";
	print_revision($PROGNAME, '$Revision: 1.0 $');
	exit $ERRORS{'OK'};
}

