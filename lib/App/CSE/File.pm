package App::CSE::File;

use Moose;
use Encode;
use File::Slurp;
use File::stat qw//;
use DateTime;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

has 'cse' => ( is => 'ro' , isa => 'App::CSE' , required => 1 );

has 'mime_type' => ( is => 'ro', isa => 'Str', required => 1);
has 'file_path' => ( is => 'ro', isa => 'Str', required => 1);
has 'encoding' => ( is => 'ro' , isa => 'Str', default => 'UTF-8');

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
  my $raw_content =  File::Slurp::read_file($self->file_path(), binmode => ':raw');
  my $decoded = eval{ Encode::decode($self->encoding(), $raw_content, Encode::FB_CROAK ); };
  unless( $decoded ){
    $LOGGER->warn("File ".$self->file_path()." failed to be decoded as ".$self->encoding().": ".$@);
    return;
  }
  return $decoded;
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
