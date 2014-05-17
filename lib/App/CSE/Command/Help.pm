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


=head1 COMMON OPTIONS

=over

=item --idx

Specifies the index. Default to 'current directory'/.cse.idx

=back

=cut
