use strict;
use warnings;

package XML::Directory::SAX;

require 5.005_62;
use Carp;
use XML::Directory;
use XML::Directory::Exception;

@XML::Directory::SAX::ISA = qw(XML::Directory);

sub parse {
    my $self = shift;

    unless (ref($self->{ContentHandler})) {
	$self->doError(4,"ContentHandler is not set!")
    }
    
    $self->SUPER::parse;
    return $self->{ret};
}

sub set_content_handler {
    my ($self, $handler) = @_;
    $handler = '' unless @_ > 1;
    $self->{ContentHandler} = $handler;
}

sub set_error_handler {
    my ($self, $err_handler) = @_;
    $err_handler = '' unless @_ > 1;
    $self->{ErrorHandler} = $err_handler;
}

sub doStartDocument {
    my $self = shift;
    $self->{ContentHandler}->start_document;
}

sub doEndDocument {
    my $self = shift;
    $self->{ret} = $self->{ContentHandler}->end_document;
}

sub doStartElement {
    my ($self, $tag, $attr, $qname) = @_;
    my $SAXattr = {};
    foreach (@$attr) {
	my $attkey = "{}$_->[0]";
	$SAXattr->{$attkey} = XML::Directory::Attribute->new (
	    Name => $_->[0],
	    Value => $_->[1],
	    NamespaceURI => '',
	    Prefix => '',
	    LocalName => $_->[0]
	)
    };
    my $uri = $self->_ns_uri;
    my $prefix = '';
    $prefix = $self->_ns_prefix unless $qname;
    my $name = $tag;
    $name = "$prefix:$tag" if $prefix;

    $self->{ContentHandler}->start_element({
	Name => $name,
	Attributes => $SAXattr,
	NamespaceURI => $uri,
	Prefix => $prefix,
	LocalName => $tag
    });
};

sub doEndElement {
    my ($self, $tag, $qname) = @_;
    my $uri = $self->_ns_uri;
    my $prefix = '';
    $prefix = $self->_ns_prefix unless $qname;
    my $name = $tag;
    $name = "$prefix:$tag" if $prefix;

    $self->{ContentHandler}->end_element({
	Name => $name,
	NamespaceURI => $uri,
	Prefix => $prefix,
	LocalName => $tag
    });
}

sub doElement {
    my ($self, $tag, $attr, $value, $qname) = @_;
    $self->doStartElement($tag, $attr, $qname);
    $self->{ContentHandler}->characters({
	Data => $value
    });
    $self->doEndElement($tag, $qname);
}

sub doError {
    my ($self, $n, $msg) = @_;

    unless ($self->{catch_error}) {
	croak "$msg\n"

    } else {

	$msg =~ s/&/&amp;/g;
	$msg =~ s/</&lt;/g;
	$msg =~ s/>/&gt;/g;
	my $exception = new XML::Directory::Exception (
		Message => $msg,
		Exception => undef);
	$self->{error} = $n;

	$@ = $exception;
	if (ref($self->{ErrorHandler})) {
	    $self->{ErrorHandler}->fatal_error($exception);
	}
    }
}

sub _ns_prefix {
    my $self = shift;
    
    my $pref = '';
    if ($self->{ns_enabled} && $self->{ns_prefix}) {
	$pref = "$self->{ns_prefix}";
    }
    return $pref;
}

sub _ns_uri {
    my $self = shift;
    
    my $uri = '';
    if ($self->{ns_enabled} && $self->{ns_uri}) {
	$uri = "$self->{ns_uri}";
    }
    return $uri;
}

###########################################################
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

XML::Directory::SAX - a subclass to generate SAX events 

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

