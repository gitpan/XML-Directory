#!/usr/bin/perl

use XML::Directory(qw(get_dir));
use CGI_Lite;
use strict;

my $cgi = new CGI_Lite;
my %in = $cgi->parse_form_data;
my $dir = $in{dir};

my @xml = get_dir($dir);

print "Content-type: text/xml\n\n";
foreach (@xml) {
    print "$_\n";
}

exit 0;

