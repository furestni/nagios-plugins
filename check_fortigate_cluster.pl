#! /usr/bin/perl -w
#
# check_fortigate_cluster 
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
use lib "/usr/local/icinga/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;
use Getopt::Long;
Getopt::Long::config('bundling');

my $PROGNAME = "check_fortigate_cluster";
#my $oid = '.1.3.6.1.4.1.12356.1.100.6.1.2';
my $oid = '.1.3.6.1.4.1.12356.101.13.2.1.1.1';
my $community = "public";
my $port = 161;
my $snmp_version = 1;
my $state = 'UNKNOWN';
my $answer = 'no data';
my $hostname;
my $session;
my $error;
my $result;
my $opt_h;
my $opt_d = 2;

$SIG{'ALRM'} = sub {
	print ("ERROR: No snmp response from $hostname (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

GetOptions(
	"d=i" => \$opt_d,        "devices=i"      => \$opt_d,
	"h"   => \$opt_h,        "help"           => \$opt_h,
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
		$result = $session->get_table( -baseoid => $oid );
		my %oids = %{$result};
		my @devices = '';
		my $serials = '';

		foreach my $key (sort(keys %oids)){
			push @devices, $oids{$key};
			$serials .= "$oids{$key} ";
		}

		if ( $#devices == $opt_d) {
			$state = 'OK';
			$answer = "All devices present - $serials";
		} else {
			$state = 'CRITICAL';
			$answer = "Not all devices in cluster $opt_d required, $#devices present - $serials";
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
	printf "$PROGNAME -H <HOSTNAME> [-C <community>] [-d devices]\n";
	printf "For help, try: $PROGNAME -h \n";
	printf "Copyright (C) 2008 Peter Bruderer\n";
	printf "$PROGNAME comes with ABSOLUTELY NO WARRANTY\n";
	printf "This programm is licensed under the terms of the ";
	printf "GNU General Public License\n(check source code for details)\n";
	printf "\n\n";
	exit $ERRORS{'UNKNOWN'};
}

sub print_help {
	printf "$PROGNAME: Nagios plugin to monitor the state of a Fortinet cluster\n";
	printf "\nUsage:\n";
	printf "   -H (--hostname)   Hostname to query - (required)\n";
	printf "   -C (--community)  SNMP read community <- defaults to public,\n";
	printf "                     used with SNMP v1 and v2c\n";
        printf "   -d (--devices)    number of devices in the cluster <- defaults to 2\n";
	printf "   -p (--port)       SNMP port (default 161)\n";
	printf "   -h (--help)       usage help \n\n";
	print_revision($PROGNAME, '$Revision: 1.0 $');
	exit $ERRORS{'OK'};
}

