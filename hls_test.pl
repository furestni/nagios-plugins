#!/usr/bin/perl
#
# Script to download and parse a HLS playlist
# Script returncodes are made for icinga:
# 0: OK
# 1: Warn
# 2: Crit
# 3: Unknown
#
# Todo:
# - Better logging
# - Outsource optionshandling ot own function.
# - Implement https
# = Further playlist parsing
#
 
use warnings;
use strict;

use LWP::Simple qw($ua getstore);
use File::Temp qw(tempfile);
use Getopt::Long;

##### Config

# playlist definition regula expression patterns
# see https://tools.ietf.org/html/draft-pantos-http-live-streaming-21#section-4.1
our $PL_HEADER = qr(#EXTM3U$); # MUST be first line in a valid playlist
our $PL_PATTERN = '\.m3u(8)?$'; # pattern to identifie a child playlist
our $SEG_IDENTIFIER = '^#EXTINF:\d+(\.\d+)?,(.*)$'; # segement identifier

##### Functions

# Usage
sub usage() {
	my $usage = <<'USAGE';
Usage: hls_test.pl [OPTION]... --url | -u URL
Downloads a HLS playlist from URL and check if it is valid.
           
Returns errorcodes usefull for Icinga2.

  -u, --url=URL                URL from where to download the playlist.
  -t, --timeout=TIMEOUT        Connection timeout (This is NOT a request timeout). (Default=0.01s)
  -v, --verbose                Print debug messages.
  -d, --tmpdir                 Directory to temporarily store the playlist. 
  -h, --help                   This text.
USAGE

	print($usage);
	return(0);
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
sub get_playlist($$$) {

	my $resp_code; # HTTP-Response code
	my $url = $_[0];
	my $file = $_[1];
	my $timeout = $_[2];
	
	$ua->timeout($timeout);
	
	$resp_code = $ua->get($url, ':content_file' => $file );

	return($resp_code);
}

# Parses a playlist
sub parse_playlist($) {

	my $pl = $_[0];
	
	# Reset postition in file for good measure and safe coding...etc.....
	seek($pl, 0, 0);

	# By defintion a HLS playlist MUST begin with a certain header.
	my $first_line = <$pl>;
	if ( $first_line !~ m/$PL_HEADER/xms ) {
		print("ERROR: Playlist header does not match HLS specifications!\n");
		return(1);
	}
	#while ( my $line = <$pl> ) {
	#	
	#}
}

##### Main
sub main(@) {

	my $err_code;
	my $http_ret_code;
	my %tempfile;

	# default options
	my %options = (
		'url' => undef,
		'timeout' => 0.01,
		'verbose' => undef,
		'tmpdir' => undef,
        'help' => undef,
	);

	GetOptions(\%options, 'url|u=s', 'verbose|v', 't|timeout=f', 'd|tmpdir=s', 'h|help' ) || die();

	if( $options{'help'} ) {
		usage();
		return(3);
	}

	if( !defined($options{'url'}) ) {
		usage();
		return(3);
	}elsif ( $options{'url'} =~ m/^https/ ) {
		print("ERROR: SSL (HTTPS) is not supported at the moment.\n");
		return(1);	
	}

	print("DEBUG: Creating tempfile...\n") if ( $options{'verbose'} );
	( $err_code, $tempfile{'fh'}, $tempfile{'name'} ) = create_tempfile($options{'tmpdir'}); # LWP::Simple::get() cannot handle a FH.
	if( $err_code != 0 ) {
		print("ERROR: Could not create tempfile..\n");
		return(3);
	}

	print("DEBUG: Downloading playlist...\n") if ( $options{'verbose'} );
	$http_ret_code = get_playlist($options{'url'}, $tempfile{'name'}, $options{'timeout'});

	# read timeout
	if ( $http_ret_code->status_line =~ m/500 read timeout/ ) {
		print("ERROR: Request timed out!\n");
		return(1);
	}
	# everything else
	if( $http_ret_code->is_error ) {
		print("ERROR: Could not download playlist @ $options{'url'}. Error was: " . $http_ret_code->status_line . ".\n");
		return(1)
	}

	print("INFO: Parsing playlist...\n") if ( $options{'verbose'} );
	$err_code = parse_playlist($tempfile{'fh'});
	if($err_code != 0 ){
		print("ERROR: Playlist is not valid!\n");
		return(1);
	}
	
	# if we got here, everything went well.
	return(0);
}

exit( main(@ARGV) );

__END__

=head1 NAME

hls_check.pl - Downloads a HLS playlist


Downloads a HLS playlist

=head1 DESCRIPTION

<Somethinguseful>

=head1 Functions

=head3 B<usage()>

Prints a short help text

=head1 COPYRIGHT

GPL: http://www.gnu.org/licenses/gpl.txt

=head1 AUTHOR

Samuel Friedli - samuel.friedli@swisstxt.ch

=cut


