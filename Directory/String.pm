use strict;
use warnings;

package XML::Directory::String;

require 5.005_62;
use File::Spec::Functions ();
use Carp;
use XML::Directory;

@XML::Directory::String::ISA = qw(XML::Directory);

sub parse {
    my $self = shift;
    $self->SUPER::parse;
    return scalar @{$self->{xml}};
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

sub doStartDocument {
    my $self = shift;
    $self->{xml} = [];
    $self->{level} = 0;
    push @{$self->{xml}}, '<?xml version="1.0" encoding="utf-8"?>';
}

sub doEndDocument {
}

sub doStartElement {
    my ($self, $tag, $attr) = @_;
    my $pref = $self->_ns_prefix;
    push @{$self->{xml}}, 
      '  ' x $self->{level}++ 
	. "<$pref" 
	  . "$tag "
 	    . join(' ', map {qq/$_->[0]="$_->[1]"/} @$attr)
 	      . ">"
 		;
}

sub doEndElement {
    my ($self, $tag) = @_;
    my $pref = $self->_ns_prefix;
    push @{$self->{xml}},
      '  ' x --$self->{level} 
	. "</$pref"  
	  . "$tag>"
	    ;
}

sub doElement {
    my ($self, $tag, $attr, $value) = @_;
    my $pref = $self->_ns_prefix;
    my $element = '  ' x $self->{level} 
      . "<$pref"  
      . "$tag "
      . join(' ', map {qq/$_->[0]="$_->[1]"/} @$attr) 
      . '>';
    $element .= $value if $value;
    $element .= "</$pref";
    $element .= "$tag>";
    push @{$self->{xml}}, $element;
}

sub doError {
    my ($self, $n, $msg) = @_;

    unless ($self->{catch_error}) {
	croak "$msg\n"

    } else {
	
	$self->doStartDocument;

	if ($self->{ns_enabled}) {
	    my @attr = ();
	    my $decl = $self->_ns_declaration;
	    push @attr, [$decl => $self->{ns_uri}];
	    $self->doStartElement('dirtree', \@attr);
	} else {
	    $self->doStartElement('dirtree', undef);
	}

	my @attr2 = ([number => $n]);
	$self->doElement('error', \@attr2, $msg);

	$self->doEndElement('dirtree');
	$self->{error} = $n;
    }
}

sub _ns_prefix {
    my $self = shift;
    
    my $pref = '';
    if ($self->{ns_enabled} && $self->{ns_prefix}) {
	$pref = "$self->{ns_prefix}:";
    }
    return $pref;
}

1;

__END__
# Below is a documentation.

=head1 NAME

XML::Directory::String - a subclass to generate strings

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

