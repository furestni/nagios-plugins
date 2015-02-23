#!/usr/bin/perl

use GD;
use Image::Grab;

$debug = 0;

my $pic = Image::Grab->new(URL=>'http://www.teletext.ch/pics/SF1/882-01.gif');
$pic->grab;
open(IMAGE, ">/tmp/actual882.gif") || die "actual882.gif: $!";
binmode IMAGE;  # for MSDOS derivations.
print IMAGE $pic->image;
close IMAGE;

open(CONVERT, "/usr/bin/convert /tmp/actual882.gif /tmp/actual882.png |") || die "cannot convert gif to png";
while (<CONVERT>) {
}
close CONVERT;
system("rm /tmp/actual882.gif");


open (PNG,"/tmp/actual882.png") || die "cannot open file $!";
$actualImage = newFromPng GD::Image(\*PNG) || die "cannot convert to GD $!";
close PNG;
open (PNG,"/usr/lib64/nagios/plugins/original882.png") || die "cannot open file $!";
$referenceImage = newFromPng GD::Image(\*PNG) || die "cannot convert to GD $!";
close PNG;

@yloc = (6, 30, 54, 72, 90, 108, 126, 144, 162, 180, 198, 216, 234, 252, 270 );

$problemcount = 0;
$row = 0;
foreach $key (@yloc) {
  $indexa = $actualImage->getPixel(20,$key);
  ($ra,$ga,$ba) = $actualImage->rgb($indexa);
  $indexr = $referenceImage->getPixel(20,$key);
  ($rr,$gr,$br) = $referenceImage->rgb($indexr);
  if (($ra-5 <= $rr && $rr <= $ra+5) && ($ga-5 <= $gr && $gr <= $ga+5) && ($ba-5 <= $br && $br <= $ba+5)) {
#  if (($ra*0.9 <= $rr && $rr <= $ra*1.1) && ($ga*0.9 <= $gr && $gr <= $ga*1.1) && ($ba*0.9 <= $br && $br <= $ba*1.1)) {
    ;
  }
  else {
    if ($debug) {
      print "ra: " . $ra . ", ga: " . $ga . ", ba: " . $ba . ", row: " . $row . "\n";
      print "rr: " . $rr . ", gr: " . $gr . ", br: " . $br . ", row: " . $row . "\n";
    }
    $problemcount++;
  }
  $row++;
}

if ($problemcount == 0) {
  print "Page 882 OK\n";
  exit 0;
}
else {
  print "Page 882 Warning\n";
  exit 1;
}

