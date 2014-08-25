package App::CSE::Command::Watch;

use Moose;
extends qw/App::CSE::Command/;
with qw/App::CSE::Role::DirIndex/;


use App::CSE::Command::Check;
use App::CSE::Command::Index;
use App::CSE::File;

use File::MimeInfo::Magic;

use Filesys::Notify::Simple;

use Lucy::Search::IndexSearcher;
use Lucy::Index::Indexer;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();


sub execute{
  my ($self) = @_;

  my $colorizer = $self->cse()->colorizer();
  my $colored = sub{ $colorizer->colored(@_);};

  my $cse = $self->cse();

  # Check the index.
  # Re-index if nothing is there.
  my $check = App::CSE::Command::Check->new({ cse => $cse });
  if( $check->execute() ){
    $LOGGER->info(&$colored("Rebuilding the index..", 'green bold'));
    my $index_cmd = App::CSE::Command::Index->new( { cse => $cse });
    if( $index_cmd->execute() ){
      $LOGGER->error(&$colored("Building index failed", 'red'));
      return 1;
    }
  }

  if( my $previous_pid = $cse->index_meta()->{'watcher.pid'} ){
    # A previous pid should be a number.
    ( $previous_pid ) = ( $previous_pid =~ /(\d+)/ );
    if( kill(0, $previous_pid ) ){
      $LOGGER->error(&$colored("Previous watcher (PID=".$previous_pid.") is still running. Try cse unwatch first",
                               "red bold"));
      return 1;
    }
  }





  my $direct_child = fork();
  confess("Cannot fork() a direct child: $!") unless defined $direct_child;

  if( $direct_child ){
    waitpid($direct_child , 0 );
    return 0;
  }

  my $pid = fork();
  confess("Cannot fork() a worker child: $!") unless defined $pid;

  if( $pid ){
    $cse->index_meta()->{'watcher.pid'} = $pid;
    $cse->index_meta()->{'watcher.started'} = DateTime->now()->iso8601();
    $cse->save_index_meta();
    $LOGGER->info(&$colored("PID=$pid :  Watching for changes in ".$self->dir_index().", updating ".$cse->index_dir(), "green bold"));
    exit(0);
  }

  my $deamon_log = q|log4perl.rootLogger                = INFO, SYSLOG
log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
log4perl.appender.SYSLOG.min_level = debug
log4perl.appender.SYSLOG.ident     = cse V|.$cse->version().q|[|.$$.q|]
log4perl.appender.SYSLOG.facility  = daemon
log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
|;

  Log::Log4perl::init(\$deamon_log);

  $LOGGER->info("Watching for changes in ".$self->dir_index().", updating ".$cse->index_dir());


  my $lock = 0;
  my $should_exit = 0;

  $SIG{TERM} = $SIG{INT} = sub{
    $LOGGER->info("Caught INT or TERM signal. Will exit");
    unless( $lock ){
      exit(0);
    }else{
      $should_exit = 1;
    }
  };




  my $watcher = Filesys::Notify::Simple->new([ $self->dir_index()->absolute()->stringify() ]);
  $watcher->wait(sub {
                   my @events = @_;

                   # Lock exiting before we do anything meaty
                   $lock = 1;




                   eval{

                     # Build an indexer just for this event.
                     my $searcher = Lucy::Search::IndexSearcher->new( index => $cse->index_dir().'' );
                     my $indexer =  Lucy::Index::Indexer->new( schema => $searcher->get_schema(),
                                                               index => $cse->index_dir().'' );



                     foreach my $event ( @events ) {

                       my $file_name = $event->{path};
                       # file_path here is absolute.
                       # $self->dir_index() can be relative
                       if( $self->dir_index()->is_relative() ){
                         # We should remove the absolute prefix from the file path
                         my $abs_prefix = $self->dir_index->absolute()->stringify();
                         $file_name =~ s/^$abs_prefix/\./ ;
                       }
                       $LOGGER->info("File ".$file_name." has changed");

                       # Delete it whatever happened. If it is gone, it
                       # will simply not be valid anymore.
                       $indexer->delete_by_term( field => 'path.raw',
                                                 term => $file_name );

                       # Unreadable files are invalid. This will help
                       # not adding deleted files.
                       unless( $cse->is_file_valid( $file_name ) ){
                         next;
                       }

                       $LOGGER->info("File ".$file_name." is a valid file");


                       my $mime_type = $cse->valid_mime_type($file_name);
                       unless( $mime_type ){
                         next;
                       }

                       my $file_class = App::CSE::File->class_for_mime($mime_type, $file_name.'');
                       unless( $file_class ){
                         next;
                       }

                       ## Build a file instance.
                       my $file = $file_class->new({cse => $cse,
                                                    mime_type => $mime_type,
                                                    file_path => $file_name.'' })->effective_object();

                       my $content = $file->content();

                       $indexer->add_doc({
                                          path => $file->file_path(),
                                          'path.raw' => $file->file_path(),
                                          dir => $file->dir(),
                                          mime => $file->mime_type(),
                                          mtime => $file->mtime->iso8601(),
                                          $content ? ( content => $content ) : ()
                                         });

                     } # End of event loop

                     $indexer->commit();
                     $indexer = undef;
                     $searcher = undef;
                   };
                   if( my $err = $@ ){
                     $LOGGER->error("ERROR reacting to event: $err");
                   }

                   # Unlock exiting
                   $lock = 0;
                   if( $should_exit ){
                     exit(0);
                   }

                 });

  my $n = 10;
  while($n){
    sleep(5)
  }

  exit(0);

  # Now is the time to watch for changes.

  # # Right time to reindex dirty files.
  # my @dirty_files = sort keys %{$self->cse->dirty_files()};
  # unless( @dirty_files ){
  #   $LOGGER->info(&$colored("No dirty files", 'green bold'));
  #   return 0;
  # }

  # # Build an indexer.
  # my $searcher = Lucy::Search::IndexSearcher->new( index => $self->cse()->index_dir().'' );
  # my $indexer =  Lucy::Index::Indexer->new( schema => $searcher->get_schema(),
  #                                           index => $self->cse()->index_dir().'' );

  # my $NFILES = 0;
  # foreach my $dirty_file ( @dirty_files ){
  #   $indexer->delete_by_term( field => 'path.raw',
  #                             term => $dirty_file );
  #   my $mime_type = File::MimeInfo::Magic::mimetype($dirty_file.'') || 'application/octet-stream';
  #   my $file_class = App::CSE::File->class_for_mime($mime_type, $dirty_file.'');
  #   unless( $file_class ){
  #     next;
  #   }

  #   ## Build a file instance.
  #   my $file = $file_class->new({cse => $self->cse(),
  #                                mime_type => $mime_type,
  #                                file_path => $dirty_file.'' })->effective_object();

  #   $LOGGER->info("Reindexing file $dirty_file as ".$file->mime_type());
  #   # And index it
  #   my $content = $file->content();
  #   $indexer->add_doc({
  #                      path => $file->file_path(),
  #                      'path.raw' => $file->file_path(),
  #                      dir => $file->dir(),
  #                      mime => $file->mime_type(),
  #                      mtime => $file->mtime->iso8601(),
  #                      $content ? ( content => $content ) : ()
  #                     });
  #   # Remove from the dirty files hash
  #   delete $self->cse()->dirty_files()->{$dirty_file};
  #   $NFILES++;
  # }

  # # Commit and save that.
  # $indexer->commit();
  # $self->cse()->save_dirty_files();
  # $LOGGER->info(&$colored('Re-indexed '.$NFILES.' files' ,'green bold'));
  # return 0;
}

__PACKAGE__->meta->make_immutable();
