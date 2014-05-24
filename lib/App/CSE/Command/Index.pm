package App::CSE::Command::Index;

use Moose;
extends qw/App::CSE::Command/;

use App::CSE::File;

use File::Basename;
use File::Find;
use File::Path;
use File::MimeInfo::Magic;

use Path::Class::Dir;
use Lucy::Plan::Schema;

use String::CamelCase;
use Term::ANSIColor;


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

  if( my $to_index = $self->cse->args()->[0] ){
    return Path::Class::Dir->new($self->cse->args()->[0])->absolute();
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
  my $tokenizer = Lucy::Analysis::StandardTokenizer->new();

  # Full text analyzer.
  my $ft_anal = Lucy::Analysis::PolyAnalyzer->new(analyzers => [ $case_folder, $tokenizer ]);

  # Full text types.
  my $ft_nohl = Lucy::Plan::FullTextType->new(analyzer => $ft_anal, sortable => 1);
  my $ft_type = Lucy::Plan::FullTextType->new(analyzer => $ft_anal, highlightable => 1 );

  # String type
  my $sstring_type = Lucy::Plan::StringType->new( sortable => 1 );


  $schema->spec_field( name => 'path' , type => $ft_nohl );
  $schema->spec_field( name => 'dir'  , type => $sstring_type );
  $schema->spec_field( name => 'mtime' , type => $sstring_type );
  $schema->spec_field( name => 'mime' , type => $sstring_type );
  $schema->spec_field( name => 'content' , type => $ft_type );


  ## Ok Schema has been built
  $LOGGER->info("Building index ".$index_dir);
  my $indexer = Lucy::Index::Indexer->new(schema => $schema,
                                          index => $index_dir,
                                          create => 1,
                                         );

  $LOGGER->info("Indexing files from ".$self->dir_index());


  my $wanted = sub{
    my $file_name = $File::Find::name;

    if( $file_name =~ /\/\.[^\/]+$/ ){
      $LOGGER->trace("File $file_name is hidden. Skipping");
      $File::Find::prune = 1;
      return;
    }

    unless( -r $file_name ){
      $LOGGER->warn("Cannot read $file_name. Skipping");
      return;
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
                                 file_path => $file_name.'' })->effective_object();


    $LOGGER->debug("Indexing ".$file->file_path().' as '.$file->mime_type());

    my $content = $file->content();
    $indexer->add_doc({
                       path => $file->file_path(),
                       dir => $file->dir(),
                       mime => $file->mime_type(),
                       mtime => $file->mtime->iso8601(),
                       $content ? ( content => $content ) : ()
                      });
  };
  my $dir_index = $self->dir_index();

  File::Find::find({ wanted => $wanted,
                     no_chdir => 1,
                     follow => 0,
                   }, $dir_index );

  $indexer->commit();

  rmtree $self->cse->index_dir()->stringify();
  rename $index_dir , $self->cse->index_dir()->stringify();

  $LOGGER->info(colored("Index is ".$self->cse()->index_dir()->stringify(), 'green bold'));

  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Index - Indexes a directory

=cut
