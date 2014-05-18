package App::CSE::Command::Help;

use Moose;
extends qw/App::CSE::Command/;

use Pod::Text;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

sub execute{
  my ($self) = @_;

  my $output;
  my $p2txt = Pod::Text->new();
  $p2txt->output_string(\$output);
  $p2txt->parse_file(__FILE__);
  $LOGGER->info($output);
  return 1;
}

__PACKAGE__->meta->make_immutable();

=head1 SYNOPSIS

  cse <command> [ .. options .. ] [ command arguments ]

  cse Something

  cse search Something

  cse check

=head1 COMMANDS

=head2 search

Searches the index for matches. Requires a query string. The name of the command is optional

Examples:

## Searching for the word 'Something'

   cse Something

## Searching for the word 'search'

   cse search 'search'

=head2 help

Output this message. This is the default command when nothing is specified.

=head2 check

Checks the health status of the index. Also output various useful things.

=head2 index

Rebuild the index from the current directory.


=head1 COMMON OPTIONS

=over

=item --idx

Specifies the index. Default to 'current directory'/.cse.idx

=item --verbose

Be more verbose.

=back

=cut
