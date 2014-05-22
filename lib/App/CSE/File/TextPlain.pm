package App::CSE::File::TextPlain;

use Moose;
extends qw/App::CSE::File/;

use App::CSE::File::ApplicationXRuby;
use App::CSE::File::ApplicationXPerl;

sub effective_object{
  my ($self) = @_;
  if( $self->file_path() =~ /\.pod$/ ){
    return App::CSE::File::ApplicationXPerl->new({ cse => $self->cse(), mime_type => 'application/x-perl', file_path => $self->file_path() });
  }
  elsif( $self->file_path() =~ /\.rbw$/ ){
    return App::CSE::File::ApplicationXRuby->new({ cse => $self->cse(), mime_type => 'application/x-ruby', file_path => $self->file_path() });
  }
  return $self;
}

__PACKAGE__->meta->make_immutable();
