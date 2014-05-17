use strict;
use warnings;
package App::CSE;

use Moose;
use Class::Load;
use String::CamelCase;

use Path::Class::Dir;

use Getopt::Long qw//;

use Log::Log4perl qw/:easy/;


has 'command_name' => ( is => 'ro', isa => 'Str', required => 1 , lazy_build => 1);
has 'command' => ( is => 'ro', isa => 'App::CSE::Command', lazy_build => 1);

# GetOpt::Long options specs.
has 'options_specs' => ( is => 'ro' , isa => 'ArrayRef[Str]', lazy_build => 1);

# The options as slurped by getopts long
has 'options' => ( is => 'ro' , isa => 'HashRef[Str]', lazy_build => 1);

# The arguments after any option
has 'args' => ( is => 'ro' , isa => 'ArrayRef[Str]', lazy_build => 1);


has 'index_dir' => ( is => 'ro' , isa => 'Path::Class::Dir', lazy_build => 1);


sub _build_index_dir{
  my ($self) = @_;

  if( my $opt_idx = $self->options->{idx} ){
    return Path::Class::Dir->new($opt_idx);
  }

  return Path::Class::Dir->new('.cse.idx');
}

sub _build_command_name{
  my ($self) = @_;
  my $command_name = shift @ARGV;
  unless( $command_name ){ return 'help'; }
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

  my $p = Getopt::Long::Parser->new;
  # Beware that accessing options_specs will consume the command as the first ARGV
  $p->getoptionsfromarray(\@ARGV, \%options , 'idx=s', 'verbose', @{$self->options_specs()} );
  return \%options;
}

sub _build_args{
  my ($self) = @_;
  $self->options();
  my @args = @ARGV;
  return \@args;
}


=head2 main

Does stuff using the command and returns an exit code.

=cut

sub main{
  my ($self) = @_;


  unless( Log::Log4perl->initialized() ){
    Log::Log4perl->easy_init($self->options()->{verbose} ? $DEBUG : $INFO);
  }

  return $self->command()->execute();
}

__PACKAGE__->meta->make_immutable();
