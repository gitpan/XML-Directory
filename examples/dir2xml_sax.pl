#!/usr/bin/perl

use XML::Directory::SAX;
use MyHandler;
use MyErrorHandler;
use strict;

(@ARGV == 1 ) || die ("Usage: dir2xml_sax.pl path\n\n");

my $path = shift;

my $dir = new XML::Directory::SAX($path);

$dir->set_maxdepth(10);
$dir->set_details(3);

my $h = new MyHandler;
my $e = new MyErrorHandler;

$dir->set_content_handler($h);
$dir->set_error_handler($e);

my $rc  = $dir->parse;

exit 0;
