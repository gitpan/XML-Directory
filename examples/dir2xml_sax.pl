#!/usr/bin/perl

use XML::Directory;
use MyHandler;
use MyErrorHandler;
use strict;

(@ARGV == 1 ) || die ("Usage: dir2xml_sax.pl path\n\n");

my $path = shift;

my $dir = new XML::Directory($path);

$dir->set_maxdepth(10);
$dir->set_details(3);

my $h = new MyHandler;
my $e = new MyErrorHandler;

my $rc  = $dir->parse_SAX($h,$e);

exit 0;
