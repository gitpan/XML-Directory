package XML::Directory;

require 5.005_62;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(get_dir);
our $VERSION = '0.30';


######################################################################
# public function
sub get_dir($) {

    my $dir = shift;
    if ($dir =~ /^(.*)[\\\/]$/) {$dir = $1}
    chdir $dir;

    my $res = [];
    my @dirs = split("/",$dir);
    my $last_dir = pop @dirs;

    @$res = ('<?xml version="1.0" encoding="utf-8"?>','<dirtree>');
    my @stat = stat '.';
    push @$res, "  <directory name=\"$last_dir\" depth=\"0\" uid=\"$stat[4]\" gid=\"$stat[5]\">";
    push @$res, "    <path>$dir</path>";
    my $atime = localtime($stat[8]);
    my $mtime = localtime($stat[9]);
    push @$res, "    <access-time epoch=\"$stat[8]\">$atime</access-time>";
    push @$res, "    <modify-time epoch=\"$stat[9]\">$mtime</modify-time>";


    foreach (<*>) {
	if (-f $_) {
	    get_file($res, $_, '  ');
	}
    }

    recursive($res,1,$dir); 

    push @$res, '  </directory>', '</dirtree>';
    return @$res;
}

######################################################################
# private procedure to process subdirectories recursively
sub recursive {

    my $res = shift;
    my $i = shift;
    my $dir = shift;

    foreach my $d (<*>) {
	if (-d $d) {
	    my $indent = '  ' . ('  'x$i);
	    my $path;
	    if ($^O =~ /win/io) {$path = "$dir\\$d"}
	    else {$path = "$dir/$d"}

	    my @stat = stat "$d";
	    push @$res, "$indent<directory name=\"$d\" depth=\"$i\" uid=\"$stat[4]\" gid=\"$stat[5]\">";
	    push @$res, "  $indent<path>$path</path>";
	    my $atime = localtime($stat[8]);
	    my $mtime = localtime($stat[9]);
	    push @$res, "  $indent<access-time epoch=\"$stat[8]\">$atime</access-time>";
	    push @$res, "  $indent<modify-time epoch=\"$stat[9]\">$mtime</modify-time>";

	    chdir $d;

	    foreach (<*>) {
		if (-f $_) {
		    get_file($res, $_, $indent);
		}
	    }

	    $i++;
	    recursive($res,$i,$path); 
	    chdir ".."; 
	    $i--; 

	    push @$res, "$indent</directory>";
	}
    }
}

######################################################################
# private procedure to get file attributes
sub get_file($$$) {

my $res = shift;
my $path = shift;
my $indent = shift;

my @stat = stat $path;

push @$res, "  $indent<file name=\"$_\" uid=\"$stat[4]\" gid=\"$stat[5]\">";

my $mode;
if (-r $path) {$mode = 'r' }else {$mode = '-'}
if (-w $path) {$mode .= 'w' }else {$mode .= '-'}
if (-x $path) {$mode .= 'x' }else {$mode .= '-'}
push @$res, "    $indent<mode code=\"$stat[2]\">$mode</mode>";
push @$res, "    $indent<size unit=\"bytes\">$stat[7]</size>";

my $atime = localtime($stat[8]);
my $mtime = localtime($stat[9]);
push @$res, "    $indent<access-time epoch=\"$stat[8]\">$atime</access-time>";
push @$res, "    $indent<modify-time epoch=\"$stat[9]\">$mtime</modify-time>";

push @$res, "  $indent</file>";

}

1;

__END__
# Below is a documentation.

=head1 NAME

XML::Directory - Perl extension to get a content of directory including 
sub-directories as an XML file

=head1 VERSION

0.30

=head1 SYNOPSIS

  use XML::Directory(qw(get_dir));
  @xml = get_dir('/home/petr');

=head1 DESCRIPTION

This utility extension provides just one function.

=head2 get_dir();

This functions takes a path as its only parameter and returns an array
containing XML representation of a directory specified by the path. Each
field of the array represents one line of the XML.

=head2 EXPORT

None by default.

=head1 AUTHOR

Petr Cimprich, petr@gingerall.cz

=head1 SEE ALSO

perl(1).

=cut
