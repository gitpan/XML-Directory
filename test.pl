# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use XML::Directory(qw(get_dir));

BEGIN { $| = 1; print "1..3\n"; }
END {print "There were problems!\n" unless ($loaded && $found);}
END {print "Passed\n" if ($loaded + $found == 2);}

# 1
$loaded = 1;
print "not ok 1\n" unless $loaded;
print "ok 1\n" if $loaded;

# 2
my @xml = get_dir('scripts');
my $xml = join '', @xml;
$found = 1 if $xml =~ /dir2xml.pl.*dir2xml_cgi.pl/;
print "not ok 2\n" unless $found;
print "ok 2\n" if $found;

# 3
my $depth0 = 25;
my $dir = new XML::Directory('scripts',1,$depth0);
my $depth = $dir->get_maxdepth;
print "ok 3\n" if $depth == $depth0 ;
