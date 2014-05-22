package App::CSE::File::TextXTex;

use Moose;
extends qw/App::CSE::File/;

use App::CSE::File::ApplicationXWineExtensionIni;

sub effective_object{
  my ($self) = @_;
  if( $self->file_path() =~ /\.ini$/ ){
    return App::CSE::File::ApplicationXWineExtensionIni->new({ cse => $self->cse(), mime_type => 'application/x-wine-extension-ini', file_path => $self->file_path() });
  }
  return $self;
}

__PACKAGE__->meta->make_immutable();
