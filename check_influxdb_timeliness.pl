#!/usr/bin/perl
# ============================================================================
# check_influx_timeliness.pl
# -------------------------
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
# Data transfer with GET
# -------------------------------------
sub getRESTData {
	my ($rest, $path, $header) = @_;

	$rest->GET($path, $header);
	
	return $rest->responseCode == 200 ? from_json($rest->responseContent()) : undef;
}

# -------------------------------------
# contruct header
# -------------------------------------
sub authHeaderCreator ($$$) {
    my ($user,$pass,$auth) = @_;

    my $result;

    if ( (defined($user) && defined($pass)) || defined($auth)) {
        # Basic Authentification is required
        unless (defined($auth)) {
            $auth = encode_base64($user . ':' . $pass);
        }
        $result = {Accept => 'application/json', Authorization => 'Basic ' . $auth};

    } else {
		# Basic Authentification not required
        $result = {Accept => 'application/json'};
    }

    return $result;
}


# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
#

GetOptions (
	"ssl"        => \$opt{'ssl'},
	"host=s"     => \$opt{'host'},
	"port=i"     => \$opt{'port'},
	"user=s"     => \$opt{'user'},
	"pass=s"     => \$opt{'pass'},
    "auth=s"	 => \$opt{'auth'},
	"verbose"    => \$opt{'verbose'},
	"debug"      => \$opt{'debug'},
	"minutes=i"  => \$opt{'minutes'},
	"warning=i"  => \$opt{'warning'},
	"critical=i" => \$opt{'critical'},
	"count=s"	 => \$opt{'count'},
	"from=s"	 => \$opt{'from'},
	"key=s"		 => \$opt{'key'},
    "value=s"    => \$opt{'value'},
	"db=s"		 => \$opt{'db'},
	"help|?"     => \$opt{'help'},
	"man"        => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

# check for required options
foreach my $k (qw/host port count from key value db minutes warning critical/) {
	unless (defined($opt{$k})) {
		printf "ERROR: --%s is required\n", $k;
		exit 3;
	}
}

if ($opt{'minutes'} < 5) {
	print "ERROR: minutes < 5 not supported\n";
	exit 3;
}

if ($opt{'warning'} < $opt{'critical'}) {
	print "ERROR: warning lower than critical!\n";
    exit 3;
}

my $headers = authHeaderCreator ($opt{'user'}, $opt{'pass'}, $opt{'auth'});

my $client = REST::Client->new({
	host => sprintf ("http%s://%s:%d", 
				defined($opt{'ssl'}) ? "s" : "",
				$opt{'host'},
				$opt{'port'}
			)
});

my $query = sprintf ("/query?db=%s&q=%s",
	uri_escape($opt{'db'}),
	uri_escape(
		sprintf ("select count(%s) from %s where %s='%s' and time > now() - %dm order by time desc;",
		 	$opt{'count'},
			$opt{'from'},
			$opt{'key'},
			$opt{'value'},
			$opt{'minutes'}
		)
	)
);

if (defined($opt{'debug'})) {
	print "--- DEBUG: Client Object -------------------\n";
	print Dumper $client;
	print "--------------------------------------------\n";
}
if (defined($opt{'verbose'})) {
	print "--- QUERY ----------------------------------\n";
	printf "%s/%s\n",$client->{'_config'}->{'host'}, $query;
	print "--------------------------------------------\n";
}

my $result_ref = getRESTData ($client, $query, $headers);

if ($opt{'verbose'}) {
	print "--- RESULT ---------------------------------\n";
	print Dumper $result_ref;
	print "--------------------------------------------\n";
}

my $rc = 3;
my $msg = "Query failed\n";

if (defined($result_ref)) {
	my $ts = defined($result_ref->{'results'}[0]{'series'}[0]{'values'}[0][0]) ? $result_ref->{'results'}[0]{'series'}[0]{'values'}[0][0] : $opt{'minutes'}." minutes";
	my $value = defined($result_ref->{'results'}[0]{'series'}[0]{'values'}[0][1]) ? $result_ref->{'results'}[0]{'series'}[0]{'values'}[0][1] : 0;

	if ($value < $opt{'critical'}) {
		$msg = "Critical: $value entries found since $ts\n";
		$rc = 2;
	} elsif ($value < $opt{'warning'}) {
		$msg = "Warning: $value entries found since $ts\n";
		$rc = 1;
	} else {
		$msg ="OK: $value entries found since $ts\n";
		$rc = 0;
	}
}

print $msg;
exit $rc;

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}

__END__

=head1 NAME

check_influx_timeliness.pl -- query db and check result

=head1 SYNOPSIS

    check_influx_timeliness.pl [options] 
     Options:
       --help            brief help message
       --man             full documentation
       --ssl             use https
       --host            host name influxdb
       --port            port influxdb
       --user            user name influxdb
       --pass            password influxdb
       --auth            base64 auth 
       --verbose         verbose
       --debug           debug
       --warning         result warning level
       --critical        result critical level
       --count           query count
       --from            query from
       --key             query key
       --value           query value
       --minutes         query minutes
       --db              query db

     Executed Query: given options by name in {{ }}
     SELECT count( {{count}} )
     FROM {{from}} 
     WHERE {{key}}='{{value}}' and time > now() - {{minutes}}m
     ORDER BY time DESC

=head1 OPTIONS

=over 8

=item B<--help>

	Print a brief help message and exits.

=item B<--man>

	Prints the manual page and exits.

=item B<--ssl>

	use https instead of http

=item B<--host>

	host name of influxdb server

=item B<--user>

	user name of influxdb server

=item B<--pass>

	password of influxdb server

=item B<--auth>

	base64 auth to use instead of user name and password

=item B<--verbose>

	verbose output of query to influxdb and result from influxdb

=item B<--debug>

	debug output 

=item B<--warning>

	result warning level
	if result count < warning then return warning

=item B<--critical>

	result critical level
	if result count < critical then return critical

=item B<--count>

	InfluxDB Query: count

=item B<--from>

	InfluxDB Query: from

=item B<--key>

	InfluxDB Query: key
	key for key='value' pair for WHERE clause

=item B<--value>

	InfluxDB Query: value
	value for key='value' pair for WHERE clause

=item B<--minutes>

	InfluxDB Query: minutes
	How many minutes to go back to count "from" entries

=item B<--db>

	InfluxDB select DB to use 

=back

=head1 DESCRIPTION
B<check_influx_timeliness.pl> query the given host with given parameters and check result against given warning and critical levels to evaluate timeliness of data
=cut

