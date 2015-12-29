#!/usr/bin/perl
use strict;
use warnings;
use Cisco::UCS;
use Getopt::Long;
use Pod::Usage;

my %opt;
my $ucs;
my $exitcode = 3;

########
# MAIN #
########

GetOptions (
        "cluster=s"	=> \$opt{'cluster'},
        "user=s"        => \$opt{'user'},
        "pass=s"        => \$opt{'pass'},
        "port=i"		=> \$opt{'port'},
		"ignore=s"		=> \$opt{'ignore'},
        "verbose"       => \$opt{'verbose'},
        "proto=s"     	=> \$opt{'proto'},
        "help|?"        => \$opt{'help'},
        "man"           => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{help};
pod2usage(-exitval => 3, -verbose => 2) if $opt{man};

# check options
foreach (qw(cluster user pass)) {
	unless (defined($opt{$_})) {
		printf "Parameter %s is required.\n", $_;
		exit 3;
	}
}

# defaults
$opt{'port'} = 80 unless defined($opt{'port'});
$opt{'proto'} = 'http' unless defined($opt{'proto'});
$opt{'verbose'} = 0 unless defined($opt{'verbose'});

$ucs = Cisco::UCS->new(	
	cluster  => $opt{'cluster'},
	port     => $opt{'port'},
	username => $opt{'user'},
	passwd   => $opt{'pass'},
	proto    => $opt{'proto'} 
);

unless ($ucs->login) {
	printf "Login to cluster %s failed.\n", $opt{'cluster'};
	exit 3;
}

my @out;
my %serv;
my %counter;
foreach my $error (reverse(sort { $a->id <=> $b->id } $ucs->get_errors)) {
#foreach my $error (@out) {
	next if (($error->cause eq 'identity-unestablishable') || ($error->severity eq "cleared"));
	next if ((defined($opt{'ignore'})) && (grep $error->dn =~ /$_/, split(',',$opt{'ignore'})));
	push @out, sprintf ("%s %s %s %s (ack:%s)\n",
		$error->created,
		$error->severity,
		$error->dn,
		$error->desc,
		$error->ack
	);
	$counter{$error->ack}++;
	$counter{'errors'}++;
	$serv{$error->ack eq 'yes' ? $error->severity.'_ack' : $error->severity}++;
}

if (@out == 0) {
	print "OK\n";
	$exitcode = 0;
} else {
	print join (", ", map { "$serv{$_} $_" } sort(keys(%serv))), "\n";
	print @out;
	$exitcode = 1;
}
# Close our session
$ucs->logout();

exit $exitcode;

__END__

=head1 NAME

	Icinga2 Check for UCS Event Log - check_ucs_events.pl

=head1 SYNOPSIS

    check_ucs_events.pl [options] 
     Options:
	--cluster       name or ip of ucs cluster
	--user          username
	--pass          password
	--port          port to use
    --ignore        entries to discard silently
    --verbose       verbose, what else?
    --proto         protocol to use http or https
	--help          brief help message
	--man           full documentation

=head1 OPTIONS

=over 8

=item B<--cluster>

IP or name of ucs to connect to (required)

=item B<--user>

Username for authentification (required)

=item B<--pass>

Password for authentifigcation (required)

=item B<--port>

Port to use, defaults to 80

=item B<--ignore>

Events to discard from event log, regex, comma seperated.
Example for Power Supply:
2011-01-07T11:48:38.129 warning sys/chassis-1/psu-4/fault-F0378 Power supply 4 in chassis 1 presence: missing (ack:yes)
2011-01-07T11:48:38.129 warning sys/chassis-1/psu-2/fault-F0378 Power supply 2 in chassis 1 presence: missing (ack:yes)

use --ignore="sys/chassis-1/psu-4/fault-F0378,sys/chassis-1/psu-2/fault-F0378" to remove from report

Example for general removal:
015-12-17T15:52:19.296 warning org-root/ls-cu01-pod01-esx-5/fault-F0334 Service profile cu01-pod01-esx-5 is not associated (ack:no)

use --ignore="fault-F0334"

=item B<--verbose>

Verbose mode, might return more information, might be not a good idea for monitoring

=item B<--proto>

Protocol to use: http or https, defaults to http

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION
	
B<check_ucs_events.pl> fetches the event log from the given ucs cluster and prints 
a statistic and events. Return Code for icinga monitoring.

=cut

