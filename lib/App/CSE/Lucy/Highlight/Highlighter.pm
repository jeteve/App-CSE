package App::CSE::Lucy::Highlight::Highlighter;

use base qw/Lucy::Highlight::Highlighter/;

use strict;
use warnings;
use Carp;
# use Class::InsideOut qw( private register );

my %cse_command;
my %cse;

=head2 encode

Overrides the Lucy encode method to avoid any HTMLI-zation.

=cut

sub new{
  my ($class, %options) = @_;
  my $cse_command = delete $options{'cse_command'} || confess("Missing cse_command");
  my $self = $class->SUPER::new(%options);
  # register($self);
  $cse_command{ $self } = $cse_command;
  $cse{ $self } = $cse_command->cse();
  return $self;
}

sub encode{
  my ($self, $text) = @_;
  return $text;
}

sub highlight{
  my ($self, $text) = @_;

  my $cse = $cse{ $self };

  if( $cse->interactive() ){
    return $cse->colorizer->colored($text , 'red bold');
  }else{
    return '[>'.$text.'<]';
  }
}

sub DESTROY{
  my ($self) = @_;
  delete $cse_command{ $self };
  delete $cse{ $self };
  $self->SUPER::DESTROY();
}

1;
