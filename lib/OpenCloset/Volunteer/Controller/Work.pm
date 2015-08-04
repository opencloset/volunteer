package OpenCloset::Volunteer::Controller::Work;
use Mojo::Base 'Mojolicious::Controller';

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 add

    GET /works/new

=cut

sub add {
    my $self = shift;
}

=head2 create

    POST /works

=cut

sub create {
    my $self = shift;
}

1;
