#!/usr/bin/perl

use XML::Directory;
use strict;

(@ARGV == 1 ) || die ("Usage: dir2xml_oo.pl path\n\n");

my $path = shift;

my $dir = new XML::Directory($path,2,5);
my $rc  = $dir->parse;
my $xml = $dir->get_arrayref;

foreach (@$xml) {
    print "$_\n";
}

exit 0;


