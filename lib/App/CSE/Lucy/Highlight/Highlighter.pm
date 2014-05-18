package App::CSE::Lucy::Highlight::Highlighter;
use base 'Lucy::Highlight::Highlighter';

use strict;
use warnings;

=head2 encode

Overrides the Lucy encode method to avoid any HTMLI-zation.

=cut

sub encode{
  my ($self, $text) = @_;
  return $text;
}

1;
