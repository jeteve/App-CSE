package App::CSE::File;

use Moose;
use File::Slurp;

has 'mime_type' => ( is => 'ro', isa => 'Str', required => 1);
has 'file_path' => ( is => 'ro', isa => 'Str', required => 1);

has 'content' => ( is => 'ro' , isa => 'Maybe[Str]', required => 1, lazy_build => 1 );

sub _build_content{
  my ($self) = @_;
  return File::Slurp::read_file($self->file_path(), binmode => ':utf8');
}

sub effective_object{
  my ($self) = @_;
  return $self;
}

__PACKAGE__->meta->make_immutable();

__END__

=head1 NAME

App::CSE::File - A general file

=head1 METHODS

=head2 effective_object

Effective Object. Some classes can choose to return something different.

=cut
