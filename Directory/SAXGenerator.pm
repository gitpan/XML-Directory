package XML::Directory::SAXGenerator;

require 5.005_62;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(_get_dir_SAX);

sub _get_dir_SAX {
    my ($h, $path, $details, $depth) = @_;
    $details = 3 unless @_ > 1;
    $depth = 1000 unless @_ > 2;
    if ($path =~ /^(.*)[\\\/]$/) {$path = $1}

    chdir ($path) or die "Path $path not found!\n";

    my @dirs = split("/",$path);
    my $last_dir = pop @dirs;

    $h->start_document({});

    my $doc_el = {Name => 'dirtree',
		  Attributes => {},
		  NamespaceURI => '',
		  Prefix => '',
		  LocalName => 'dirtree'};

    $h->start_element($doc_el);

    my @stat = stat '.';

    my $dir_el = _get_current_dir($h,$details,0,$last_dir,$path,@stat);

    # nested dirs
    if ($depth > 0) {
	_recursive_SAX($h, 1, $path, $details, $depth); 
    }

    # final dirs
    if ($depth == 0) {
	foreach (<*>) {
	    if (-d $_) {
		my @dst = stat "$_";
		my $dp;
		if ($^O =~ /win/io) {$dp = "$path\\$_"}
		else {$dp = "$path/$_"}
		my $del = _get_current_dir($h,$details,1,$_,$dp,@dst);    
		$h->end_element($del);
	    }
	}
    }

    # files
    foreach (<*>) {
	if (-f $_) {
	    _get_file_SAX($h, $_, $details);
	}
    }

    $h->end_element($dir_el);
    $h->end_element($doc_el);
    $h->end_document({});
}

sub _recursive_SAX {

    my $h = shift;
    my $i = shift;
    my $dir = shift;
    my $details = shift;
    my $depth = shift;

    foreach my $d (<*>) {
	if (-d $d) {
	    my $indent = '  ' . ('  'x$i);
	    my $path;
	    if ($^O =~ /win/io) {$path = "$dir\\$d"}
	    else {$path = "$dir/$d"}

	    my @stat = stat "$d";

	    my $dir_el = _get_current_dir($h,$details,$i,$d,$path,@stat);

	    chdir $d;

	    # nested dirs
	    if ($depth > $i) {
		$i++;
		_recursive_SAX($h, $i, $path, $details, $depth); 
		$i--; 
	    }

	    # final dirs
	    unless ($depth > $i) {
		my $j = $i + 1;
		foreach (<*>) {
		    if (-d $_) {
			my @dst = stat "$_";
			my $dp;
			if ($^O =~ /win/io) {$dp = "$path\\$_"}
			else {$dp = "$path/$_"}
			my $del = _get_current_dir($h,$details,$j,$_,$dp,@dst);
			$h->end_element($del);
		    }
		}
	    }

	    # files
	    foreach (<*>) {
		if (-f $_) {
		    _get_file_SAX($h, $_, $details);
		}
	    }

	    chdir ".."; 

	    $h->end_element($dir_el);
	}
    }
}

sub _get_file_SAX($$$$) {

my $h       = shift;
my $path    = shift;
my $details = shift;

my @stat = stat $path;

my $at_name = new XML::Directory::Attribute (
        Name => 'name',
        Value => $path,
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'name');
my $at_uid = new XML::Directory::Attribute (
	Name => 'uid',
	Value => $stat[4],
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'uid');
my $at_gid = new XML::Directory::Attribute (
	Name => 'gid',
	Value => $stat[5],
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'gid');

my %attr_f;
$attr_f{name} = $at_name;
$attr_f{uid} = $at_uid if $details > 2;
$attr_f{gid} = $at_gid if $details > 2;

my $file_el = {Name => 'file',
	       Attributes => \%attr_f,
	       NamespaceURI => '',
	       Prefix => '',
	       LocalName => 'file'};

$h->start_element($file_el);

my $mode;
if (-r $path) {$mode = 'r' }else {$mode = '-'}
if (-w $path) {$mode .= 'w' }else {$mode .= '-'}
if (-x $path) {$mode .= 'x' }else {$mode .= '-'}

my $attr = new XML::Directory::Attribute (
	Name => 'code',
	Value => $stat[2],
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'code');

my %attr_m;
$attr_m{code} = $attr if $details > 1;

my $element = {Name => 'mode',
	    Attributes => \%attr_m,
	    NamespaceURI => '',
	    Prefix => '',
	    LocalName => 'mode'};

my $data = {Data => $mode};

if ($details > 1) {
    $h->start_element($element);
    $h->characters($data);
    $h->end_element($element);
}

$attr = new XML::Directory::Attribute (
	Name => 'unit',
	Value => 'bytes',
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'unit');

my %attr_s;
$attr_s{unit} = $attr if $details > 1;

$element = {Name => 'size',
	    Attributes => \%attr_s,
	    NamespaceURI => '',
	    Prefix => '',
	    LocalName => 'size'};

$data = {Data => $stat[7]};

if ($details > 1) {
    $h->start_element($element);
    $h->characters($data);
    $h->end_element($element);
}

_get_time($h, $details, $stat[8], $stat[9]);

$h->end_element($file_el);
}

sub _get_current_dir {

my ($h, $details, $i, $dir, $path, @stat) = @_;

my $at_name = new XML::Directory::Attribute (
        Name => 'name',
        Value => $dir,
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'name');
my $at_depth = new XML::Directory::Attribute (
	Name => 'depth',
	Value => $i,
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'depth');
my $at_uid = new XML::Directory::Attribute (
	Name => 'uid',
	Value => $stat[4],
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'uid');
my $at_gid = new XML::Directory::Attribute (
	Name => 'gid',
	Value => $stat[5],
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'gid');

my %attr;
$attr{name} = $at_name;
$attr{depth} = $at_depth if $details > 1;
$attr{uid} = $at_uid if $details > 2;
$attr{gid} = $at_gid if $details > 2;
    
my $dir_el = {Name => 'directory',
	      Attributes => \%attr,
	      NamespaceURI => '',
	      Prefix => '',
	      LocalName => 'directory'};

eval $h->start_element($dir_el);

my $element = {Name => 'path',
	       Attributes => {},
	       NamespaceURI => '',
	       Prefix => '',
	       LocalName => 'path'};

my $data = {Data => $path};

if ($details > 1) {
    $h->start_element($element);
    $h->characters($data);
    $h->end_element($element);
}

_get_time($h, $details, $stat[8], $stat[9]);

return $dir_el;
}

sub _get_time {

my $h       = shift;
my $details = shift;
my $aepo    = shift;
my $mepo    = shift;

my $atime = localtime($aepo);
my $mtime = localtime($mepo);

my $at_epoch = new XML::Directory::Attribute (
	Name => 'epoch',
	Value => $aepo,
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'epoch');

my %attr_at;
$attr_at{epoch} = $at_epoch if $details > 2;

my $element = {Name => 'access-time',
	       Attributes => \%attr_at,
	       NamespaceURI => '',
	       Prefix => '',
	       LocalName => 'access-time'};

my $data = {Data => $atime};

if ($details > 2) {
    $h->start_element($element);
    $h->characters($data);
    $h->end_element($element);
}

$at_epoch = new XML::Directory::Attribute (
	Name => 'epoch',
	Value => $mepo,
	NamespaceURI => '',
	Prefix => '',
	LocalName => 'epoch');

my %attr_mt;
$attr_mt{epoch} = $at_epoch if $details > 1;

$element = {Name => 'modify-time',
	    Attributes => \%attr_mt,
	    NamespaceURI => '',
	    Prefix => '',
	    LocalName => 'modify-time'};

$data = {Data => $mtime};

if ($details > 1) {
    $h->start_element($element);
    $h->characters($data);
    $h->end_element($element);
}

}

# The idea of overloading attributes as well as
# the following portion of code comes from XML::LibXML
# by Matt Sergeant.
package XML::Directory::Attribute;

use overload '""' => "stringify";

sub new {
    my $class = shift;
    my %p = @_;
    return bless \%p, $class;
}

sub stringify {
    my $self = shift;
    return $self->{Value};
}

1;

__END__
# Below is a documentation.

=head1 NAME

XML::Directory::SAXGenerator - a utility used by XML::Directory to generate
SAX events. See XML::Directory docs for details.

=head1 LICENSING

Copyright (c) 2001 Ginger Alliance. All rights reserved. This program is free 
software; you can redistribute it and/or modify it under the same terms as 
Perl itself. 

=head1 AUTHOR

Petr Cimprich, petr@gingerall.cz

=head1 SEE ALSO

perl(1).

=cut
