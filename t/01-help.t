#! perl -T
use Test::More;

use App::CSE;

my $cse = App::CSE->new();

{
  local @ARGV = ( 'help' );
  ok( $cse->command()->isa('App::CSE::Command::Help') , "Ok good command instance");
  ok( $cse->main() , "Ok can execute the magic command");
}

ok(1);
done_testing();
