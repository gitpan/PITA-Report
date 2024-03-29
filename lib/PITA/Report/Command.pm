package PITA::Report::Command;

=pod

=head1 NAME

PITA::Report::Command - An executed command, with stored output 

=head1 SYNOPSIS

  # Create a command
  my $dist = PITA::Report::Request->new(
  	cmd    => 'perl Makefile.PL',
  	stdout => \"...",
  	stderr => \"...",
  	);

=head1 DESCRIPTION

C<PITA::Report::Command> is an object for holding information about
a command executed during the installation process.

It holds the actual command, and the STDOUT and STDERR output.

=head1 METHODS

=cut

use strict;
use Carp         ();
use Params::Util '_SCALAR0';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.07';
}





#####################################################################
# Constructors and Accessors

=pod

=head2 new

The C<new> constructor is used to create a new ::Command object.

It takes a set of key/value names params.

=over

=item cmd

The C<cmd> param should contains the command that was executed,
as it was sent to the operating system, as as a plain string.

=item stdout

The C<stdout> param should be the resulting output to C<STDOUT>,
provided as a reference to a C<SCALAR> string.

=item stderr

The C<stderr> param should be the resulting output to C<STDERR>,
provided as a reference to a C<SCALAR> string.

=back

Returns a new L<PITA::Report::Command> object, or dies on error.

=cut

sub new {
	my $class = shift;

	# Create the object
	my $self = bless { @_ }, $class;

	# Check the object
	$self->_init;

	$self;
}

sub _init {
	my $self = shift;

	# Check the actual command string
	my $cmd = $self->{cmd};
	unless ( 
		defined $cmd and ! ref $cmd
		and
		length $cmd
	) {
		Carp::croak('Invalid or missing cmd');
	}

	# Check the STDOUT
	unless ( PITA::Report->_OUTPUT($self, 'stdout') ) {
		Carp::croak('Invalid or missing stdout');
	}

	# Check the STDERR
	unless ( PITA::Report->_OUTPUT($self, 'stderr') ) {
		Carp::croak('Invalid or missing stderr');
	}

	$self;
}

=pod

=head2 cmd

The C<cmd> accessor returns the actual command sent to the system.

=cut

sub cmd {
	$_[0]->{cmd};
}

=pod

=head2 stdout

The C<stdout> accessor returns the output of the command as a
C<SCALAR> reference.

=cut

sub stdout {
	$_[0]->{stdout};
}

=pod

=head2 stderr

The C<stderr> accessor returns the output of the command as a
C<SCALAR> reference.

=cut

sub stderr {
	$_[0]->{stderr};
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

L<PITA::Report>

The Perl Image-based Testing Architecture (L<http://ali.as/pita/>)

=head1 COPYRIGHT

Copyright 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
