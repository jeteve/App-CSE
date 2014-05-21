package App::CSE::File;

use Moose;

has 'mime_type' => ( is => 'ro', isa => 'Str', required => 1);

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
