use strict;
use warnings;
package App::CSE;

use Moose;
use Class::Load;
use String::CamelCase;

use Path::Class::Dir;

use Getopt::Long qw//;

has 'command_name' => ( is => 'ro', isa => 'Str', required => 1 , lazy_build => 1);
has 'command' => ( is => 'ro', isa => 'App::CSE::Command', lazy_build => 1);

# GetOpt::Long options specs.
has 'options_specs' => ( is => 'ro' , isa => 'ArrayRef[Str]', lazy_build => 1);

# The options as slurped by getopts long
has 'options' => ( is => 'ro' , isa => 'HashRef[Str]', lazy_build => 1);

has 'index_dir' => ( is => 'ro' , isa => 'Path::Class', lazy_build => 1);


sub _build_index_dir{
  my ($self) = @_;

  my $opt_idx = $self->options->{idx};
  if( $opt_idx ){
    return Path::Class::Dir->new($opt_idx);
  }

  return Path::Class::Dir->new();
}

sub _build_command_name{
  my ($self) = @_;
  my $command_name = shift @ARGV;
  unless( $command_name ){ die "Missing command name\n"; }
  return $command_name;
}

sub _build_command{
  my ($self) = @_;
  my $command_class = Class::Load::load_class(__PACKAGE__.'::Command::'.String::CamelCase::camelize($self->command_name()));
  my $command = $command_class->new({ cse => $self });
  return $command;
}

sub _build_options_specs{
  my ($self) = @_;
  return $self->command()->options_specs();
}

sub _build_options{
  my ($self) = @_;
  my %options = ();
  Getopt::Long::GetOptions(\%options, 'idx=s', @{$self->options_specs} );
  return \%options;
}


sub main{
  my ($self) = @_;
  $self->command()->execute();
}

__PACKAGE__->meta->make_immutable();
