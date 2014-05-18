package App::CSE::Command::Check;

use Moose;
extends qw/App::CSE::Command/;

use Lucy::Search::IndexSearcher;

use Term::ANSIColor;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

sub execute{
  my ($self) = @_;

  my $index_dir = $self->cse()->index_dir();

  unless( -d  $index_dir ){
    $LOGGER->warn("No index $index_dir. You should run 'cse index'");
    return 1;
  }

  # The directory is there. Check it is a valid lucy index.
  my $lucy = eval{ my $l = Lucy::Search::IndexSearcher->new( index => $index_dir );
                   $l->get_reader();
                   $l;
                 };
  unless( $lucy ){
    my $err = $@;
    $LOGGER->error(colored("The index $index_dir is not a valid lucy index. Run cse check --verbose", 'red bold'));
    $LOGGER->debug("Lucy error: $err");
    return 1;
  }

  $LOGGER->info("Index $index_dir is healthy.");
  $LOGGER->info($lucy->get_reader()->doc_count().' files indexed.');
  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Help - Help about the cse utility

=cut
