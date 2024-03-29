package PITA::Report::SAXParser;

=pod

=head1 NAME

PITA::Report::SAXParser - Implements a SAX Parser for PITA::Report files

=head1 DESCRIPTION

Although you won't need to use it directly, this class provides a
"SAX Parser" class that converts a stream of SAX events (most likely from
an XML file) and populates a L<PITA::Report> with L<PITA::Report::Install>
objects.

Please note that this class is incomplete at this time. Although you
can create objects and parse some of the tags, many are still ignored
at this time (in particular the E<lt>outputE<gt> and E<lt>analysisE<gt>
tags.

=head1 METHODS

In addition to the following documented methods, this class implements
a large number of methods relating to its implementation of a
L<XML::SAX::Base> subclass. These are not considered part of the
public API, and so are not documented here.

=cut

use strict;
use base 'XML::SAX::Base';
use Carp ();
use Params::Util '_INSTANCE';

use vars qw{$VERSION $XML_NAMESPACE @PROPERTIES %TRIM};
BEGIN {
	$VERSION = '0.07';

	# Define the XML namespace we are a parser for
	$XML_NAMESPACE = 'http://ali.as/xml/schemas/PITA/1.0';

	# The name/tags for the simple properties
	@PROPERTIES = qw{
		scheme  distname   filename
		md5sum  authority  authpath
		cmd     bin        system
		exitcode
	};

	# Set up the char strings to trim
	%TRIM = map { $_ => 1 } @PROPERTIES;

	# Create the property handlers
	foreach my $name ( @PROPERTIES ) { eval <<"END_PERL" }

	# Start capturing chars
	sub start_element_${name} {
		\$_[0]->{chars} = '';
		1;
	}

	# Save those chars to the element
	sub end_element_${name} {
		my \$self = shift;

		# Add the $name to the context
		\$self->_context->{$name} = delete \$self->{chars};

		1;
	}
END_PERL
}





#####################################################################
# Constructor

=pod

=head2 new

  # Create the SAX parser
  my $parser = PITA::Report::SAXParser->new( $report );

The C<new> constructor takes a single L<PITA::Report> object and creates
a SAX Parser for it. When used, the SAX Parser object will fill the empty
L<PITA::Report> object with L<PITA::Report::Install> reporting objects.

If used with a L<PITA::Report> that already has existing content, it
will add the new install reports in addition to the existing ones.

Returns a new C<PITA::Report::SAXParser> object, or dies on error.

=cut

sub new {
	my $class  = shift;
	my $report = _INSTANCE(shift, 'PITA::Report')
		or Carp::croak("Did not provie a PITA::Report param");

	# Create the basic parsing object
	my $self = bless {
		report  => $report,
		context => [],
		}, $class;

	$self;
}

# Add to the context
sub _push {
	push @{shift->{context}}, @_;
	return 1;
}

# Remove from the context
sub _pop {
	my $self = shift;
	unless ( @{$self->{context}} ) {
		die "Ran out of context";
	}
	return pop @{$self->{context}};
}

# Get the current context
sub _context {
	shift->{context}->[-1];
}

# Convert full Attribute data into a simple hash
sub _hash {
	my $self  = shift;
	my $attrs = shift;

	# Shrink it
	my %hash  = map { $_->{LocalName}, $_->{Value} }
		grep {
			$_->{Value} =~ s/^\s+//;
			$_->{Value} =~ s/\s+$//;
			1;
		}
		grep { ! $_->{Prefix} }
		values %$attrs;

	return \%hash;
}



#####################################################################
# Simplification Layer

sub start_element {
	my ($self, $element) = @_;

	# We don't support namespaces.
	if ( $element->{Prefix} ) {
		Carp::croak( __PACKAGE__
		. ' does not support XML namespaces (yet)' );
	}

	# Shortcut if we don't implement a handler
	my $handler = 'start_element_' . $element->{LocalName};
	return 1 unless $self->can($handler);

	# Hand off to the handler
	my $hash = $self->_hash($element->{Attributes});
	return $self->$handler( $hash );
}

sub end_element {
	my ($self, $element) = @_;

	# Hand off to the optional tag-specific handler
	my $handler = 'end_element_' . $element->{LocalName};
	if ( $self->can($handler) ) {
		# If there is anything in the character buffer, trim whitespace
		if ( exists $self->{chars} and defined $self->{chars} ) {
			if ( $TRIM{$element->{LocalName}} ) {
				$self->{chars} =~ s/^\s+//;
				$self->{chars} =~ s/\s+$//;
			}
		}
		$self->$handler();
	}

	return 1;
}

# Because we don't know in what context this will be called,
# we just store all character data in a character buffer
# and deal with it in the various end_element methods.
sub characters {
	my ($self, $element) = @_;

	# Add to the buffer (if not null)
	if ( exists $self->{chars} and defined $self->{chars} ) {
		$self->{chars} .= $element->{Data};
	}

	1;
}





#####################################################################
# Simplified Tag-Specific Event Handlers
# The simplified event handlers are passed arguments in the forms
# start_element_foo( $self, \%attribute_hash )
# end_element_foo  ( $self )

# Ignore the actual report tag
sub start_element_report { 1 }
sub   end_element_report { 1 }





#####################################################################
# Handle the <install>...</install> tag

sub start_element_install {
	$_[0]->_push( bless { commands => [], tests => [] }, 'PITA::Report::Install' );
}

sub end_element_install {
	my $self = shift;

	# Complete the install and add to the report
	$self->{report}->add_install( $self->_pop->_init );

	1;
}





#####################################################################
# Handle the <request>...</request> tag

sub start_element_request {
	$_[0]->_push( bless {}, 'PITA::Report::Request' );
}

sub end_element_request {
	my $self = shift;

	# Complete the Request and add to the Install
	$self->_context->{request} = $self->_pop->_init;

	1;
}





#####################################################################
# Handle the <platform>...</platform> tag

sub start_element_platform {
	$_[0]->_push( bless { env => {}, config => {}, }, 'PITA::Report::Platform' );
}

sub end_element_platform {
	my $self = shift;

	# Complete the Platform and add to the Install
	$self->_context->{platform} = $self->_pop->_init;

	1;
}





#####################################################################
# Handle the <command>...</command> tag

sub start_element_command {
	$_[0]->_push( bless {}, 'PITA::Report::Command' );
}

sub end_element_command {
	my $self = shift;

	# Complete the Command and add to the Install
	my $command = $self->_pop->_init;
	push @{ $self->_context->{commands} }, $command;

	1;
}





#####################################################################
# Handle the <test>...</test> tag

sub start_element_test {
	my ($self, $hash) = @_;

	# Create the test object
	my $test = bless {
		language => $hash->{language},
		}, 'PITA::Report::Test';
	if ( $hash->{name} ) {
		$test->{name} = $hash->{name};
	}

	$_[0]->_push( $test );
}

sub end_element_test {
	my $self = shift;

	# Complete the Command and add to the Install
	my $test = $self->_pop->_init;
	push @{ $self->_context->{tests} }, $test;

	1;
}





#####################################################################
# Handle the <stdout>...</stdout> tag

# Start capturing the STDOUT content
sub start_element_stdout {
	$_[0]->{chars} = '';
	1;
}

# Save those chars to the element by reference, not plain strings
sub end_element_stdout {
	my $self = shift;

	# Add the $name to the context
	my $stdout = delete $self->{chars};
	$self->_context->{stdout} = \$stdout;

	1;
}





#####################################################################
# Handle the <stderr>...</stderr> tag

# Start capturing the STDERR content
sub start_element_stderr {
	$_[0]->{chars} = '';
	1;
}

# Save those chars to the element by reference, not plain strings
sub end_element_stderr {
	my $self = shift;

	# Add the $name to the context
	my $stderr = delete $self->{chars};
	$self->_context->{stderr} = \$stderr;

	1;
}





#####################################################################
# Handle the <env>...</env> tag

# Start capturing the $ENV{key} content
sub start_element_env {
	my ($self, $hash) = @_;
	$self->{chars} = '';
	$self->_push( $hash->{name} );
}

# Save those chars to the element by reference, not plain strings
sub end_element_env {
	my $self = shift;

	# Add the vey/value pair to the env propery
	my $name  = $self->_pop;
	my $value = delete $self->{chars};
	$self->_context->{env}->{$name} = $value;

	1;
}





#####################################################################
# Handle the <config>...</config> tag

# Start capturing the %Config::Config content
sub start_element_config {
	my ($self, $hash) = @_;
	$self->{chars} = '';
	$self->_push( $hash->{name} );
}

# Save those chars to the element by reference, not plain strings
sub end_element_config {
	my $self = shift;

	# Add the vey/value pair to the config propery
	my $name  = $self->_pop;
	my $value = delete $self->{chars};
	$self->_context->{config}->{$name} = $value;

	1;
}





#####################################################################
# Handle <null/> tags in a variety of things

sub start_element_null {
	my ($self, $hash) = @_;

	# A null tag indicates that the currently-accumulating character
	# buffer should be set to undef.
	if ( exists $self->{chars} ) {
		$self->{chars} = undef;
	}

	1;
}

sub end_element_null {
	1;
}

1;

=pod

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PITA-Report>

For other issues, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>cpan@ali.asE<gt>, L<http://ali.as/>

=head1 SEE ALSO

L<PITA::Report>, L<PITA::Report::SAXDriver>

The Perl Image-based Testing Architecture (L<http://ali.as/pita/>)

=head1 COPYRIGHT

Copyright 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
