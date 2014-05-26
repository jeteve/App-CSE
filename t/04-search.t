#! perl -T
use Test::More;

use App::CSE;


use File::Temp;
use Path::Class::Dir;

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
  local @ARGV = ( 'bonjour' );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok its a search command");
  is_deeply( $cse->args() , [ 'bonjour' ] );
}

{
  # Explicit search for bonjour
  local @ARGV = ( 'search' , 'bonjour' );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok its a search command");
  is_deeply( $cse->args() , [ 'bonjour' ] );
}

{
  # Explicit search for bonjour
  local @ARGV = ( 'bonjour' , '--idx=blabla' );
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok its a search command");
  is( $cse->options()->{idx} , 'blabla' );
  is_deeply( $cse->args() , [ 'bonjour' ] );
}

{
  ## Searching the content dir for bonjour.
  local @ARGV = (  '--idx='.$idx_dir, 'bonjour', '--dir='.$content_dir.'');
  my $cse = App::CSE->new();
  is( $cse->command()->execute(), 0 , "Ok execute has terminated just fine");
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok got search");
  is( $cse->command()->query->to_string() , '(content:bonjour OR path:bonjour)' , "Ok got good query");
  ok( $cse->command()->hits() , "Ok got hits");
  is( $cse->command()->hits()->total_hits() , 2 , "Ok got two hits");
  ok( $cse->index_mtime() , "Ok got index mtime");
}

{
  ## Searching the content_dir/text_files/ for bonjour. Shouldnt not find anything.
  local @ARGV = (  '--idx='.$idx_dir, 'bonjour', $content_dir.'/text_files');
  my $cse = App::CSE->new();
  is( $cse->command()->execute(), 0 , "Ok execute has terminated just fine");
  is( $cse->command()->hits()->total_hits() , 0 , "No hits there.");
}

{
  ## Searhing for bon*. Will find stuff with bonjour, bonnaventure and bonsoir
  local @ARGV = (  '--idx='.$idx_dir, 'bon*', '--dir='.$content_dir.'');
  my $cse = App::CSE->new();
  is( $cse->command()->execute(), 0 , "Ok execute has terminated just fine");
  is( $cse->command()->hits()->total_hits() , 3 , "Ok got 3 hits");
}



ok(1);
done_testing();
