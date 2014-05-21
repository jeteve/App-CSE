package App::CSE::File::InodeDirectory;

use Moose;
extends qw/App::CSE::File/;

sub _build_content{
  return undef;
}

__PACKAGE__->meta->make_immutable();
