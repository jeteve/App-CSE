package App::CSE::File::TextXTex;

use Moose;
extends qw/App::CSE::File::TextPlain/;

sub effective_object{
  my ($self) = @_;
  return $self;
}

__PACKAGE__->meta->make_immutable();
