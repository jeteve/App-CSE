#! perl -T
use Test::More;

use App::CSE;


use File::Temp;
use Path::Class::Dir;

use Log::Log4perl qw/:easy/;
# Log::Log4perl->easy_init($INFO);

use File::BaseDir qw//;
unless( File::BaseDir::data_files('mime/globs') ){
    plan skip_all => 'No mime-info database on the machine. The shared-mime-info package is available from http://freedesktop.org/';
}


my $idx_dir = File::Temp->newdir( CLEANUP => 1 );
my $content_dir = Path::Class::Dir->new('t/toindex');


# {
#   ## Indexing the content dir
#   local @ARGV = ( 'index' , '--idx='.$idx_dir , $content_dir.'' );
#   my $cse = App::CSE->new();
#   is( $cse->main() , 0 ,  "Ok can execute the magic command just fine");
# }

{
  ## Searching just for bonjour
  local @ARGV = ( 'bonjour' ,  '--idx='.$idx_dir  , '--dir='.$content_dir );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok its a search command");
  is_deeply( $cse->args() , [ 'bonjour' ] );
}

my $watcher_pid;

{
  # Watch for changes.
  local @ARGV = ( 'watch' , '--idx='.$idx_dir  , '--dir='.$content_dir );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Watch') , "Ok we have a watch command");
  is( $cse->command()->execute() , 0 , "Ok can execute that");
}


{
  ## Get the watcher_pid
  local @ARGV = ( 'check' , '--idx='.$idx_dir );

  my $cse = App::CSE->new();
  ok( $watcher_pid = $cse->index_meta->{'watcher.pid'} , "Ok got a watcher PID");
  ( $watcher_pid ) = ( $watcher_pid =~ /(\d+)/ );
}

{
  local @ARGV = ( 'unwatch' , '--idx='.$idx_dir );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Unwatch') , "Ok good command");
  is( $cse->command()->execute() , 0 , "Ok can execute that");
}

{
  local @ARGV = ( 'unwatch' , '--idx='.$idx_dir );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Unwatch') , "Ok good command");
  is( $cse->command()->execute() , 1 , "Ok executing that is a mistake");
}


{
  # Kill 9 the watcher pid, just in case.
  kill( 9 , $watcher_pid );
}


ok(1);
done_testing();
