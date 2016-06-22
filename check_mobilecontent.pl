#!/usr/bin/perl
# ============================================================================
# check_mobilecontent.pl
# ------------------------------
# 16.06.2016 Michael Pospiezsynski, SWISS TXT 
# ============================================================================
use Mojo::DOM;
use Data::Dumper;
use LWP::UserAgent;
use Getopt::Long;
use Pod::Usage;
use warnings;
use strict;

# ----------------------------------------------------------------------------
# Global Vars
# ----------------------------------------------------------------------------
my %opt;
my @stat;
my @msg;
my $rc = 3;

# ----------------------------------------------------------------------------
# Fetch Data from URL
# ----------------------------------------------------------------------------
sub fetchData($) {
	my ($url) = @_;

	my $ua = LWP::UserAgent->new;
	my $response = $ua->get($url);

	printf "[INFO] %s\n", $response->is_success ? $response->content : $response->code if ($opt{'verbose'});

	return ($response->code, $response->is_success ? $response->content : undef);
}


########
# MAIN #
########

GetOptions (
    "url=s"         => \$opt{'url'},
    "verbose"       => \$opt{'verbose'},
    "help|?"        => \$opt{'help'},
    "man"           => \$opt{'man'},
) or pod2usage(2);

#
# check options
#
pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

unless (defined($opt{'url'})) {
        print "--url is required\n";
        exit 3;
}

#
# get Data 
#
my ($code,$data) = fetchData($opt{'url'});

unless (defined($data)) {

	print "Error $code from $opt{'url'}\n";
	exit 1;

}

#
# check status
#
my $dom = Mojo::DOM->new($data);
my %counter;

foreach my $e ($dom->find('td')->each) {
	my $info = $e->previous->text ? $e->previous->text : $e->previous->at('a')->content;
	printf "[info] %s: %s: %s\n", 
		$e->{class},
		$info,
		$e->text if (defined($opt{'verbose'}));
	foreach my $c (split (/\s/, $e->{class})) {
		if ($c =~ m/^status/) {
			$counter{$c}{'count'}++;
			push @{$counter{$c}{'info'}}, $info;
		}
	}
}

foreach my $e (keys(%counter)) {
	printf "[info] %s: %d\n", $e, $counter{$e}{'count'} if (defined($opt{'verbose'}));
	if ($e eq 'status_ok') {
		push @stat, (sprintf "%s=%d (%s)", $e, $counter{$e}{'count'}, join(',', @{$counter{$e}{'info'}}));
		push @msg, (sprintf "%s=%d", $e, $counter{$e}{'count'});
	} else {
		push @msg, (sprintf "%s=%d (%s)", $e, $counter{$e}{'count'}, join(',', @{$counter{$e}{'info'}}));
	}
}

#
# evaluate status
#
if (defined($counter{'status_error'}{'count'}) && ($counter{'status_error'}{'count'} > 0)) {
	$rc = 2;
} elsif (defined($counter{'status_warning'}{'count'}) && ($counter{'status_warning'}{'count'} > 0)) {
	$rc = 1;
} elsif (defined($counter{'status_ok'}{'count'}) && ($counter{'status_ok'}{'count'} != 11)) {
	unshift @msg, sprintf('unknown_status=%d', 11-$counter{'status_ok'}{'count'});
	$rc = 1;
} elsif (defined($counter{'status_ok'}{'count'}) && ($counter{'status_ok'}{'count'} == 11)) {
	$rc = 0;
} else {
	$rc = 3;
}

#
# print result
#
print join (" ", @msg), "\n";
print join ("\n", @stat),"\n";

print "[info] RC= ",$rc,"\n" if (defined($opt{'verbose'}));

exit $rc;


__END__

=head1 NAME

check_mobilecontent.pl -- check status of mobilecontent

=head1 SYNOPSIS

    check_mobilecontent.pl [options]
    Options:
        --url           URL (mobilecontent)
        --verbose       verbose, what else?
        --help          brief help message
        --man           full documentation

=head1 OPTIONS

=over 8

=item B<--url>

URL for mobilecontent status
like http://server:port/path

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_mobilecontent.pl> fetch status page of given URL and parse content for status information 

=cut

