package App::CSE::Command::Index;

use Moose;
extends qw/App::CSE::Command/;

use File::Find;
use File::MimeInfo::Magic;
use File::Slurp;

use Path::Class::Dir;
use Lucy::Plan::Schema;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

has 'dir_index' => ( is => 'ro' , isa => 'Path::Class::Dir' , lazy_build => 1 );

sub _build_dir_index{
  my ($self) = @_;
  my $dir_index = Path::Class::Dir->new($self->cse->args()->[0] || '')->absolute();
  return $dir_index;
}

sub execute{
  my ($self) = @_;

  my $index_dir = $self->cse()->index_dir();

  my $schema = Lucy::Plan::Schema->new();
  my $sstring_type = Lucy::Plan::StringType->new( sortable => 1 );

  my $case_folder = Lucy::Analysis::CaseFolder->new();
  my $tokenizer = Lucy::Analysis::StandardTokenizer->new();

  my $ft_anal = Lucy::Analysis::PolyAnalyzer->new(analyzers => [ $case_folder, $tokenizer ]);
  my $ft_type = Lucy::Plan::FullTextType->new(analyzer => $ft_anal,
                                              highlightable => 1
                                             );


  $schema->spec_field( name => 'path' , type => $sstring_type );
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
      $LOGGER->info("File $file_name is hidden. Skipping");
      $File::Find::prune = 1;
      return;
    }

    my $mime_type = 'application/octet-stream';
    my $content;

    unless( -r $file_name ){
      $LOGGER->warn("Cannot read $file_name. Skipping");
      return;
    }

    if( -d $file_name ){
      $mime_type = 'inode/directory';
    }else{
      $mime_type = File::MimeInfo::Magic::mimetype($file_name);
      ## Slurp the content. Assume utf8 as we are being modern.
      $content = File::Slurp::read_file($file_name, binmode => ':utf8');
    }

    $LOGGER->info("Indexing $file_name as $mime_type");
    $indexer->add_doc({
                       path => $file_name,
                       mime => $mime_type,
                       $content ? ( content => $content ) : ()
                      });
  };
  my $dir_index = $self->dir_index();

  File::Find::find({ wanted => $wanted,
                     no_chdir => 1,
                     follow => 0,
                   }, $dir_index );

  $indexer->commit();
  return 0;
}

__PACKAGE__->meta->make_immutable();

=head1 NAME

App::CSE::Command::Index - Indexes a directory

=cut
