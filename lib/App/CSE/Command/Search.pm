package App::CSE::Command::Search;

use Moose;
extends qw/App::CSE::Command/;

use App::CSE::Command::Check;
use App::CSE::Command::Index;
use App::CSE::Lucy::Highlight::Highlighter;
use App::CSE::Lucy::Search::QueryPrefix;
use DateTime;
use File::Find;
use File::MimeInfo::Magic;
use Log::Log4perl;
use Lucy::Search::Hits;
use Lucy::Search::IndexSearcher;
use Lucy::Search::QueryParser;
use Lucy::Search::SortSpec;
use Lucy::Search::SortRule;
use Path::Class::Dir;
use Term::ANSIColor; # For colored

my $LOGGER = Log::Log4perl->get_logger();

# Parameter stuff

# Inputs
has 'query_str' => ( is => 'ro' , isa => 'Str' , lazy_build => 1);
has 'num' => ( is => 'ro' , isa => 'Int', lazy_build => 1);
has 'offset' => ( is => 'ro' , isa => 'Int' , lazy_build => 1);
has 'sort_str' => ( is => 'ro' , isa => 'Str' , lazy_build => 1);

# Calculated
has 'query' => ( is => 'ro', isa => 'Lucy::Search::Query' , lazy_build => 1);
has 'sort_spec' => ( is => 'ro' , isa => 'Lucy::Search::SortSpec', lazy_build => 1);

# Operational stuff.
has 'hits' => ( is => 'ro', isa => 'Lucy::Search::Hits', lazy_build => 1);
has 'searcher' => ( is => 'ro' , isa => 'Lucy::Search::IndexSearcher' , lazy_build => 1);
has 'highlighter' => ( is => 'ro' , isa => 'App::CSE::Lucy::Highlight::Highlighter' , lazy_build => 1);

sub _build_sort_spec{
  my ($self) = @_;

  my @rules = ( Lucy::Search::SortRule->new( type => 'score'),
                Lucy::Search::SortRule->new( field => 'path' )
              );
  if( $self->sort_str() eq 'score' ){
    # Nothing to do.
    1;
  }elsif( $self->sort_str() eq 'path' ){
    @rules = (
              Lucy::Search::SortRule->new( field => 'path' ),
              Lucy::Search::SortRule->new( type => 'score'),
             );
  }elsif( $self->sort_str() eq 'mtime' ){
    @rules = (
              Lucy::Search::SortRule->new( field => 'mtime' , reverse => 'true' ),
              Lucy::Search::SortRule->new( field => 'path' ),
             );
  }else{
    $LOGGER->error(colored("Unknown sort mode ".$self->sort_str().". Falling back to 'score'", 'red bold'));
  }

  return Lucy::Search::SortSpec->new(rules => \@rules );
}


sub _build_highlighter{
  my ($self) = @_;
  return App::CSE::Lucy::Highlight::Highlighter->new(
                                                     searcher => $self->searcher(),
                                                     query    => $self->highlight_query(),
                                                     field    => 'content',
                                                     excerpt_length => 100,
                                                    );
}

=head2 highlight_query

The query used to highlight the content. Will be the original
query or the highlight query of the query prefix.

=cut

sub highlight_query{
  my ($self) = @_;
  my $query = $self->query();
  if( $query->isa('App::CSE::Lucy::Search::QueryPrefix') ){
    return $query->highlight_query();
  }
  return $query;
}

sub _build_searcher{
  my ($self) = @_;
  my $searcher = Lucy::Search::IndexSearcher->new( index => $self->cse->index_dir().'' );
  return $searcher;
}

sub options_specs{
  return [ 'offset|o=i', 'num|n=i', 'sort|s=s' , 'reverse|r' ];
}

my %legit_sort = ( 'score' => 1,  'path' => 1 , 'mtime' => 1 );

sub _build_sort_str{
  my ($self) = @_;
  my $sort_str =  $self->cse()->options()->{sort} || 'score';
  unless( $legit_sort{$sort_str} ){
    $LOGGER->error(colored("Unknown sort mode ".$sort_str.". Falling back to 'score'", 'red bold'));
    return 'score';
  }

  my $perl_version = $];
  if( $perl_version >= 5.016 && $sort_str ne 'score' ){
    $LOGGER->warn(colored("A bug in Lucy doesn't allow this version of Perl($perl_version) to take sort mode (".$sort_str.") into account for now.", 'yellow bold'));
    return 'score'
  }


  return $sort_str;
}

sub _build_offset{
  my ($self) = @_;
  return $self->cse()->options->{offset} || 0;
}

sub _build_num{
  my ($self) = @_;
  my $num = $self->cse->options()->{num};
  return defined($num) ? $num : 5;
}

sub _build_hits{
  my ($self) = @_;

  $LOGGER->info("Searching for '".$self->query()->to_string()."'");

  my $perl_version = $];

  my $hits = $self->searcher->hits( query => $self->query(),
                                    offset => $self->offset(),
                                    num_wanted => $self->num(),
                                    ## This segfaults on perl 16 and 18 :(
                                    ( $perl_version < 5.016 ) ? ( sort_spec => $self->sort_spec() ) : ()
                                  );
  return $hits;
}

sub _build_query_str{
  my ($self) = @_;
  return  shift @{$self->cse->args()} || '';
}

sub _build_query{
  my ($self) = @_;

  if( $self->query_str() =~ /\*$/ ){
    return App::CSE::Lucy::Search::QueryPrefix->new(
                                                    field        => 'content',
                                                    query_string => $self->query_str(),
                                                   );
  }

  my $qp = Lucy::Search::QueryParser->new( schema => $self->searcher->get_schema,
                                           default_boolop => 'AND',
                                           fields => [ 'content' , 'path' ] );
  $qp->set_heed_colons(1);

  return $qp->parse($self->query_str());
}

sub execute{
  my ($self) = @_;

  unless( $self->query_str() ){
    $LOGGER->warn(colored("Missing query. Do cse help" , 'red'));
    return 1;
  }

  # Check the index.
  my $check = App::CSE::Command::Check->new({ cse => $self->cse() });
  if( $check->execute() ){
    $LOGGER->info(colored("Rebuilding the index..", 'green bold'));
    my $index_cmd = App::CSE::Command::Index->new( { cse => $self->cse() });
    if( $index_cmd->execute() ){
      $LOGGER->error(colored("Building index failed", 'red'));
      return 1;
    }
  }

  my $hits = $self->hits();
  my $highlighter = $self->highlighter();

  $LOGGER->info(colored('Hits: '. $self->offset().' - '.( $self->offset() + $self->num() - 1).' of '.$hits->total_hits().' sorted by '.$self->sort_str(), 'green bold')."\n\n");

  while ( my $hit = $hits->next ) {

    my $excerpt = $highlighter->create_excerpt($hit);

    my $star = '';
    if( my $stat = File::stat::stat( $hit->{path} ) ){
      if( $hit->{mtime} lt DateTime->from_epoch(epoch => $stat->mtime())->iso8601() ){
        $star = colored('*' , 'red bold');
      }
    }

    $LOGGER->trace("Score: ".$hit->get_score());

    my $hit_str = colored($hit->{path}.'', 'magenta bold').' ('.$hit->{mime}.') ['.$hit->{mtime}.$star.']'.colored(':', 'cyan bold').q|
|.( $excerpt || substr($hit->{content} || '' , 0 , 100 ) ).q|

|;

    $LOGGER->info($hit_str);
  }

  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Index - Indexes a directory

=cut
