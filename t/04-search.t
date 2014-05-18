#! perl -T
use Test::More;

use App::CSE;


use File::Temp;
use Path::Class::Dir;

my $idx_dir = File::Temp->newdir( CLEANUP => 1 );
my $content_dir = Path::Class::Dir->new('t/toindex');


{
  ## Indexing the content dir
  local @ARGV = ( 'index' , '--idx='.$idx_dir , $content_dir.'' );
  my $cse = App::CSE->new();
  is( $cse->main() , 0 ,  "Ok can execute the magic command just fine");
}

{
  ## Searching the content dir for hello.
  local @ARGV = (  '--idx='.$idx_dir, 'hello');
  my $cse = App::CSE->new();
  ok( $cse->command()->isa('App::CSE::Command::Search') , "Ok got search");
  is( $cse->command()->query() , 'hello' , "Ok got good query");
  ok( $cse->command()->hits() , "Ok got hits");
  is( $cse->command()->execute(), 0 , "Ok execute has terminated just fine");
}

ok(1);
done_testing();
