package App::CSE::File;

use Moose;
use File::Slurp;
use File::stat qw//;
use DateTime;

has 'cse' => ( is => 'ro' , isa => 'App::CSE' , required => 1 );

has 'mime_type' => ( is => 'ro', isa => 'Str', required => 1);
has 'file_path' => ( is => 'ro', isa => 'Str', required => 1);

has 'content' => ( is => 'ro' , isa => 'Maybe[Str]', required => 1, lazy_build => 1 );

has 'stat' => ( is => 'ro' , isa => 'File::stat' , lazy_build => 1 );
has 'mtime' => ( is => 'ro' , isa => 'DateTime' , lazy_build => 1);

sub _build_stat{
  my ($self) = @_;
  return File::stat::stat($self->file_path());
}

sub _build_mtime{
  my ($self) = @_;
  return DateTime->from_epoch( epoch => $self->stat->mtime() );
}


sub _build_content{
  my ($self) = @_;
  if( $self->stat()->size() > $self->cse()->max_size() ){
    return undef;
  }
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
