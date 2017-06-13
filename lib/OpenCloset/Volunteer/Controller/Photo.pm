package OpenCloset::Volunteer::Controller::Photo;
use Mojo::Base 'Mojolicious::Controller';

use Path::Tiny;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 create

    POST /photos

=cut

sub create {
    my $self = shift;
    my $v    = $self->validation;
    $v->required('key');
    $v->required('photo')->upload->size( 1, 1024 * 1024 * 10 );    # 10MB

    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $key   = $v->param('key');
    my $photo = $v->param('photo');

    if ( $photo->size ) {
        my $temp = Path::Tiny->tempfile( UNLINK => 0 );
        $photo->move_to("$temp");
        $self->minion->enqueue( upload_photo => [$key, $temp] );
    }

    $self->render( json => {} );
}

1;
