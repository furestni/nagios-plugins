#!/usr/bin/perl
#
# Icinga2 check script that downloads a HLS playlist from URL and check if it is valid and how long the request took.
# Returns the request time as performance data.
#
# Read the POD at the end of this file!
#
# Todo:
# - Better logging
# - Outsource optionshandling ot own function.
# - Implement https
# = Further playlist parsing
#

use warnings;
use strict;

use LWP::UserAgent;
use File::Temp qw(tempfile);
use Getopt::Long;
use Time::HiRes;
#use Data::Dumper;

##### Config

# playlist definition regula expression patterns
# see https://tools.ietf.org/html/draft-pantos-http-live-streaming-21#section-4.1
our $PL_HEADER = qr(#EXTM3U$); # MUST be first line in a valid playlist
our $PL_PATTERN = '\.m3u(8)?$'; # pattern to identifie a child playlist
our $SEG_IDENTIFIER = '^#EXTINF:\d+(\.\d+)?,(.*)$'; # segement identifier

### Options
our %OPTIONS = (
	'url' => undef,
	'maxtime' => 0.5,
	'verbose' => undef,
	'tmpdir' => undef,
    'perflabel' => 'request_time',
	'help' => undef,
);

# Icinga2 return codes
my %ICINGA_RET_CODES = (
  "OK" => 0,
  "WARN" => 1,
  "ERROR" => 2,
  "UNKNOWN" => 3
);

##### Functions

# Usage
sub usage() {
	my $usage = <<'USAGE';
Usage: check_hls.pl [OPTION]... --url | -u URL
Icinga2 check script that downloads a HLS playlist from URL and check if it is valid and how long the request took.
Returns the request time as performance data.

Returns errorcodes usefull for Icinga2.

  -u, --url=URL                URL from where to download the playlist.
  -t, --maxtime=MAXTIME        Maximum time in seconds a request may take (default: 0.5).
  -v, --verbose                Print debug messages.
  -d, --tmpdir                 Directory to temporarily store the playlist (default: system's default).
  -p, --perflabel              Performance data label name in icinga2 for the request time (default: request_time).
  -h, --help                   This text.

Type "perlpod <script_name>" for more script informations.

USAGE

	print($usage);
	return($ICINGA_RET_CODES{'UNKNOWN'});
}

# Creates a temp file
sub create_tempfile($) {
	my $err_code;
	my $tmpdir = $_[0];

	if( !defined($tmpdir) ) {
		$tmpdir = "";
	}

	my ($fh, $filename) = tempfile(UNLINK=>1, DIR=>"$tmpdir");
	$err_code = $?;

	if( !$fh ) {
		#print("ERROR: create_tempfile: could not create tempfile ($?)");
		return(1, undef, undef);
	}

	return(0, $fh, $filename);
}

# Download playlist and save it to a file
sub get_playlist($$) {

	my $response; # HTTP-Response code
	my $url = $_[0];
	my $file = $_[1]; # must be filename, NOT file handle because LWP needs a file name

	# for measuring the full request
	my $req_start_time = undef;
	my $req_end_time = undef;
	my $req_time = undef;

	my $ua = LWP::UserAgent->new();

	$ua->ssl_opts( 'verify_hostname' => 1 );

	$req_start_time = Time::HiRes::time();
	$response = $ua->get($url, ':content_file' => $file );
	$req_end_time = Time::HiRes::time();

	$req_time = $req_end_time - $req_start_time;

	return($response, $req_time);
}

# Parses a playlist
sub parse_playlist($) {

	# file handle of the playlist file
	my $pl = $_[0];

	# Reset postition in file for good measure and safe coding...etc.....
	seek($pl, 0, 0);

	# By defintion a HLS playlist MUST begin with a certain header.
	my $first_line = <$pl>;
	if ( $first_line !~ m/$PL_HEADER/xms ) {
		return($ICINGA_RET_CODES{"ERROR"}, "Non-valid playlist file received (header not HLS compliant)");
	}

	if ( defined( $OPTIONS{'verbose'} ) ) {
		while ( my $line = <$pl> ) {
			print($line);
		}
	}
	return($ICINGA_RET_CODES{"OK"}, "");
}

##### Main
sub main(@) {

	my $err_code = undef;
	my $lwp_resp = undef; # LWP-response object
	my $lwp_req_time = undef; # Time the full request took
	my %tempfile;

	GetOptions(\%OPTIONS, 'url|u=s', 'verbose|v', 'maxtime|t=f', 'tmpdir|d=s', 'perflabel|p=s', 'h|help' ) || die();

	if( $OPTIONS{'help'} ) {
		usage();
		return($ICINGA_RET_CODES{'UNKNONW'});
	}

	if( !defined($OPTIONS{'url'}) ) {
		usage();
		return($ICINGA_RET_CODES{'UNKNOWN'});
	}

	print("DEBUG: Creating tempfile...\n") if ( $OPTIONS{'verbose'} );
	( $err_code, $tempfile{'fh'}, $tempfile{'name'} ) = create_tempfile($OPTIONS{'tmpdir'}); # LWP::Simple::get() cannot handle a FH.
	if( $err_code != 0 ) {
		print("Could not create tempfile..\n");
		return($ICINGA_RET_CODES{'UNKNOWN'});
	}

	print("DEBUG: Downloading playlist...\n") if ( $OPTIONS{'verbose'} );
	( $lwp_resp, $lwp_req_time ) = get_playlist($OPTIONS{'url'}, $tempfile{'name'});
	if( $lwp_resp->is_error ) {
		print("Could not download playlist @ $OPTIONS{'url'}. Error was: " . $lwp_resp->status_line . ".\n");
		return($ICINGA_RET_CODES{'WARN'})
	}

	print("DEBUG: Parsing playlist...\n") if ( $OPTIONS{'verbose'} );
	( $err_code, my $parse_msg )  = parse_playlist($tempfile{'fh'});

	if( $err_code != $ICINGA_RET_CODES{'OK'}  ){
		printf("%s|$OPTIONS{'perflabel'}=%6fs\n", $parse_msg, $lwp_req_time);
		return($err_code); # icinga2 error code already resolved in function
	}

	# playlist could be downloaded and is ok
	# now check if it took too long

	if( $lwp_req_time >= $OPTIONS{'maxtime'} ) {
		printf("ERROR: Request time was %6f seconds.|%s=%6fs\n", $lwp_req_time, $OPTIONS{'perflabel'}, $lwp_req_time );
		return($ICINGA_RET_CODES{'ERROR'});
	}else{
		printf("OK: Request time was %6f seconds.|%s=%6fs\n", $lwp_req_time, $OPTIONS{'perflabel'}, $lwp_req_time );
		return($ICINGA_RET_CODES{'OK'});
	}

	# we should not be here
	print("UNKNOWN: $0 script error.\n");
	return($ICINGA_RET_CODES{'UNKNOWN'});
}

exit( main(@ARGV) );

__END__

=pod

=head1 NAME

hls_check.pl - Icinga2 HLS check script

=head1 DESCRIPTION

 Downloads a HLS playlist from URL and checks if it is valid and how long the request took.
 Also outputs the request time as performance data for icinga2.

 All script return codes are icinga2 conform (0,1,2,3).
 Script errors are always UNKNOWNS!

=head1 Functions

=head3 B<usage()>

 Prints a short help text.

 Arguments: None
 Returns: UNKNOWN for icinga.

=head3 B<create_tempfile($)>

 Creates a temp file where the content of the downloaded HLS playlist is stored.

 Arguments:
 $0: Tempdir - Directory where to create the file. Defaults to system settings (most likely /tmp und linux).

 Returns:
 $0: Return code
 $1: Filehandle
 $2: Name of the temp file

=head3 B<get_playlist($)>

 Downloads a file (playlist) from an URL and stores it to a file on disk. Measures the time the whole request took.

 Arguments:
 $0: URL
 $1: File name on disk

 Returns:
 $0: An LWP response object.
 $1: The time the whole request took.

=head3 B<parse_playlist()>

 Parses an HLS playlist. At the moment (05.2017) only checks if the header is OK.

 Arguments:
 $0: Filehandle of the playlist

 Returns:
 $0: Icinga error code
 $2: Error message or "blank" if OK.

=head1 COPYRIGHT

 GPL: http://www.gnu.org/licenses/gpl.txt

=head1 AUTHOR

 Samuel Friedli - samuel.friedli@swisstxt.ch

=cut
