#!/usr/bin/perl

use warnings;
use strict;
use Net::SNMP;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
my %opt;

my $msg = "";
my $rc = 3;

# defaults
$opt{'community'} = "public";

#
GetOptions (
    "host=s"      => \$opt{'host'},
    "community=s" => \$opt{'community'},
    "vpnname=s"   => \$opt{'vpnname'},
    "debug"       => \$opt{'debug'},
    "help|?"      => \$opt{'help'},
    "man"         => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

foreach my $o (qw(host vpnname)) {
    unless (defined($opt{$o})) {
        printf "--%s is required\n", $o;
        $rc = 1;
    }
}
exit 3 if $rc <3;


my ($session, $error) = Net::SNMP->session(
        -hostname  => $opt{'host'},
        -community => $opt{'community'},
        -port      => 161
   );

if (!defined($session)) {
        printf("ERROR: %s.\n", $error);
        exit 2;
}

my $oid;
my $response = $session->get_table('1.3.6.1.4.1.12356.101.12.2.2.1.2');
unless (defined($response)) {
	print "SNMP request failed\n";
	exit 3;
}
foreach my $k (keys($response)) {
	printf "%s = %s\n", $k, $response->{$k} if ($opt{'debug'});
	if ($response->{$k} eq $opt{'vpnname'}) {
		printf "found %s in %s\n", $opt{'vpnname'}, $k if ($opt{'debug'});
		$oid = $k;
		last;
	}
}

if (defined($oid)) { # VPN found
	# rewrite OID to match VPN status (.2. -> .20.)
	$oid =~ s/^1\.3\.6\.1\.4\.1\.12356\.101\.12\.2\.2\.1\.2\./1.3.6.1.4.1.12356.101.12.2.2.1.20./;
	
	$response = $session->get_request($oid);
	unless (defined($response)) {
		printf ("SNMP request %s failed\n", $oid);
		exit 3;
	}
	my $vlanStatus = $response->{$oid} == 2;
	$msg = sprintf ("VPN %s is %s", $opt{'vpnname'}, $vlanStatus ? "up" : "down" );
	$rc = $vlanStatus ? 0 : 2;
} else {
	$msg = sprintf "VPN %s not defined/found", $opt{'vpnname'};
	$rc = 3;
}


print "$msg\n";
exit $rc;


__END__

=head1 NAME

VPN Check

=head1 SYNOPSIS

usage:

=head1 OPTIONS

=over 8

=item B<--debug>
   
   Print Debugging Information

=item B<--help>

   Print a brief help message and exits.

=item B<--man>
   Prints the manual page and exits.

=back

=head1 DESCRIPTION

description of vpn check

=cut
