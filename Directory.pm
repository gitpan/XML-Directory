package XML::Directory;

require 5.005_62;
use strict;
use warnings;
use File::Spec::Functions ();
use Carp;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(get_dir);
our $VERSION = '0.70';


######################################################################
# object interface

sub new {
    my ($class, $path, $details, $depth) = @_;
    $path = '.'   unless @_ > 1;
    $details = 2  unless @_ > 2;
    $depth = 1000 unless @_ > 3;

    my $self = {
	path    => File::Spec::Functions::canonpath($path),
	details => $details,
	depth   => $depth,
	error   => 0,
	catch_error => 0,	
	ns_enabled  => 0,
	ns_uri      => 'http://gingerall.org/directory',
	ns_prefix   => 'xd',

    };
    bless $self, $class;
    return $self;
}

sub parse {
    my $self = shift;

    if ($self->{details} !~ /^[123]$/) {
	$self->doError(1,"Details value ($self->{details}) invalid!")
    }
    if ($self->{depth} !~ /^\d+$/) {
	$self->doError(2,"Depth value ($self->{depth}) invalid!")
    }
    if ($self->{error} == 0) {
	eval {

	    chdir ($self->{path}) or die "Path $self->{path} not found!\n";
	    my @dirs = File::Spec::Functions::splitdir($self->{path});
	    my $dirname = pop @dirs;

	    $self->doStartDocument;

	    if ($self->{ns_enabled}) {
		my @attr = ();
		my $decl = $self->_ns_declaration;
		push @attr, [$decl => $self->{ns_uri}];
		$self->doStartElement('dirtree', \@attr);
	    } else {
		$self->doStartElement('dirtree', undef);
	    }

	    if ($self->{details} > 1) {
		my @attr = ();
		push @attr, [version => $XML::Directory::VERSION];
	
		$self->doStartElement('head', \@attr);
		$self->doElement('path', undef, $self->{path});
		$self->doElement('details', undef, $self->{details});
		$self->doElement('depth', undef, $self->{depth});
		$self->doEndElement('head');
	    }
	    
	    $self->_directory('', $dirname, 0);
	    
	    $self->doEndElement('dirtree');
	    $self->doEndDocument;
	};
	  if ($@) {
	      chomp $@;
	      $self->doError(3,"$@");
	  }
    }
}

sub set_path {
    my ($self, $path) = @_;
    $path = '.' unless @_ > 1;
    $self->{path} = File::Spec::Functions::canonpath($path),;
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

sub enable_ns {
    my ($self) = @_;
    $self->{ns_enabled} = 1;
}

sub disable_ns {
    my ($self) = @_;
    $self->{ns_enabled} = 0;
}

sub get_ns_data {
    my $self = shift;
    return {
	    ns_enabled => $self->{ns_enabled},
	    ns_uri     => $self->{ns_uri},
	    ns_prefix  => $self->{ns_prefix},
	   };
}

sub error_treatment {
    my ($self, $val) = @_;
    if (@_ > 1) {
	$self->{catch_error} = 0 if $val eq 'die';
	$self->{catch_error} = 1 if $val eq 'warn';
    } else {
	return 'die' if $self->{catch_error} == 0;
	return 'warn' if $self->{catch_error} == 1;
    }
}

######################################################################
# original interface

sub get_dir {
    
    require XML::Directory::String;
    my $h = XML::Directory::String->new(@_);
    $h->parse;
    return @{$h->{xml}};
}

######################################################################
# private procedures

sub _directory {
    my ($self, $path, $dirname, $level) = @_;

    my @stat = stat '.';
    $dirname =~ s/&/&amp;/;

    my @attr = ([name => $dirname]);
    push @attr, ['depth', $level] if $self->{details} > 1;
    push @attr, ['uid', $stat[4]] if $self->{details} > 2;
    push @attr, ['gid', $stat[5]] if $self->{details} > 2;

    $self->doStartElement('directory', \@attr);

    $self->doElement('path', undef, $path) if $self->{details} > 1;

    my $atime = localtime($stat[8]);
    my $mtime = localtime($stat[9]);
    $self->doElement('access-time', [[epoch => $stat[8]]], $atime) 
      if $self->{details} > 2;
    $self->doElement('modify-time', [[epoch => $stat[9]]], $mtime) 
      if $self->{details} > 1;


    # nested dirs
    if ($self->{depth} > $level) {
	$level++;
	foreach my $d (grep -d, <*>) {
	    my $path = File::Spec::Functions::catfile($path, $d);

	    chdir $d or croak "Cannot chdir to $d, $!\n";

	    $self->_directory($path, $d, $level);

	    chdir '..'; 
	}
	$level--;
    }

    # final dirs
    if ($self->{depth} == $level) {
	foreach my $d (grep -d, <*>) {
	    my $path = File::Spec::Functions::catfile($path, $d);
	    my @stat = stat "$_";

	    $d =~ s/&/&amp;/;

	    my @attr = ([name => $d]);
	    push @attr, ['depth', $level] if $self->{details} > 1;
	    push @attr, ['uid', $stat[4]] if $self->{details} > 2;
	    push @attr, ['gid', $stat[5]] if $self->{details} > 2;

	    $self->doElement('directory', \@attr, undef);
	}
    }

    # files
    foreach (grep -f, <*>) {
	$self->_get_file($_, $level);
    }

    $self->doEndElement('directory');
}

sub _get_file($$$$) {
    my ($self, $name, $level) = @_;

    my @stat = stat $name;
    my $esc_name = $name;
    $esc_name =~ s/&/&amp;/;

    my @attr = ();
    push @attr, [name => $esc_name];
    push @attr, [uid => $stat[4]] if $self->{details} > 2;
    push @attr, [gid => $stat[5]] if $self->{details} > 2;

    if ($self->{details} == 1) {
	$self->doElement('file', \@attr, undef)
    } else {
	$self->doStartElement('file', \@attr);

	my $mode;
	if (-r $name) {$mode = 'r' }else {$mode = '-'}
	if (-w $name) {$mode .= 'w' }else {$mode .= '-'}
	if (-x $name) {$mode .= 'x' }else {$mode .= '-'}
	$self->doElement('mode', [[code => $stat[2]]], $mode)
	    if $self->{details} > 1;
	$self->doElement('size', [[unit => 'bytes']], $stat[7])
	    if $self->{details} > 1;

	my $atime = localtime($stat[8]);
	my $mtime = localtime($stat[9]);
	$self->doElement('access-time', [[epoch => $stat[8]]], $atime)
	    if $self->{details} > 2;
	$self->doElement('modify-time', [[epoch => $stat[9]]], $mtime)
	    if $self->{details} > 1;
	$self->doEndElement('file');
    }
}

sub _ns_declaration {
    my $self = shift;
    
    my $decl = '';
    if ($self->{ns_enabled}) {
	if ($self->{ns_prefix}) {
	    $decl = "xmlns:$self->{ns_prefix}";
	} else {
	    $decl = 'xmlns';
	}
    }
    return $decl;
}

1;

__END__
# Below is a documentation.

=head1 NAME

XML::Directory - returns a content of directory as XML

=head1 LICENSING

Copyright (c) 2001 Ginger Alliance. All rights reserved. This program is free 
software; you can redistribute it and/or modify it under the same terms as 
Perl itself. 

=head1 AUTHOR

Petr Cimprich, petr@gingerall.cz
Duncan Cameron, dcameron@bcs.org.uk

=head1 SEE ALSO

perl(1).

=cut
