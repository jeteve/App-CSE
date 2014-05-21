package App::CSE::File::TextPlain;

use Moose;
extends qw/App::CSE::File/;

use App::CSE::File::ApplicationXRuby;

sub effective_object{
  my ($self) = @_;
  if( $self->file_path() =~ /\.rbw/ ){
    return App::CSE::File::ApplicationXRuby->new({ mime_type => 'application/x-ruby', file_path => $self->file_path() });
  }
  return $self;
}

__PACKAGE__->meta->make_immutable();