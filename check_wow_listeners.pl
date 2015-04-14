#!/usr/bin/perl

use strict;
use XML::LibXML;
use Getopt::Long;
use LWP::UserAgent;
use lib "/usr/lib/nagios/plugins";
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

# Global Definitions
my $user = '';
my $pass = '';
my $hostname = '';
my $listeners = 0;

GetOptions(
        "H=s" => \$hostname, 
        "p=s" => \$pass,
        "u=s" => \$user
) or print_help();

# Call Wowza API to get XML
my $staturl = "http://" . $hostname . ":8086/connectioncounts";
my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => $staturl);
$ua->credentials($hostname.":8086","Wowza Media Systems",$user,$pass);
my $res = $ua->request($req);

# Parse XML to get Current Listeners
my $parser = XML::LibXML->new();
my $tree = $parser->parse_string($res->content);
my $root = $tree->getDocumentElement;
my $query = "//WowzaMediaServer/VHost/Application[Name/text() = 'live']/ConnectionsCurrent/text()";

# Get what you need and print
$listeners = $_->data ."\n" foreach ($root->findnodes($query));
my $noutput = "total listeners = " . $listeners . " | total_listeners=" . $listeners;
print $noutput . "\n";;

# Help
sub print_help {
        printf "Plugin to monitor wowza listeners \n";
        printf "\nUsage:\n";
        printf "   -H Hostname\n";
        printf "   -p Password\n";
        printf "   -u Username\n";
        exit $ERRORS{'OK'};
}
