package App::CSE::File::TextTroff;

use Moose;
extends qw/App::CSE::File/;

use App::CSE::File::ApplicationXPerl;

sub effective_object{
  my ($self) = @_;

  # This could have been wrongly detected as text/troff when
  # it is effectively application/x-perl
  if( $self->content() =~ /^(?:.*?)perl(?:.*?)\n/ ){
    return App::CSE::File::ApplicationXPerl->new({ cse => $self->cse(), mime_type => 'application/x-perl' , file_path => $self->file_path(),
                                                   content => $self->content()
                                                 });
  }
  return $self;
}


__PACKAGE__->meta->make_immutable();
