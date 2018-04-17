#!/usr/bin/perl
# 
# check_snmp_cumulus_interfaces.pl
# --------------------------------
use warnings;
use strict;
use Net::SNMP;
#use Data::Dumper;
use Getopt::Long;
use JSON;
use Pod::Usage;
my %opt;

my @msg;
my $rc = 3;

# defaults
$opt{'community'} = "public";


my @txtOperStatus = qw(zero up down testing unknown dormant notPresent lowerLayerDown);
my @txtAdminStatus = qw(zero up down testing);

#
GetOptions (
    "host=s"      => \$opt{'host'},
    "community=s" => \$opt{'community'},
#    "debug"       => \$opt{'debug'},
    "help|?"      => \$opt{'help'},
    "man"         => \$opt{'man'},
	"tofile=s"    => \$opt{'tofile'},
	"fromfile=s"  => \$opt{'fromfile'},
	"ignore=s"	  => \$opt{'ignore'},
	"verbose"     => \$opt{'verbose'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

foreach my $o (qw(host)) {
    unless (defined($opt{$o})) {
        printf "--%s is required\n", $o;
        $rc = 1;
    }
}

if (defined($opt{'fromfile'}) && defined($opt{'tofile'})) {
	print "--fromfile and --tofile can not be used together.\n";
	$rc = 1;
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

my $response;

if (defined($opt{'fromfile'})) {
	open (IN_FILE, "<".$opt{'fromfile'}."_ifAlias.json");
	$response->{'ifAlias'} = from_json(<IN_FILE>);
	close (IN_FILE);
	open (IN_FILE, "<".$opt{'fromfile'}."_ifAdminStatus.json");
	$response->{'ifAdminStatus'} = from_json(<IN_FILE>);
	close (IN_FILE);
    open (IN_FILE, "<".$opt{'fromfile'}."_ifOperStatus.json");
    $response->{'ifOperStatus'} = from_json(<IN_FILE>);
    close (IN_FILE);
} else {
	$response->{'ifAlias'} = $session->get_table(-baseoid => '.1.3.6.1.2.1.31.1.1.1.18');
	unless (defined($response->{'ifAlias'})) {
	    print "SNMP request for ifAlias failed\n";
		exit 2;
	}
	$response->{'ifAdminStatus'} = $session->get_table(-baseoid => '.1.3.6.1.2.1.2.2.1.7');
	unless (defined($response->{'ifAdminStatus'})) {
		print "SNMP request for ifAdminStatus failed\n";
		exit 2;
	}
	$response->{'ifOperStatus'} = $session->get_table(-baseoid => '.1.3.6.1.2.1.2.2.1.8');
	unless (defined($response->{'ifOperStatus'})) {
		print "SNMP request for ifOperStatus failed\n";
		exit 2;
	}
}

if (defined($opt{'tofile'})) {
	open (OUT_FILE, ">".$opt{'tofile'}."_ifAlias.json");
	print OUT_FILE to_json($response->{'ifAlias'});
	close (OUT_FILE);
    open (OUT_FILE, ">".$opt{'tofile'}."_ifAdminStatus.json");
    print OUT_FILE to_json($response->{'ifAdminStatus'});
    close (OUT_FILE);    
	open (OUT_FILE, ">".$opt{'tofile'}."_ifOperStatus.json");
    print OUT_FILE to_json($response->{'ifOperStatus'});
    close (OUT_FILE);
}

my $idLong;
my $idShort;
my $interface;
my $counter;

foreach my $idLong (keys($response->{'ifAdminStatus'})) {
	$idShort = $idLong;
    $idShort =~ s/^\.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.//;
	$interface->{$idShort}{'ifAdminStatus'} = $response->{'ifAdminStatus'}{$idLong};
	# increment counter for found state 
	$counter->{'ifStatusCounter'}{"AdminState_".$txtAdminStatus[$response->{'ifAdminStatus'}{$idLong}]}++;
}

foreach my $idLong (keys($response->{'ifOperStatus'})) {
    $idShort = $idLong;
   	$idShort =~ s/^\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.//;
    $interface->{$idShort}{'ifOperStatus'} = $response->{'ifOperStatus'}{$idLong};
	# increment counter for found state 
	$counter->{'ifStatusCounter'}{"OperState_".$txtOperStatus[$response->{'ifOperStatus'}{$idLong}]}++;
}

foreach my $idLong (keys($response->{'ifAlias'})) {
    $idShort = $idLong;
    $idShort =~ s/^\.1\.3\.6\.1\.2\.1\.31\.1\.1\.1\.18\.//;
    $interface->{$idShort}{'ifAlias'} = $response->{'ifAlias'}{$idLong};
	$interface->{$idShort}{'ifIgnore'} = defined($opt{'ignore'}) ? grep (/^$response->{'ifAlias'}{$idLong}$/, split (",", $opt{'ignore'})) : 0;
}




$rc = 0;
foreach my $id (sort(keys($interface))) {
#	printf "%3d	  %-32s   %-20s %s\n", $id, $interface->{$id}{'ifAlias'}, $txtAdminStatus[$interface->{$id}{'ifAdminStatus'}], $txtOperStatus[$interface->{$id}{'ifOperStatus'}];
#	printf "%3d	  %-32s   %s\n", $id, $interface->{$id}{'ifAlias'}, $txtOperStatus[$interface->{$id}{'ifOperStatus'}] if ($interface->{$id}{'ifAdminStatus'} == 1);
	if (($interface->{$id}{'ifAdminStatus'} == 1) && ($interface->{$id}{'ifOperStatus'} != 1)) {
		printf "%3d	  %-32s   %s	%s\n", $id, $interface->{$id}{'ifAlias'}, $txtOperStatus[$interface->{$id}{'ifOperStatus'}], $interface->{$id}{'ifIgnore'} > 0 ? "(ignored)" : "" if ($opt{'verbose'});
		push(@msg, sprintf("%s=%s%s", $interface->{$id}{'ifAlias'}, $txtOperStatus[$interface->{$id}{'ifOperStatus'}], $interface->{$id}{'ifIgnore'} > 0 ? "(ignored)" : ""));
		$rc=2 if ($interface->{$id}{'ifIgnore'} == 0 );
	}
}

my @states;
foreach my $stateCounter (sort(keys($counter->{'ifStatusCounter'}))) {
	push (@states, sprintf("%s=%s", $stateCounter, $counter->{'ifStatusCounter'}{$stateCounter}));
}

printf "%s | %s\n", 
	$rc > 0 ? join (" ", @msg) : "ok",
	join (" ", @states);

exit $rc;

__END__

=head1 NAME

Check Port States of Cumulus Switch

=head1 SYNOPSIS

usage:

=head1 OPTIONS

=over 8

=item B<--host address>

    Hostname/IP for SNMP request

=item B<--community string>

    Community String, default: public

=item B<--ignore item{,item}>

	port alias names to ignore the actual state for monitoring

=item B<--tofile filename>

    Write SNMP output in JSON Format to given file

=item B<--fromfile filename>

    Read from given file SNMP input in JSON Format

=item B<--verbose>
   
    Print more information

=item B<--help>

    Print a brief help message and exits.

=item B<--man>

    Prints the manual page and exits.

=back

=head1 DESCRIPTION

Check Port State of Cumulus Switch. Print all Ports which are Admin UP and Operation State is not UP. If all Admin UP Ports are Operation State UP, just print OK.

=cut
