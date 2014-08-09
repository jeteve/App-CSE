package App::CSE::Command::Index;

use Moose;
extends qw/App::CSE::Command/;

use App::CSE::File;

use File::Basename;
use File::Find;
use File::Path;
use File::stat;
use File::MimeInfo::Magic;

use Path::Class::Dir;
use Lucy::Plan::Schema;

use String::CamelCase;
use Term::ProgressBar;
use Time::HiRes;

## Note that using File::Slurp is done at the CSE level,
## avoiding undefined warnings,

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

my $BLACK_LIST = {
                  'application/x-trash' => 1
                 };


has 'dir_index' => ( is => 'ro' , isa => 'Path::Class::Dir' , lazy_build => 1 );


sub _build_dir_index{
  my ($self) = @_;

  if( my $to_index = $self->cse->options()->{dir} ){
    return Path::Class::Dir->new($to_index);
  }

  ## Default to the current directory
  return Path::Class::Dir->new();
}

sub execute{
  my ($self) = @_;

  ## We will index as a new dir.
  my $index_dir = $self->cse()->index_dir().'-new';


  my $schema = Lucy::Plan::Schema->new();


  my $case_folder = Lucy::Analysis::CaseFolder->new();
  my $tokenizer = Lucy::Analysis::RegexTokenizer->new( pattern => '\w+' ); # ;Lucy::Analysis::StandardTokenizer->new();

  # Full text analyzer.
  my $ft_anal = Lucy::Analysis::PolyAnalyzer->new(analyzers => [ $case_folder, $tokenizer ]);
  my $decl_anal = Lucy::Analysis::PolyAnalyzer
    ->new(
          analyzers => [ $case_folder, Lucy::Analysis::RegexTokenizer->new( pattern => '\S+' ) ]
         );

  # Full text types.
  my $path_type = Lucy::Plan::FullTextType->new(analyzer => $ft_anal, sortable => 1, boost => 2.0);
  my $body_type = Lucy::Plan::FullTextType->new(analyzer => $ft_anal, highlightable => 1 , boost => 1.0);
  my $declare_type = Lucy::Plan::FullTextType->new( analyzer => $decl_anal, highlightable => 1 , boost => 4.0 );


  # String type
  my $plain_sortable_string = Lucy::Plan::StringType->new( sortable => 1 );

  # Plain string type
  my $plain_string = Lucy::Plan::StringType->new();


  $schema->spec_field( name => 'content' , type => $body_type );
  $schema->spec_field( name => 'decl' , type => $declare_type );
  $schema->spec_field( name => 'dir'  , type => $plain_sortable_string );
  $schema->spec_field( name => 'mtime' , type => $plain_sortable_string);
  $schema->spec_field( name => 'mime' , type => $plain_sortable_string );
  $schema->spec_field( name => 'path' , type => $path_type );
  $schema->spec_field( name => 'path.raw' , type => $plain_string );


  ## Ok Schema has been built
  $LOGGER->info("Building index ".$index_dir);
  my $indexer = Lucy::Index::Indexer->new(schema => $schema,
                                          index => $index_dir,
                                          create => 1,
                                         );

  $LOGGER->info("Indexing files from ".$self->dir_index());

  my $dir_index = $self->dir_index();

  ## Wrapper to build File::find wanter subs
  my $wanted_wrapper = sub{
    my ($wrapped) = @_;

    return sub{
      my $file_name = $File::Find::name;
      unless( -r $file_name ){
        $LOGGER->trace("Cannot read $file_name. Skipping");
        return;
      }

      my $stat = File::stat::stat($file_name.'');
      if( $file_name =~ /\/\.[^\/]+$/ ){
        $LOGGER->trace("File $file_name is hidden. Skipping");
        $File::Find::prune = 1;
        return;
      }
      &$wrapped($file_name, $stat);
    };
  };



  $LOGGER->info("Estimating size. Please wait");
  my $ESTIMATED_SIZE = 0;
  File::Find::find({ wanted => &$wanted_wrapper(sub{
                                                  my ($file_name, $stat) = @_;
                                                  unless( -d $file_name ){
                                                    $ESTIMATED_SIZE += $stat->size();
                                                  }
                                                }),
                     no_chdir => 1,
                     follow => 0,
                   }, $dir_index );

  my $PROGRESS_BAR =  Term::ProgressBar->new({name  => 'Indexing',
                                              count => $ESTIMATED_SIZE,
                                              ETA   => 'linear',
                                              silent => ! $self->cse()->interactive(),
                                             });

  my $START_TIME = Time::HiRes::time();
  my $NUM_INDEXED = 0;
  my $SIZE_LOOKEDAT = 0;
  my $TOTAL_SIZE = 0;

  my $wanted = sub{
    my ($file_name, $stat) = @_;


    unless( -d $file_name.'' ){
      $SIZE_LOOKEDAT += $stat->size();
      $PROGRESS_BAR->update($SIZE_LOOKEDAT);
    }

    my $mime_type = File::MimeInfo::Magic::mimetype($file_name.'') || 'application/octet-stream';

    if( $BLACK_LIST->{$mime_type} ){
      return;
    }

    my $file_class = App::CSE::File->class_for_mime($mime_type, $file_name.'');
    unless( $file_class ){
      return;
    }

    ## Build a file instance.
    my $file = $file_class->new({cse => $self->cse(),
                                 mime_type => $mime_type,
                                 stat => $stat,
                                 file_path => $file_name.'' })->effective_object();


    $LOGGER->debug("Indexing ".$file->file_path().' as '.$file->mime_type());

    my $content = $file->content();
    $indexer->add_doc({
                       path => $file->file_path(),
                       'path.raw' => $file->file_path(),
                       decl => join(' ', @{$file->decl()}),
                       dir => $file->dir(),
                       mime => $file->mime_type(),
                       mtime => $file->mtime->iso8601(),
                       $content ? ( content => $content ) : ()
                      });
    $NUM_INDEXED++;
    $TOTAL_SIZE+= $file->stat->size();
  };

  File::Find::find({ wanted => &$wanted_wrapper($wanted),
                     no_chdir => 1,
                     follow => 0,
                   }, $dir_index );

  $indexer->commit();
  $PROGRESS_BAR->update($ESTIMATED_SIZE);


  rmtree $self->cse->index_dir()->stringify();
  rename $index_dir , $self->cse->index_dir()->stringify();

  my $END_TIME = Time::HiRes::time();

  $LOGGER->info($self->cse->colorizer->colored("Index is ".$self->cse()->index_dir()->stringify(), 'green bold'));
  $LOGGER->info("$NUM_INDEXED files ($TOTAL_SIZE Bytes) indexed in ".sprintf('%.03f', ( $END_TIME - $START_TIME )).' seconds');

  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Index - Indexes a directory

=cut
