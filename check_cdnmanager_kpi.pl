#!/usr/bin/perl
# ============================================================================
# check_cdnmanager_kpi.pl
# -----------------------
# 
# ============================================================================

use REST::Client;
use JSON;
use MIME::Base64;
use URI::Escape;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
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
	my ($rest, $path, $header) = @_;

	$rest->GET($path, $header);
	
	return $rest->responseCode == 200 ? from_json($rest->responseContent()) : undef;
}

	
# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
#

GetOptions (
	"host=s"     => \$opt{'host'},
	"user=s"     => \$opt{'user'},
	"pass=s"     => \$opt{'pass'},
    "auth=s"	 => \$opt{'auth'},
	"verbose"    => \$opt{'verbose'},
	"minutes=i"  => \$opt{'minutes'},
	"warning=i"  => \$opt{'warning'},
	"critical=i" => \$opt{'critical'},
	"count=s"	 => \$opt{'count'},
	"from=s"	 => \$opt{'from'},
	"service=s"  => \$opt{'service'},
	"db=s"		 => \$opt{'db'},
	"help|?"     => \$opt{'help'},
	"man"        => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

# check for required options
foreach my $k (qw/host count from service db minutes warning critical/) {
	unless (defined($opt{$k})) {
		print "ERROR: --".$k." is required\n";
		exit 3;
	}
}
unless (( (defined($opt{'user'}) && defined($opt{'pass'})) || defined($opt{'auth'}))) {
        print "ERROR: ";
        print '--user ' unless (defined($opt{'user'}));
        print '--pass ' unless (defined($opt{'pass'}));
        print 'or --auth ' unless (defined($opt{'user'}) && defined($opt{'pass'}));
        print "required\n" ;
        exit 3;
}

# tweak options
unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
}


if ($opt{'minutes'} < 5) {
	print "ERROR: minutes < 5 not supported\n";
	exit 3;
}

if ($opt{'warning'} < $opt{'critical'}) {
	print "ERROR: warning lower than critical!\n";
    exit 3;
}

my $headers = {Accept => 'application/json', Authorization => 'Basic ' . $opt{'auth'}};

my $client = REST::Client->new({
	host => 'https://'.$opt{'host'}
});

my $query = '/query?q=select+count('.$opt{'count'}.')+from+'.$opt{'from'}.'+where+service+%3D+%27'.$opt{'service'}.'%27+and+time+%3E+now()+-+'.$opt{'minutes'}.'m+order+by+time+desc%3B&db='.$opt{'db'};

print "GET: $client, $query\n\n" if ($opt{'verbose'});

my $kpi = fetchData ($client, $query, $headers);

if ($opt{'verbose'}) {
	print "--------------------------------------------\n";
	print Dumper $kpi ;
	print "--------------------------------------------\n";
}

#print Dumper $kpi_2;

my $ts = $kpi->{'results'}[0]{'series'}[0]{'values'}[0][0];
my $value = $kpi->{'results'}[0]{'series'}[0]{'values'}[0][1];

printf "TS = %s\nValue = %s\n" , $ts, $value if ($opt{'verbose'});

my $rc = 3;
my $msg = "UNKNOWN";

if ($value < $opt{'critical'}) {
	$msg = "Critical: $value entries found since $ts\n";
	$rc = 2;
} elsif ($value < $opt{'warning'}) {
	$msg = "Warning: $value entires found since $ts\n";
	$rc = 1;
} else {
	$msg ="OK: $value entries found since $ts\n";
	$rc = 0;
}

print $msg;
exit $rc;



BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}


__END__

=head1 NAME

check_cdnmanager_kpi.pl -- query db and check result

=head1 SYNOPSIS

    check_cdnmanager_kpi.pl [options] 
     Options:
       --help            brief help message
       --man             full documentation
       --host            host name
       --user            user name
       --pass            password
       --verbose         verbose
       --minutes         query minutes to check
       --warning         result warning level
       --critical        result critical level
       --count           query count
       --from            query from
       --service         query service
       --db              query db


=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>
    Prints the manual page and exits.

=back

=head1 DESCRIPTION
B<check_cdnmanager_kpi.pl> query the given host with given parameters and check result against given warning and critical levels
=cut

