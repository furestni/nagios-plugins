#!/usr/bin/perl

use strict;
use XML::LibXML;
use Getopt::Long;
use lib "/usr/lib/nagios/plugins";
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);

my $staturl = "http://" . $ARGV[0] . ":8086/connectioncounts";
my $user = '';
my $pass = '';
my $hostname = '';
my $listeners = 0;

GetOptions(
        "H=s" => \$hostname, 
        "p=s" => \$pass,
        "u=s" => \$user
) or print_help();

my $staturl = "http://" . $hostname . ":8086/connectioncounts";

#get listeners
use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => $staturl);
$ua->credentials($ARGV[0].":8086","Wowza Media Systems",$user,$pass);

my $res = $ua->request($req);

my $parser = XML::LibXML->new();
my $tree = $parser->parse_string($res->content);
my $root = $tree->getDocumentElement;



my $query = "//WowzaMediaServer/VHost/Application[Name/text() = 'live']/ConnectionsCurrent/text()";
$listeners = $_->data ."\n" foreach ($root->findnodes($query));




#my $noutput = "total listeners = " . $totallisteners . " | total_listeners=" . $totallisteners . ", " . $perfdata;
#$noutput =~ s/, $//g;
my $noutput = "total listeners = " . $listeners . " | total_listeners=" . $listeners;
print $noutput . "\n";;

sub print_help {
        printf "Plugin to monitor wowza listeners \n";
        printf "\nUsage:\n";
        printf "   -H Hostname\n";
        printf "   -p Password\n";
        printf "   -u Username\n";
        exit $ERRORS{'OK'};
}
