#!/usr/bin/perl
# ============================================================================
# check_cdn_platform.pl
# ------------------------------
# 14.07.2016 Michael Pospiezsynski, SWISS TXT 
# ============================================================================
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
my $msg;
my $rc = 3;

# ----------------------------------------------------------------------------
# Purge File from Cache
# ----------------------------------------------------------------------------
sub purgePcache($$$$$) {
	my ($host,$path,$apiurl,$key,$secret) = @_;

	my $ua = LWP::UserAgent->new;
	
	$ua->agent('check_cdn_platform/1.0');
	$ua->default_header("X-Api-Key" => $key);
	$ua->default_header("X-Api-Secret" => $secret);
	$ua->default_header("Accept" => "application/json");

	my $response = $ua->post($apiurl."/purge", [ host=> $host, path => $path ]);
	
	printf "[INFO] %s\n", $response->content if ($opt{'verbose'});

	return ($response->code, $response->is_success ? $response->content : undef);
}

# ----------------------------------------------------------------------------
# Fetch Data from URL
# ----------------------------------------------------------------------------
sub fetchData($$) {
	my ($url, $header) = @_;

	my $ua = LWP::UserAgent->new;

	$ua->agent('check_cdn_platform/1.0');

	if (defined($header)) {
		my ($p,$v) = split (/: /, $header);
		$ua->default_header($p => $v);
	}
	my $response = $ua->get($url);

	printf "[INFO] %s\n", $response->code if ($opt{'verbose'});

	return ($response->code, $response->is_success ? $response->content : undef);
}


########
# MAIN #
########

GetOptions (
	"host=s"		=> \$opt{'host'},
	"path=s"		=> \$opt{'path'},
	"header=s"		=> \$opt{'header'},
	"api=s"			=> \$opt{'api'},
	"key=s"			=> \$opt{'key'},
	"secret=s"		=> \$opt{'secret'},
    "verbose"       => \$opt{'verbose'},
    "help|?"        => \$opt{'help'},
    "man"           => \$opt{'man'},
) or pod2usage(2);

#
# check options
#
pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

foreach my $o (qw/host path api key secret/) {
	unless (defined($opt{$o})) {
	        print "--$o is required\n";
	        exit 3;
	}
}


#
# Purge file from cache
#
my ($code,$data) = purgePcache($opt{'host'},$opt{'path'},$opt{'api'},$opt{'key'},$opt{'secret'});

print "[info] purgePcache returns: $code\n" if (defined($opt{'verbose'}));

#
# get Data 
#
($code,$data) = fetchData("http://".$opt{'host'}.$opt{'path'},$opt{'header'});

print "[info] fetchData returns: $code\n" if (defined($opt{'verbose'}));

unless (defined($data)) {

	$msg = "HTTP Result code is $code";
	$rc = 2;

} else {
	$msg = "HTTP Result: OK";
	$rc = 0;
}

#
# print result
#

print "[info] RC= ",$rc,"\n" if (defined($opt{'verbose'}));

print $msg,"\n";
exit $rc;


__END__

=head1 NAME

 check_cdn_platform.pl -- check CDN platform functionality

=head1 SYNOPSIS

 check_cdn_platform.pl [options]
 Options:
   --host     host name
   --path     file path
   --header   optional header for test file request
   --api      API url
   --key      API key
   --secret   API secret
   --verbose  verbose, what else?
   --help     brief help message
   --man      full documentation

=head1 OPTIONS

=over 8

=item B<--host>

host name for test file

=item B<--path>

path to test file

=item B<--header>

optional header for test file request

=item B<--api>

base URL to API

=item B<--key>

API key

=item B<--secret>

API secret

=item B<--verbose>

verbose mode for testing and debugging

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<check_cdn_platform.pl> purges the test file and fetches it afterwards

=cut

