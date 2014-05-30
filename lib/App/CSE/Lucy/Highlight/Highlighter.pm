package App::CSE::Lucy::Highlight::Highlighter;

use base qw/Lucy::Highlight::Highlighter/;

use strict;
use warnings;
use Carp;
use Class::InsideOut qw( public register id );

public cse_command => my %cse_command;

=head2 encode

Overrides the Lucy encode method to avoid any HTMLI-zation.

=cut

use Term::ANSIColor;

sub new{
  my ($class, %options) = @_;
  my $cse_command = delete $options{'cse_command'} // confess("Missing cse_command");
  my $self = $class->SUPER::new(%options);
  register($self);
  $self->cse_command($cse_command);
  return $self;
}

sub encode{
  my ($self, $text) = @_;
  return $text;
}

sub highlight{
  my ($self, $text) = @_;
  return colored($text , 'red bold');
}

1;
