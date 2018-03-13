#!/usr/bin/perl

use warnings;
use strict;
use LWP::UserAgent;
use Getopt::Long;
use Pod::Usage;


my %opt;

my $msg = "";
my $rc = 3;


GetOptions (
    "host=s"      => \$opt{'host'},
    "body=s" => \$opt{'body'},
    "help|?"      => \$opt{'help'},
    "man"         => \$opt{'man'},
) or pos2usage(2);

pod2usage(1) if $opt{'help'};
pod2usage(-exitval => 0, -verbose => 2) if $opt{'man'};

foreach my $o (qw(host body)) {
    unless (defined($opt{$o})) {
        printf "--%s is required\n", $o;
        $rc = 1;
    }
}
exit 3 if $rc <3;

my $ua = LWP::UserAgent->new;
 
my $server_endpoint = $opt{'host'};
 
# set custom HTTP request header fields
my $req = HTTP::Request->new('POST', $server_endpoint);
$req->header( 'Content-Type' => 'application/json' );
#$req->header('x-auth-token' => 'jd9d');
 
# add POST data to HTTP request body
my $post_data = $opt{'body'};
$req->content($post_data);
 
my $resp = $ua->request($req);

if ($resp->is_success) {
    my $message = $resp->decoded_content;
    print "HTTP POST return code: ", $resp->code, "\n";
}
else {
    print "HTTP POST error code: ", $resp->code, "\n";
}



__END__

=head1 NAME

Json Body Check

=head1 SYNOPSIS

usage:

=head1 OPTIONS

=over 8

=item B<--debug>
   
   Print Debugging Information

=item B<--help>

   Print a brief help message and exits.

=item B<--man>
   Prints the manual page and exits.

=back

=head1 DESCRIPTION

description of Json Body Check

=cut


