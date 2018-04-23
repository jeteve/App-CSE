package App::CSE::File::TextXScala;

use Moose;

extends qw/App::CSE::File/;

sub _build_decl{
    my ($self) = @_;
    ( my @declarations ) = ( $self->content() =~ m/\s(?:class|trait|object|def|val|var)\s+(\w+)/gm );
    return \@declarations;
}

__PACKAGE__->meta->make_immutable();
