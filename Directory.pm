package XML::Directory;

require 5.005_62;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(get_dir);
our $VERSION = '0.41';


######################################################################
# object interface

sub new {
    my ($class, $path, $details, $depth) = @_;
    $details = 2 unless @_ > 2;
    $depth = 1000 unless @_ > 3;
    my $xml = [];

    my $self = {
		path    => $path,
		details => $details,
		depth   => $depth,
		xml     => $xml,
		error   => 0
	       };
    bless $self, $class;
    return $self;
}

sub parse {
    my $self = shift;
    my @xml = ();

    if ($self->{details} !~ /^[123]$/) {
	@xml = $self->_set_error(1,"Details value ($self->{details}) invalid!")
    }
    if ($self->{depth} !~ /^\d+$/) {
	@xml = $self->_set_error(2,"Depth value ($self->{depth}) invalid!")
    }
    if ($self->{error} == 0) {
	eval {
	    @xml =  get_dir($self->{path},$self->{details},$self->{depth});
	};
    }
    if ($@) {
	chomp $@;
	@xml = $self->_set_error(3,"$@")
    }
    $self->{xml} = \@xml;
    return scalar(@xml);
}

sub set_path {
    my ($self, $path) = @_;
    $path = '.' unless @_ > 1;
    $self->{path} = $path;
}

sub set_details {
    my ($self, $details) = @_;
    $details = 2 unless @_ > 1;
    $self->{details} = $details;
}

sub set_maxdepth {
    my ($self, $depth) = @_;
    $depth = 1000 unless @_ > 1;
    $self->{depth} = $depth;
}

sub get_arrayref {
    my $self = shift;
    return $self->{xml};
}

sub get_array {
    my $self = shift;
    my $xml = $self->{xml};
    return @$xml;
}

sub get_string {
    my $self = shift;
    my $xml = $self->{xml};
    return join "\n", @$xml, '';
}

sub get_path {
    my $self = shift;
    return $self->{path};
}

sub get_details {
    my $self = shift;
    return $self->{details};
}

sub get_maxdepth {
    my $self = shift;
    return $self->{depth};
}

sub _set_error {
    my $self = shift;
    my $num = shift;
    my $msg = shift;
    my @err = ();
    push @err, '<?xml version="1.0" encoding="utf-8"?>';
    push @err, '<dirtree>';
    push @err, "<error number=\"$num\">$msg</error>";
    push @err, '</dirtree>';
    $self->{error} = $num;
    return @err;
}

######################################################################
# original interface

sub get_dir {
    my ($path, $details, $depth) = @_;
    $details = 3 unless @_ > 1;
    $depth = 1000 unless @_ > 2;
    if ($path =~ /^(.*)[\\\/]$/) {$path = $1}

    chdir ($path) or die "Path $path not found!\n";

    my $res = [];
    my @dirs = split("/",$path);
    my $last_dir = pop @dirs;

    @$res = ('<?xml version="1.0" encoding="utf-8"?>','<dirtree>');

    my @stat = stat '.';

    my $line = "  <directory name=\"$last_dir\"";
    $line .= " depth=\"0\"" if $details > 1;
    $line .= " uid=\"$stat[4]\" gid=\"$stat[5]\"" if $details > 2;
    $line .= '>';
    push @$res, $line;
    push @$res, "    <path>$path</path>"if $details > 1;
    my $atime = localtime($stat[8]);
    my $mtime = localtime($stat[9]);
    push @$res, "    <access-time epoch=\"$stat[8]\">$atime</access-time>"
      if $details > 2;
    push @$res, "    <modify-time epoch=\"$stat[9]\">$mtime</modify-time>"
      if $details > 1;

    foreach (<*>) {
	if (-f $_) {
	    __get_file($res, $_, '  ', $details);
	}
    }

    if ($depth > 0) {
	__recursive($res,1,$path,$details,$depth); 
    }

    push @$res, '  </directory>', '</dirtree>';
    return @$res;
}

######################################################################
# private procedures

sub __recursive {

    my $res = shift;
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

	    my $line = "$indent<directory name=\"$d\"";
	    $line .= " depth=\"$i\"" if $details > 1;
	    $line .= " uid=\"$stat[4]\" gid=\"$stat[5]\"" if $details > 2;
	    $line .= '>';
	    push @$res, $line;
	    push @$res, "  $indent<path>$path</path>" if $details > 1;;
	    my $atime = localtime($stat[8]);
	    my $mtime = localtime($stat[9]);
	    push @$res, "  $indent<access-time epoch=\"$stat[8]\">$atime</access-time>" if $details > 2;
	    push @$res, "  $indent<modify-time epoch=\"$stat[9]\">$mtime</modify-time>" if $details > 1;

	    chdir $d;

	    foreach (<*>) {
		if (-f $_) {
		    __get_file($res, $_, $indent, $details);
		}
	    }

	    if ($depth > $i) {
		$i++;
		__recursive($res,$i,$path,$details,$depth); 
		$i--; 
	    }

	    chdir ".."; 

	    push @$res, "$indent</directory>";
	}
    }
}

sub __get_file($$$$) {

my $res     = shift;
my $path    = shift;
my $indent  = shift;
my $details = shift;

my @stat = stat $path;

my $line = "  $indent<file name=\"$_\"";
$line .= " uid=\"$stat[4]\" gid=\"$stat[5]\"" if $details > 2;
$line .= '/' if $details == 1;
$line .= '>';
push @$res, $line;

my $mode;
if (-r $path) {$mode = 'r' }else {$mode = '-'}
if (-w $path) {$mode .= 'w' }else {$mode .= '-'}
if (-x $path) {$mode .= 'x' }else {$mode .= '-'}
push @$res, "    $indent<mode code=\"$stat[2]\">$mode</mode>" 
  if $details > 1;
push @$res, "    $indent<size unit=\"bytes\">$stat[7]</size>" 
  if $details > 1;

my $atime = localtime($stat[8]);
my $mtime = localtime($stat[9]);
push @$res, "    $indent<access-time epoch=\"$stat[8]\">$atime</access-time>"
  if $details > 2;
push @$res, "    $indent<modify-time epoch=\"$stat[9]\">$mtime</modify-time>"
  if $details > 1;

push @$res, "  $indent</file>" if $details > 1;

}

1;

__END__
# Below is a documentation.

=head1 NAME

XML::Directory - Perl extension allowing to get a content of directory 
including sub-directories as an XML file. The current version is 0.41.

=head1 SYNOPSIS

 $dir = new XML::Directory('/home/petr',2,5);

 $dir->set_path('/home/petr');
 $dir->set_details(3);
 $dir->set_maxdepth(10);

 $rc  = $dir->parse;

 $res = $dir->get_arrayref;
 @res = $dir->get_array;
 $res = $dir->get_string;

or

 use XML::Directory(qw(get_dir));
 @xml = get_dir('/home/petr',2,5);

=head1 DESCRIPTION

This utility extension provides XML::Directory class and its methods
plus the original public function (get_dir) because of  backward 
compatibility.

=head2 XML::DIRECTORY CLASS

=over

=item new

 $dir = new XML::Directory('/home/petr',2,5);
 $dir = new XML::Directory('/home/petr',2);
 $dir = new XML::Directory('/home/petr');

The constructor accepts up to 3 parameters: path, details (1-3, brief or 
verbose XML) and depth (number of nested sub-directories). The last two 
parameters are optional (defaulted to 2 and 1000).

=item set_path

 $dir->set_path('/home/petr');

Resets path. An initial path is set using the constructor.

=item set_details

 $dir->set_details(3);

Sets or resets level of details to be returned. Can be also set using 
the constructor. Valid values are 1, 2 or 3.

 1 = brief

 Example:

 <?xml version="1.0" encoding="utf-8"?>
 <dirtree>
   <directory name="test">
     <file name="dir2xml.pl"/>
   </directory>
 </dirtree>

 2 = normal

 Example:

 <?xml version="1.0" encoding="utf-8"?>
 <dirtree>
   <directory name="test" depth="0">
     <path>/home/petr/test</path>
     <modify-time epoch="998300843">Mon Aug 20 11:47:23 2001</modify-time>
     <file name="dir2xml.pl">
       <mode code="33261">rwx</mode>
       <size unit="bytes">225</size>
       <modify-time epoch="998300843">Mon Aug 20 11:47:23 2001</modify-time>
     </file>
   </directory>
 </dirtree>

 3 = verbose

 Example:

 <?xml version="1.0" encoding="utf-8"?>
 <dirtree>
   <directory name="test" depth="0" uid="500" gid="100">
     <path>/home/petr/test</path>
     <access-time epoch="998300915">Mon Aug 20 11:48:35 2001</access-time>
     <modify-time epoch="998300843">Mon Aug 20 11:47:23 2001</modify-time>
     <file name="dir2xml.pl" uid="500" gid="100">
       <mode code="33261">rwx</mode>
       <size unit="bytes">225</size>
       <access-time epoch="998300843">Mon Aug 20 11:47:23 2001</access-time>
       <modify-time epoch="998300843">Mon Aug 20 11:47:23 2001</modify-time>
     </file>
   </directory>
 </dirtree>

=item set_maxdepth

 $dir->set_maxdepth(5);

Sets or resets number of nested sub-directories to be parsed. Can also be
set using the constructor. 0 means that only a directory specified by path 
is parsed (no sub-directories).

=item parse

 $rc  = $dir->parse;

Scans directory tree specified by path and stores its XML representation 
in memory. Returns a number of lines of the XML file.

This method checks a validity of details and depth. In the event a parameter
is out of valid range, an XML file containing error message is returned. The
same is true if the path specified can't be found.

 Example:

 <?xml version="1.0" encoding="utf-8"?>
 <dirtree>
 <error number="3">Path /home/petr/work/done not found!</error>
 </dirtree>

=item get_arrayref

 $res = $dir->get_arrayref;

Returns a parsed XML directory image as a reference to array (each field 
contains one line of the XML file).

=item get_array

 @res = $dir->get_array;

Returns a parsed XML directory image as an array (each field 
contains one line of the XML file).

=item get_string

 $res = $dir->get_string;

Returns a parsed XML directory image as a string.

=item get_path

 $path = $dir->get_path;

Returns current path.

=item get_details

 $details = $dir->get_details;

Returns current level of details.

=item get_maxdepth

 $maxdepth = $dir->get_maxdepth;

Returns current number of nested sub-directories.

=back

=head2 ORIGINAL INTERFACE

=over

=item get_dir();

 @xml = get_dir('/home/petr',2,5);

This functions takes a path as a mandatory parameter and details and depth
as optional ones. It returns an array containing an XML representation of 
directory specified by the path. Each field of the array represents one line 
of the XML.

Optional arguments are defaults to 3 and 1000. The default value for detail
level is different from the same default for the object interface; the reason
is to keep the get_dir function backward compatible with the version 0.30.

=back

=head1 LICENSING

Copyright (c) 2001 Ginger Alliance. All rights reserved. This program is free 
software; you can redistribute it and/or modify it under the same terms as 
Perl itself. 

=head1 AUTHOR

Petr Cimprich, petr@gingerall.cz

=head1 SEE ALSO

perl(1).

=cut
