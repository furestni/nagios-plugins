#!/usr/bin/perl
# ============================================================================
# check_bgp_status.pl
# -------------------
# 
# ============================================================================
#use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use Net::OpenSSH;
use warnings;
use strict;


# ----------------------------------------------------------------------------
# Options
# ----------------------------------------------------------------------------
my %opt;

# -------------------------------------
# fetch Data
# -------------------------------------
sub fetchData {
	my ($host, $user, $pass) = @_;

	my $out;
	my $cmd = "sh ip bgp ipv4 unicast summary vrf all";

	my $session = Net::OpenSSH -> new(
		$host, 
		user => $user, 
		password => $pass, 
		master_stdout_discard => 1, 
		master_stderr_discard => 1, 
		timeout => 8,
		master_opts => [-o => "StrictHostKeyChecking=no"]
	);
	
	if ($session->error) {
		print "WARNING: Unable to open ssh connection: ".$session->error."\n";
		exit 1;
	}

	$out = $session->capture($cmd);

	return $out;
}

# -------------------------------------
# Parse Data
# -------------------------------------
sub parseData {
	my ($data) = @_;

	my $line;
	my $vrf;
	my $bgp;
	my ($neighbor,$v,$as,$msgRcvd,$msgSent,$tblVer,$inQ,$outQ,$uptime,$state);

	foreach $line (split (/\n/, $data)) {
		if ($line =~ m/BGP summary information for VRF (\w+)/) {
			$vrf = $1;
			$bgp->{$vrf}{'entries'}++;
			print "[DEBUG] VRF = $vrf\n" if ($opt{'verbose'});
		} elsif ($line =~ m/^\d+\.\d+\.\d+\.\d/) {
			($neighbor,$v,$as,$msgRcvd,$msgSent,$tblVer,$inQ,$outQ,$uptime,$state) = split (/\s+/,$line);
			print "[DEBUG] $neighbor,$v,$as,$msgRcvd,$msgSent,$tblVer,$inQ,$outQ,$uptime,$state\n" if ($opt{'verbose'});
			$bgp->{$vrf}{'neighbors'}++;
			$bgp->{$vrf}{'AS'}{$as}{'uptime'}=$uptime;
			$bgp->{$vrf}{'AS'}{$as}{'state'}=$state;
		} else {
			#print "[DEBUG] ignored line: $line\n";
		}
	}
	return $bgp;
}

	
# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
#

GetOptions (
	"host=s"     => \$opt{'host'},
	"user=s"     => \$opt{'user'},
	"pass=s"     => \$opt{'pass'},
	"check=s"	 => \$opt{'check'},
	"verbose"    => \$opt{'verbose'},
	"help|?"     => \$opt{'help'},
	"man"        => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

# check for required options
foreach my $k (qw/host user pass check/) {
	unless (defined($opt{$k})) {
		print "ERROR: --".$k." is required\n";
		exit 3;
	}
}

my $bgp = parseData(fetchData($opt{'host'},$opt{'user'},$opt{'pass'}));

my $i;
my $as;
my $vrf;
my @asList;
my @crit;
my @warn;
my @info;

foreach $i (split(/:/, $opt{'check'})) {
	($vrf,@asList) = split(/,/, $i);
	unless (defined($bgp->{$vrf})) {
		push @crit, sprintf ("%s missing", $vrf);
	} else {
		foreach $as (@asList) {
			if (defined($bgp->{$vrf}{'AS'}{$as})) {
				$bgp->{$vrf}{'AS'}{$as}{'checked'}++;
				if ($bgp->{$vrf}{'AS'}{$as}{'state'} =~ /idle/i) {
					push @crit, sprintf("%s:%s=IDLE(%s)", $vrf, $as, $bgp->{$vrf}{'AS'}{$as}{'uptime'}); 
				} elsif ($bgp->{$vrf}{'AS'}{$as}{'state'} =~ /admin/i) {
					push @info, sprintf("%s:%s=ADMIN-SHUT(%s)", $vrf, $as, $bgp->{$vrf}{'AS'}{$as}{'uptime'});
				} elsif ($bgp->{$vrf}{'AS'}{$as}{'state'} =~ /^0/) {
					push @crit, sprintf("%s:%s=%s(%s)", $vrf, $as, "0!", $bgp->{$vrf}{'AS'}{$as}{'uptime'});
				} else {
					push @info, sprintf("%s:%s=%s(%s)", $vrf, $as, $bgp->{$vrf}{'AS'}{$as}{'state'}, $bgp->{$vrf}{'AS'}{$as}{'uptime'});
				}
				if ($bgp->{$vrf}{'AS'}{$as}{'uptime'} !~ /\d/) {
					push @warn, sprintf("%s:%s=%s(%s!)", $vrf, $as, $bgp->{$vrf}{'AS'}{$as}{'state'}, $bgp->{$vrf}{'AS'}{$as}{'uptime'});
				}
			} else {
				push @crit, sprintf("%s:%s no neighbor", $vrf, $as);
			}
			
		}
	}
}

foreach $i (keys(%{$bgp})) {
	foreach $as (keys(%{$bgp->{$i}{'AS'}})) {
		next if (defined($bgp->{$i}{'AS'}{$as}{'checked'}));
		push @warn, sprintf ("%s:%s not expected", $i, $as);
	}
}

my $msg = "";
my $rc = 3;
if (scalar @crit > 0) {
	$msg = "CRITICAL: ".join (',',@crit);
	$rc = 2; # CRITICAL
}
if (scalar @warn > 0) {
	$msg .= " - " if ($msg ne "");
	$msg .= "WARNING: ".join (',',@warn);
	$rc = 1 if ($rc == 3);
}
if (scalar @info > 0) {
	$msg .= " - " if ($msg ne "");
	$msg .= "OK: ".join (',',@info);
	$rc = 0 if ($rc == 3);
}

print $msg."\n";
exit $rc;

__END__

=head1 NAME

check_bgp_status.pl -- check BGP Status on Nexus

=head1 SYNOPSIS

    check_bgp_status.pl [options] 
     Options:
       --help            brief help message
       --man             full documentation
       --host            host name
       --user            user name
       --pass            password
       --check           Expected BGP Status
       --verbose         verbose


=head1 OPTIONS

=over 8

=item B<--help>

    Print a brief help message and exits.

=item B<--man>

    Prints the manual page and exits.

=item B<--host>

	Host to check

=item B<--user>

	Username used for ssh

=item B<--pass>

	Password used for ssh

=item B<--check>

	Expected BGP Status.
	Syntax:
	VRF,AS[,AS][:VRF,AS[,AS]]

=item B<--verbose>

	Be more verbose

=back

=head1 DESCRIPTION
B<check_bgp_status.pl> checks the BGP status and compares it to the expected one
=cut

