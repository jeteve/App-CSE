#! perl -T
use Test::More;

use App::CSE;


use File::Temp;

{
  #local @ARGV = ( 'help' );

  my $dir = File::Temp->newdir( CLEANUP => 1 );

  local @ARGV = ( 'help' , '--idx='.$dir );

  my $cse = App::CSE->new();

  ok( $cse->index_dir() , "Ok index dir");
  is( $cse->index_dir()->absolute() , $dir.'' , "Ok good option taken into account");

  # ok( $cse->command()->isa('App::CSE::Command::Help') , "Ok good command instance");
  # ok( $cse->main() , "Ok can execute the magic command");
}

ok(1);
done_testing();
