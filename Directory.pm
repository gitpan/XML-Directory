package XML::Directory;

require 5.005_62;
use strict;
use warnings;
use File::Spec::Functions ();
use Carp;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(get_dir);
our $VERSION = '0.85';


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
	rdf_enabled => 0,	
	n3_index    => '',	
	ns_uri      => 'http://gingerall.org/directory/1.0/',
	ns_prefix   => 'xd',
	encoding    => 'utf-8',	
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
		push @attr, ['xmlns:doc' => 
			     'http://gingerall.org/charlie-doc/1.0/']
		  if $self->{rdf_enabled};
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
	    
	    my $rc = $self->_directory('', $dirname, 0);
	    return 0 if $rc == -1;
	    
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

sub encoding {
    my ($self, $code) = @_;
    if (@_ > 1) {
	$self->{encoding} = $code;
    } else {
	return $self->{encoding};
    }
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

sub enable_rdf {
    my ($self, $index) = @_;
    $self->{ns_enabled} = 1;
    $self->{rdf_enabled} = 1;
    $self->{n3_index} = $index;
    eval { require RDF::Notation3; };
    chomp $@;
    $self->doError(5,"$@") if $@;
}

sub disable_rdf {
    my ($self) = @_;
    $self->{rdf_enabled} = 0;
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
    my ($self, $path, $dirname, $level, $rdf_data_P, $rdf_P) = @_;

    # rdf metadata
    my $rdf_data = 0;       # RDF/N3 meta-data found or not
    my $doc_prefix = 'doc'; # default prefix
    my $rdf;                # rdf object
    my $stop = 0;           # end of recursion controlled by meta-data

    if ($self->{rdf_enabled}) {

	if (-f $self->{n3_index}) {
	    require RDF::Notation3::PrefTriples;
	    $rdf = new RDF::Notation3::PrefTriples;
	    eval {$rdf->parse_file($self->{n3_index})};
	    if ($@) {
		$self->doError(6,"[RDF/N3 error ($dirname)] $@");
		return -1;
	    } else {
		$rdf_data = 1;
	    }
	}
	# parent N3 is read for uppermost directories only
	if (not $rdf_data_P) {
	    my $p_n3 = File::Spec::Functions::canonpath("../$self->{n3_index}");
	    if (-f $p_n3) {
		require RDF::Notation3::PrefTriples;
		$rdf_P = new RDF::Notation3::PrefTriples;
		eval {$rdf_P->parse_file($p_n3)};
		if ($@) {
		    $self->doError(6,"[RDF/N3 error ($dirname/..)] $@");
		    return -1;
		} else {
		    $rdf_data_P = 1;
		}
	    }
	}
    }

    my @stat = stat '.';
    $dirname =~ s/&/&amp;/;

    my @attr = ([name => $dirname]);
    push @attr, ['depth', $level] if $self->{details} > 1;
    push @attr, ['uid', $stat[4]] if $self->{details} > 2;
    push @attr, ['gid', $stat[5]] if $self->{details} > 2;

    # rdf metadata NS
    if ($rdf_data) {
	foreach (keys %{$rdf->{ns}->{$rdf->{context}}}) {
	    if ($rdf->{ns}->{$rdf->{context}}->{$_} eq 
		'http://gingerall.org/charlie-doc/1.0/') {
		$doc_prefix = $_;
	    }
	    push @attr, 
	      ["xmlns:$_" => $rdf->{ns}->{$rdf->{context}}->{$_}];
	} 
    }

    $self->doStartElement('directory', \@attr);

    $self->doElement('path', undef, $path) if $self->{details} > 1;

    my $atime = localtime($stat[8]);
    my $mtime = localtime($stat[9]);
    $self->doElement('access-time', [[epoch => $stat[8]]], $atime) 
      if $self->{details} > 2;
    $self->doElement('modify-time', [[epoch => $stat[9]]], $mtime) 
      if $self->{details} > 1;

    # rdf metadata for nested or uppermost dirs dirs
    if ($self->{details} > 1) {
	if ($rdf_data_P) {
	    my $position_set = 0;
	    my $cnt = scalar @{$rdf_P->{triples}};
	    for (my $i = 0; $i < $cnt; $i++) {
		if ($rdf_P->{triples}->[$i]->[0] eq "<$dirname>") {
		    $self->doElement("$doc_prefix:Position",undef,$i+1,1);
		    $position_set = 1;
		    last;
		}
	    }
	    $self->doElement("$doc_prefix:Position",undef,$cnt+1,1)
	      unless $position_set;
	    my $triples = $rdf_P->get_triples("<$dirname>");
	    foreach (@$triples) {
		$_->[2] =~ s/^"(.*)"$/$1/;
		$self->doElement($_->[1],undef,_esc($_->[2]),1);

		# looking for doc:Type = 'document'
		$_->[1] =~ s/^([_a-zA-Z]\w*)*:/$rdf_P->{ns}->{'<>'}->{$1}/;
		$stop = 1
		  if $_->[1] eq 'http://gingerall.org/charlie-doc/1.0/Type' 
		    and $_->[2] eq 'document';
	    }
	}
    }

    # nested dirs
    if ($self->{depth} > $level) {
	$level++;
	foreach my $d (grep -d, <*>) {
	    my $path = File::Spec::Functions::catfile($path, $d);

	    unless ($stop) {
		chdir $d or croak "Cannot chdir to $d, $!\n";
		$self->_directory($path, $d, $level, $rdf_data, $rdf);
		chdir '..'; 
	    }
	}
	$level--;
    }

    # final dirs
    if ($self->{depth} == $level) {
	foreach my $d (grep -d, <*>) {
	    my $path = File::Spec::Functions::catfile($path, $d);
	    my @stat = stat "$d";

	    $d =~ s/&/&amp;/;

	    my @attr = ([name => $d]);
	    push @attr, ['depth', $level] if $self->{details} > 1;
	    push @attr, ['uid', $stat[4]] if $self->{details} > 2;
	    push @attr, ['gid', $stat[5]] if $self->{details} > 2;

	    if ($self->{details} == 1) {
		$self->doElement('directory', \@attr, undef)
	    } else {
		$self->doStartElement('directory', \@attr);

		$self->doElement('path', undef, $path);
		my $atime = localtime($stat[8]);
		my $mtime = localtime($stat[9]);
		$self->doElement('access-time', [[epoch => $stat[8]]], $atime) 
		  if $self->{details} > 2;
		$self->doElement('modify-time', [[epoch => $stat[9]]], $mtime);

		# rdf metadata
		if ($rdf_data) {
		    my $position_set = 0;
		    my $cnt = scalar @{$rdf->{triples}};
		    for (my $i = 0; $i < $cnt; $i++) {
			if ($rdf->{triples}->[$i]->[0] eq "<$d>") {
			    $self->doElement("$doc_prefix:Position",undef,$i+1,1);
			    $position_set = 1;
			    last;
			}
		    }
		    $self->doElement("$doc_prefix:Position",undef,$cnt+1,1)
		      unless $position_set;
		    my $triples = $rdf->get_triples("<$d>");
		    foreach (@$triples) {
			$_->[2] =~ s/^"(.*)"$/$1/;
			$self->doElement($_->[1],undef,_esc($_->[2]),1);
		    }
		}
		$self->doEndElement('directory');
	    }
	}
    }

    # files
    unless ($stop) {
	foreach (grep -f, <*>) {
	    unless ($_ eq $self->{n3_index}) {
		$self->_file($_, $level, $rdf_data, $rdf, $doc_prefix);
	    }
	}
    }

    $self->doEndElement('directory');
}

sub _file($$$$) {
    my ($self, $name, $level, $rdf_data, $rdf, $doc_prefix) = @_;

    my @stat = stat $name;

    my @attr = ();
    push @attr, [name => _esc($name)];
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

	# rdf metadata
	if ($rdf_data) {
	    my $position_set = 0;
	    my $cnt = scalar @{$rdf->{triples}};
	    for (my $i = 0; $i < $cnt; $i++) {
		if ($rdf->{triples}->[$i]->[0] eq "<$name>") {
		    $self->doElement("$doc_prefix:Position",undef,$i+1,1);
		    $position_set = 1;
		    last;
		}
	    }
	    $self->doElement("$doc_prefix:Position",undef,$cnt+2,1)
	      unless $position_set;
	    my $triples = $rdf->get_triples("<$name>");
	    foreach (@$triples) {
		$_->[2] =~ s/^"(.*)"$/$1/;
		$self->doElement($_->[1],undef,_esc($_->[2]),1);
	    }
	}

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

sub _esc {
    my $str = shift;

    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    return $str;
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
