# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use XML::Directory(qw(get_dir));

BEGIN { $| = 1; print "1..2\n"; }
END {print "There were problems!\n" unless ($loaded && $found);}
END {print "Passed\n" if ($loaded + $found == 2);}

$loaded = 1;
print "not ok 1\n" unless $loaded;
print "ok 1\n" if $loaded;

my @xml = get_dir('scripts');
my $xml = join '', @xml;
$found = 1 if $xml =~ /dir2xml.pl.*dir2xml_cgi.pl/;
print "not ok 2\n" unless $found;
print "ok 2\n" if $found;
