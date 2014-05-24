package App::CSE::File::TextPlain;

use Moose;
extends qw/App::CSE::File/;

use App::CSE::File::ApplicationXRuby;
use App::CSE::File::ApplicationXPerl;

sub effective_object{
  my ($self) = @_;
  if( $self->file_path() =~ /\.pod$/ ){
    return $self->requalify('application/x-perl');
  }
  elsif( $self->file_path() =~ /\.rbw$/ ){
    return $self->requalify('application/x-ruby');
  }elsif( $self->file_path() =~ /\.tt$/ &&
          $self->content() =~ /\[%.+%\]/ ){
    return $self->requalify('application/x-templatetoolkit');
  }
  return $self;
}

__PACKAGE__->meta->make_immutable();
