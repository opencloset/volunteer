package OpenCloset::Volunteer::Controller::Root;
use Mojo::Base 'Mojolicious::Controller';

use Path::Tiny;

=head1 METHODS

=head2 home

    # home
    GET /

=cut

sub home {
    my $self = shift;
}

=head2 closed

    under /works/new

=cut

sub closed {
    my $self = shift;

    if ( -f "closed" ) {
        my $message = path("closed")->slurp_utf8;
        $self->render(
            template => "root/closed",
            message  => $message,
        );
        return;
    }

    return 1;
}

1;
