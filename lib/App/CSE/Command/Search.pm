package App::CSE::Command::Search;

use Moose;
extends qw/App::CSE::Command/;

use File::Find;
use File::MimeInfo::Magic;

use Path::Class::Dir;
use App::CSE::Lucy::Highlight::Highlighter;
use Lucy::Search::IndexSearcher;
use Lucy::Search::Hits;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

has 'query' => ( is => 'ro', isa => 'Str' , lazy_build => 1);

has 'hits' => ( is => 'ro', isa => 'Lucy::Search::Hits', lazy_build => 1);
has 'searcher' => ( is => 'ro' , isa => 'Lucy::Search::IndexSearcher' , lazy_build => 1);
has 'highlighter' => ( is => 'ro' , isa => 'App::CSE::Lucy::Highlight::Highlighter' , lazy_build => 1);

sub _build_highlighter{
  my ($self) = @_;
  return App::CSE::Lucy::Highlight::Highlighter->new(
                                    searcher => $self->searcher(),
                                    query    => $self->query(),
                                    field    => 'content'
                                   );
}

sub _build_searcher{
  my ($self) = @_;
  my $searcher = Lucy::Search::IndexSearcher->new( index => $self->cse->index_dir().'' );
  return $searcher;
}

sub _build_hits{
  my ($self) = @_;
  my $hits = $self->searcher->hits( query => $self->query() );
  return $hits;
}

sub _build_query{
  my ($self) = @_;
  my $query =  $self->cse->args->[0] || '';
  return $query;
}

sub execute{
  my ($self) = @_;

  unless( $self->query() ){
    $LOGGER->warn("Missing query. Do cse help");
    return 1;
  }

  my $hits = $self->hits();
  my $highlighter = $self->highlighter();

  $LOGGER->info("Total hits: ".$hits->total_hits());

  while ( my $hit = $hits->next ) {

    my $excerpt = $highlighter->create_excerpt($hit);

    my $hit_str = $hit->{path}.q| :
|.$excerpt.q|
|;

    $LOGGER->info($hit_str);
  }

  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Index - Indexes a directory

=cut
