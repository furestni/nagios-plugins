#!/usr/bin/perl

use JSON::XS;
use LWP::UserAgent;

sub login {

  # First lets setup the HTTP request for the session
  my $session_uri = "http://hbbtv.swisstxt.ch/Admin/Api/Status";
  my $session_req = HTTP::Request->new( 'GET', $session_uri );
  $session_req->header( 'Content-Type' => 'application/json' );
  $session_req->content( $session_json );

  # Now create a LWP agent and make the request
  my $session_lwp = LWP::UserAgent->new;
  $session_res = $session_lwp->request( $session_req );

  # decode the return json
  $session_output = decode_json($session_res->content);
  return $session_output;
}

#Init of Session Variables
my $session = login();
my $state = $session->[0]{"State"};
my $state_name;
my $name = $session->[0]{"Name"};
my $desc = $session->[0]{"Description"};

#If Variable is null
if ($name eq '') {
        $name = "null";
}
if ($desc eq '') {
  $desc = "null";
}


SELECT:{
if ($state == 0){ $state_name = "OK" ; last SELECT; }
if ($state == 1){ $state_name = "Warning" ; last SELECT; }
if ($state == 2){ $state_name = "Critical" ; last SELECT; }
if ($state == 3){ $state_name = "Unknown" ; last SELECT; }
}

print "State: " . $state_name . " Name: " . $name . " Description: " . $desc . "\n";

#exit $state;
exit 0;
