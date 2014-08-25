package App::CSE::Role::DirIndex;

use Moose::Role;
# Factorizing dir_index command property.
#

requires 'cse';

use Path::Class::Dir;

has 'dir_index' => ( is => 'ro' , isa => 'Path::Class::Dir' , lazy_build => 1 );


sub _build_dir_index{
  my ($self) = @_;

  if( my $to_index = $self->cse->options()->{dir} ){
    return Path::Class::Dir->new($to_index);
  }

  ## Default to the current directory
  return Path::Class::Dir->new();
}

1;

