# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use XML::Directory(qw(get_dir));

BEGIN { $| = 1; print "1..4\n"; }
END {print "There were problems!\n" unless $sum == 4;}
END {print "Passed\n" if $sum == 4;}

# 1
$r[0] = 1;
print "not ok 1\n" unless $r[0];
print "ok 1\n" if $r[0];

# 2
my @xml = get_dir('examples');
my $xml = join '', @xml;
$r[1] = 1 if $xml =~ /dir2xml.pl.*dir2xml_cgi.pl/;
print "not ok 2\n" unless $r[1];
print "ok 2\n" if $r[1];

# 3
my $depth0 = 25;
my $dir = new XML::Directory('examples',1,$depth0);
my $depth = $dir->get_maxdepth;
$r[2] = 1 if $depth == $depth0 ;
print "not ok 3\n" unless $r[2];
print "ok 3\n" if $r[2];

#4
my $rc  = $dir->parse_SAX();
$r[3] = 1 if $@ =~ /not set/; 
print "not ok 4\n" unless $r[3];
print "ok 4\n" if $r[3];

$sum = 0;
foreach (@r) {
    $sum += $_;
}
