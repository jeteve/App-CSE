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

sub effective_mime_type{
  my ($self) = @_;
  return $self->mime_type();
}

__PACKAGE__->meta->make_immutable();

__END__

=head1 NAME

App::CSE::File - A general file

=head1 METHODS

=head2 effective_mime_type

Effective MIME Type of this file. Can differ from MIME_TYPE

=cut
