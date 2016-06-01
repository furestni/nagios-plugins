#!/usr/bin/perl
# ============================================================================
# check_RabbitMQ_API_Overview.pl
# ------------------------------
# 01.06.2016 Michael Pospiezsynski, SWISS TXT 
# ============================================================================
use REST::Client;
use JSON;
use MIME::Base64;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use warnings;
use strict;

# ----------------------------------------------------------------------------
# Global Vars
# ----------------------------------------------------------------------------
my %opt;
my %checks = (
				'redeliver_details_rate', \&perform_check_redeliver_details_rate,
			 );
my $msg = "?";
my $rc = 3;

# fetch data from server using REST API
# -------------------------------------
sub fetchData($$$) {
    my ($server, $path, $auth) = @_;
    my $headers = {Accept => 'application/json', Authorization => 'Basic ' . $auth};
    my $client = REST::Client->new({ host => $server });

	printf ("Server: %s\nHeader:\n%s\nPath:   %s\n", $server, Dumper $headers, $path) if ($opt{'verbose'});
    $client->GET($path, $headers);

    return (
        $client->responseCode,
        $client->responseCode == 200 ? from_json($client->responseContent()) : undef
    );
}

# check implementation
# --------------------
sub perform_check_redeliver_details_rate () {

	my $rc = 3;
	my $msg = "unknown";
	my $value;

	my ($http_rc, $data_ref) = fetchData($opt{'server'}, '/api/overview', $opt{'auth'});

	if (defined($data_ref)) {

		#$data_ref->{'message_stats'}{'redeliver_details'}{'rate'} = "0.1";
		$value = $data_ref->{'message_stats'}{'redeliver_details'}{'rate'};

		$msg = sprintf "message_stats.redeliver_details.rate=%.1f", $value;
		$rc = ($value > 0) ? 2 : 0;	# check is critical if condition is true
	} else {
	   $msg = "something went wrong while fetching data from the REST API... rc=".$http_rc;
	   $rc = 3;
	}

	return ($rc, $msg);
}


########
# MAIN #
########

GetOptions (
    "server=s"		=> \$opt{'server'},
    "user=s"		=> \$opt{'user'},
    "pass=s"		=> \$opt{'pass'},
    "auth=s"		=> \$opt{'auth'},
    "check=s"		=> \$opt{'check'},
    "verbose"		=> \$opt{'verbose'},
    "help|?"		=> \$opt{'help'},
    "man"			=> \$opt{'man'},
) or pod2usage(2);

#
# check options
#
pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

unless (defined($opt{'server'})) {
        print "--server is required\n";
        exit 3;
}
$opt{'server'} = "http://".$opt{'server'} unless ($opt{'server'} =~ m!^http[s?]://!);

unless (( (defined($opt{'user'}) && defined($opt{'pass'})) || defined($opt{'auth'}))) {
        print '--user ' unless (defined($opt{'user'}));
        print '--pass ' unless (defined($opt{'pass'}));
        print 'or --auth ' unless (defined($opt{'user'}) && defined($opt{'pass'}));
        print "required\n" ;
        exit 3;
}

unless ($opt{'auth'}) {
        $opt{'auth'} = encode_base64($opt{'user'} . ':' . $opt{'pass'});
}

unless (defined($opt{'check'})) {
	print "--check is required\n";
	exit 3;
} elsif (! grep  { $opt{'check'} eq $_ } keys %checks) {
	print "selected check is not implemented.\n";
	exit 3;
} else {
	printf "run check: %s\n", $opt{'check'} if ($opt{'verbose'});

	($rc, $msg) = &{$checks{$opt{'check'}}};


}

# result of check

print $msg, "\n";
printf "exit code = %d\n", $rc if ($opt{'verbose'});
exit $rc;

BEGIN {
   $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}


__END__

=head1 NAME

check_RabbitMQ_API_Overview.pl -- check Element

=head1 SYNOPSIS

	check_RabbitMQ_API_Overview.pl [options]
	Options:
		--server        IP/name of server
		--user          user name for authentification
		--pass          password for authentification
		--auth          pass-through auth string
		--check         name of check to be executed
		--verbose       verbose, what else?
		--help          brief help message
		--man           full documentation

=head1 OPTIONS

=over 8

=item B<--server>

IP/name of Server

=item B<--user>

user name for authentification

=item B<--pass>

password for authentification

=item B<--auth>

pass-though auth string

=item B<--check>

name of check to be executed

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_RabbitMQ_API_Overview.pl> execute the specified check and server using he REST API
=cut

