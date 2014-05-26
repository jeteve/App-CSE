package App::CSE::Command::Help;

use Moose;
extends qw/App::CSE::Command/;

use Pod::Text;
use Pod::Usage;

use Log::Log4perl;
my $LOGGER = Log::Log4perl->get_logger();

sub execute{
  my ($self) = @_;


  unless( $self->cse()->interactive() ){
    my $output;
    my $p2txt = Pod::Text->new();
    $p2txt->output_string(\$output);
    $p2txt->parse_file(__FILE__);
    $LOGGER->info($output);
  }else{
    Pod::Usage::pod2usage( -input => __FILE__ , -verbose => 2 );
  }
  return 1;
}

__PACKAGE__->meta->make_immutable();

=head1 SYNOPSIS

  cse <command> [ .. options .. ] [ command arguments ]

  # Search for 'Something'
  cse Something

  # Search for 'search'
  cse search search

  # Check the index.
  cse check

=head1 COMMANDS

=head2 search

Searches the index for matches. Requires a query string. The name of the command is optional if you
are searching for a term that doesnt match a command.

Optionally, you can give a directory to retrict the search to a specific directory.

Examples:

   ## Searching for the word 'Something'
   cse Something

   ## Searching for the word 'search'
   cse search search

   ## Searching for the word 'Something' only in the directory './lib'
   cse search Something ./lib

   ## Searching for any term starting with 'some':
   cse search some*

=head3 search syntax

In addition of searching for simple terms, cse supports "advanced" searches using Lucy/Lucene-like query syntax.

cse uses the L<Lucy> query syntax.

For a full description of the supported query syntax, look there:
URL<Lucy query syntax|https://metacpan.org/pod/distribution/Lucy/lib/Lucy/Search/QueryParser.pod>

Examples:

  # Searching 'hello' only in perl files:
  cse 'hello mime:application/x-perl'


  # Searching ruby in everything but ruby files:
  cse -- 'ruby -mime:application/x-ruby'

  # Note the '--' that protects the rest of the command line to be interpreted as -options.

=head3 search options

=over

=item --offset (-o)

Offset in the result space. Defaults to 0.

=item --num (-n)

Number of result on one page. Defaults to 5.

=back

=head2 help

Output this message. This is the default command when nothing is specified.

=head2 check

Checks the health status of the index. Also output various useful things.

=head2 index

Rebuild the index from the current directory.

=head3 index options

=over

=item --dir

Directory to index. Defaults to current directory.

=back

=head1 COMMON OPTIONS

=over

=item --idx

Specifies the index. Default to 'current directory'/.cse.idx

=item --verbose (-v)

Be more verbose.

=back

=head1 COPYRIGHT

Copyright 2014 Jerome Eteve.

This program is free software; you can redistribute it and/or modify it under the terms of the Artistic License v2.0.

See L<http://dev.perl.org/licenses/artistic.html>.

=cut
