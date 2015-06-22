#!/usr/bin/perl

#
# Basic script to get things going.
#
#use strict;
#use warnings;

#use constant $VERBOSE => 0;
#use constant $VERBOSE => 1;

#my $PROGNAME=substr($0,0,rindex($0,'.'));



#my $VERBOSE=0;
my %equipment = "";
my @equipment_in_file = "";
my @equipment_read = "";
use LWP;
use XML::Simple;
use XML::Writer;
use XML::LibXML;
use Data::Dumper;
use XML::Parser;
use XML::DOM;
use IO::Socket;
use Getopt::Long;
use List::Compare;

sub doLogin
{
    my ($mUri, $lusername, $lpassword) = @_;
    my $lXmlAttrs  = 'inName="' . $lusername . '" inPassword="' . $lpassword . '"';
    my $lXmlMethod = 'aaaLogin';
    my $lIsNested  = 0;

    my $lXmlReq = prepareXmlQuery($mCookie, $lXmlMethod, $lXmlAttrs, 1);
    my ($lContent, $lMessage, $lSuccess) = doPostXML($mUri, $lXmlReq);

    $mCookie = undef;
    if ($lSuccess)
    {
        eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lContent);
            $mCookie = $lConfig->{'outCookie'};
            $mCookie = undef if ($mCookie && $mCookie eq "");

        };
        $lSuccess = undef if ($@);
    }

    return ($lSuccess, $mCookie, $lContent) if wantarray;
    return ($mCookie);
}


sub doLogout
{
    my ($aInUri, $aInCookie) = @_;
    my $lXmlRequest = "<aaaLogout inCookie=\"REPLACE_COOKIE\" />";
    $lXmlRequest =~ s/REPLACE_COOKIE/$aInCookie/;

    my $lCookie = undef;
    my ($lContent, $lMessage, $lSuccess) = doPostXML($aInUri, $lXmlRequest,1);

    if ($lSuccess)
    {
        eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lContent);
            $lCookie = $lConfig->{'outCookie'};
            $lCookie = undef if ($lCookie && $lCookie eq "");
        };
    }
    return $lCookie;
}


sub resolveClass
{
    my ($Class, $mCookie, $Hier , $lUri) = @_;

    if (defined $Class)
    {
#        my $lXmlMethod = 'configResolveClass';
        my $lXmlMethod = 'configResolveDn';
#        my $lXmlMethod = 'configResolveDns';
        if ($Hier == 1) {
          $Hier = 'true';
        }
        else {
          $Hier = 'false';
        }

#        my $lXmlAttrs  = 'inHierarchical="' . $Hier . '" classId="' . $Class . '"';
        my $lXmlAttrs  = 'inHierarchical="' . $Hier . '" dn="' . $Class . '"';
#        my $lXmlReq  = '<configResolveDns cookie="' . $mCookie . '" inHierarchical="true"> <inDns> <dn value="' . $Class . '" /> </inDns> </configResolveDns>';
        my $lXmlReq = prepareXmlQuery($mCookie, $lXmlMethod, $lXmlAttrs, 0);
        my ($lContent, $lMessage, $lSuccess) = doPostXML($lUri, $lXmlReq);
        return ($lContent) if $lSuccess;
    }
    return undef;
}

sub printNode {
  my ($theNode) = @_;
  my $thisType    = $theNode->getNodeType;
  my $nodeList    = $theNode->getChildNodes;
  my $name                = $theNode->getNodeName;
  my $attLength;
  my $length              = $nodeList->getLength;

  my $attList             = $theNode->getAttributes;
  if( $attList ){ $attLength = $attList->getLength };

  $sep    = "    ";

#Atributes are NOT part of the DOM tree, but properties of an element.
#As properties, things like parent, child, next and last item are
#not definable, even though it looks like a node.
#If they exist, handle them.
  if($attLength) {
    $depth++;
    my $state = "";
    my $id = "";
    my $dn = "";

    for( my $j=0; $j<$attLength; $j++ ) {
      my $attNode = $attList->item($j);
      if ($attNode->getName =~ /^operState$/) {
        $state = $attNode->getName . "=" . $attNode->getValue;
      }
      elsif ($attNode->getName =~ /^id$/i) {
        $id = $attNode->getValue;
      }
      elsif ($attNode->getName =~ /dn/i && $attNode->getValue !~ //) {
        $dn = $attNode->getValue;
      }
      elsif ($attNode->getName =~ /rn/i && $attNode->getValue !~ //) {
        $rn = $attNode->getValue;
      }
    }

    if ($state) {
    my $hashke = "";
      if ($rn) {
        if ($dn) {
          $hashkey = $name . "_" . $rn . "_" . $dn;
        }
        else {
          $hashkey = $name . "_" . $rn;
        }
      }
      elsif ($dn) {
        $hashkey = $name . "_" . $dn;
      }
      elsif ($id) {
        $hashkey = $name . "_" . $id;
      }
      else {
        $hashkey = $name;
      }
      $equipment{$hashkey} = $state;
    }
    $depth--;
  }
  $depth++;

  for(my $i=0; $i<$length; $i++) {
    my $node        = $nodeList->item($i);
    my $theType     =$node->getNodeType;
    my $j=$i+1;

    if ($theType == ELEMENT_NODE ) {
      #Recursive call to itself
      printNode( $node );
    }
  }
  $depth--;
}

sub print_equipment {
  
  foreach my $item (sort keys %equipment) {
    if ($item) {
      print $item . ":" . $equipment{$item} . "\n";
    }
  }

}

sub printXML2Array($;$;$)
{
        my ($lContents,$sObject,$errflag)=@_;

	my $parser = new XML::DOM::Parser;
	my $config = $parser->parse($lContents);

	printNode($config->getChildNodes);

}

sub get_equipment_in_file {

  open(FILE, "<$FileName") || die "cannot open $!";
  @equipment_in_file = <FILE>;
  close FILE;
}

sub convert_h_to_a {
  
  foreach $item (sort keys %equipment) {
    push(@equipment_read, $item . ": " . $equipment{$item}."\n");
  }
}

# Print usage message.
sub usage {
    print "$PROGNAME XML-API demo sample.\n\n";
    print "\© 2010 Cisco Systems, Inc. All rights reserved.\n";
    print "***********************************************************************\n";
    print "*                                                                     *\n";
    print "* Do not use on production systems nor in customer environments!!!    *\n";
    print "*                                                                     *\n";
    print "***********************************************************************\n\n";
    my $options = <<HERE_OPT;
        --server=<server>        Server address.
        --port=<port>            Server port.
        --uname=<Username>       Monitoring Service Account
        --passwd=<Password>      Monitoring Service Password
        --filename=<Filename>    Filname of the comparision File
        --writetofile            instead of testing write a new xml-temlate file
        --chassis=n              chassis to use (default 1)
        --usage                  This usage message.
        --help                   This help message.
HERE_OPT
    $options =~ s/^\s+/    /gm;

    print "Usage : $0 <OPTIONS>\n$options\n";
    print "Example :\n";
    print "perl  $0 --uname=admin --passwd=nbv12345 \\ \n";
    print "   --server=10.193.36.108 --port=80\n";

    exit(1);
}

#
# Prepare the xml for transmission - add necessary tokens.
#
sub prepareXmlQuery
{
    my ($mCookie, $lXmlMethod, $lAttrs, $noCookie) = @_;

#print("(method=$lXmlMethod) (Cookie=$mCookie) (Attrs=$lAttrs)\n") if $VERBOSE;

    my $content = undef;

    if ($noCookie)
    {
	$content = '<' . $lXmlMethod . ' ' . $lAttrs . ' />';
    }
    else
    {
        $content = '<' . $lXmlMethod . ' ' . $lAttrs . ' cookie="' . $mCookie . '"  />';
    }

    return $content;
}

# Parameters:
#  the uri
#  an arrayref or hashref for the key/value pairs,
#  and then, optionally, any header lines: (key,value, key,value)
sub doPostXML
{
    my ($mUri, $postData) = @_;
    if (!$mBrowser)
    {
        $mBrowser = LWP::UserAgent->new();
    }
    my $request = HTTP::Request->new(POST => $mUri);
    $request->content_type("application/x-www-form-urlencoded");
    $request->content($postData);

    print("\nRequest: \n" . $request->as_string() . "\n") if $VERBOSE;

    my $resp = $mBrowser->request($request);    #HTTP::Response object

    print("\nResponse: \n" . $resp->content . "\n") if $VERBOSE;

    return ($resp->content, $resp->status_line, $resp->is_success, $resp)
      if wantarray;
    return unless $resp->is_success;
    return $resp->content;
}


# Specify the command line options and process the command line
my $options_okay = GetOptions (
    # Application specific options
    'server=s'      => \$lServer,     # Server address
    'port=s'        => \$lPort,         # Server port
    'uname=s'       => \$lUname,        # User name.
    'passwd=s'      => \$lPasswd,       # Password.
    'filename=s'      => \$FileName,       # Password.
    'chassis=i'      => \$ChassisNbr,       # Password.
    'writetofile'      => \$WriteToFile,       # Password.

    # Standard meta-options
    'usage'         => sub { usage(); },
    'help'          => sub { usage(); },
);



usage() if !$options_okay;

usage() if ((!$lUname) || (!$lPasswd) || (!$lPort) || (!$lServer) || (!$FileName));

$Chassis = "";
if ($ChassisNbr) {
  $Chassis = "sys/chassis-" . $ChassisNbr;
}
else {
  $Chassis = "sys/chassis-1";
}

my $lUri = "http://" . $lServer . ":" . $lPort . "/nuova";

my $lCookie = doLogin($lUri, $lUname, $lPasswd);

if (!defined($lCookie)) {
  print "ERROR: Problem with Login to ucs!\n";
  exit 1;
}

my $response;
$response=resolveClass($Chassis, $lCookie, 1 , $lUri);
printXML2Array($response,$Chassis,0);  ##check the object ..

doLogout($lUri, $lCookie);

if ($WriteToFile) {
  open(FILE, "+>$FileName") || die "cannot open File $!";
  convert_h_to_a();
  foreach $key (@equipment_read) {
    if ($key && $key !~ /^:/) {
      chomp($key);
      print FILE $key . "\n";
    }
  }
  close FILE;
}
else {
  get_equipment_in_file();
  convert_h_to_a();


  $lc = List::Compare->new(\@equipment_in_file, \@equipment_read);

  @onlyinfile = $lc->get_unique;
  @onlyinfile1 = "";
  @onlyineq = $lc->get_complement;
  @onlyineq1 = "";

  foreach $key (@onlyinfile) {
    if ($key && $key !~ /powerBudget_budget/ && $key !~ /firmwareBootUnit_bootunit-combined/ && $key !~ /^:/) {
      push(@onlyinfile1, $key);
    }
  }

  foreach $key (@onlyineq) {
    if ($key && $key !~ /powerBudget_budget/ && $key !~ /firmwareBootUnit_bootunit-combined/ && $key !~ /^:/) {
      push(@onlyineq1, $key);
    }
  }

  if ($#onlyineq1 < 1 && $#onlyinfile1 < 1) {
    print "UCS Overall Health OK\n";
    exit 0;
  }
  else {
    print "WARNING: Problem with UCS Health: ";
    my $val = "";
    foreach $key (@onlyinfile1) {
      if ($val) {
        $val .= $key;
      }
      else {
        $val = $key;
      }
    }
    foreach $key (@onlyineq1) {
      if ($val) {
        $val .= $key;
      }
      else {
        $val = $key;
      }
    }
    print $val . "\n";
    exit 1;
  }
}

exit 0;


