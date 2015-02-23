#!/usr/bin/perl

use Image::Compare;
use warnings;
use strict;
use Image::Grab;

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

my($cmp) = Image::Compare->new();
$cmp->set_image1(
   img  => '/usr/lib64/nagios/plugins/original882.png',
   type => 'png',
);
$cmp->set_image2(
   img  => '/tmp/actual882.png',
   type => 'png',
);
$cmp->set_method(
   method => &Image::Compare::THRESHOLD_COUNT,
   args   => 75,
);
my $count = 0;
if (($count = $cmp->compare()) > 14000) {
  # The images too diffenent (maybe problem)
  print "WARNING, more than 14000 pixel difference between original an actual 882 | 882_difference=$count\n";
  exit 1;
}
else {
  # The images are almost the same
  print "OK, images seems to be similar | 882_difference=$count\n";
  exit 0
}
