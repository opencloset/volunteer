package OpenCloset::Volunteer::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 auth

    under /

=cut

sub auth {
    my $self = shift;

    my $user_id = $self->session('access_token');
    unless ($user_id) {
        $self->error( 401, 'Permission Denied' );
        return;
    }

    my $user = $self->schema->resultset('User')->find( { id => $user_id } );
    my $user_info = $user->user_info;
    $self->stash( user => $user, user_info => $user_info );
    return 1;
}

1;
