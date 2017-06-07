package OpenCloset::Volunteer::Controller::Volunteer;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 summary

    GET /summary?email=:email

=cut

sub summary {
    my $self = shift;
    my $v    = $self->validation;

    $v->required('email')->email;
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $email = $self->param('email');
    my $volunteer = $self->schema->resultset('Volunteer')->find( { email => $email } );

    return $self->error( 404, "Not found volunteer: $email" ) unless $volunteer;
    my $works = $volunteer->volunteer_works;

    my %group;
    while ( my $work = $works->next ) {
        my $status = $work->status;
        my $from   = $work->activity_from_date;
        my $to     = $work->activity_to_date;

        my $activity = $to->hour - $from->hour;
        $group{$status}{count}++;
        $group{$status}{activity} += $activity;
        push @{ $group{$status}{date} ||= [] }, $to->ymd;
    }

    $self->render( volunteer => $volunteer, group => \%group );
}

=head2 update

    POST /volunteer/:id

=cut

sub update {
    my $self = shift;
    my $id   = $self->param('id');

    my $volunteer = $self->schema->resultset('Volunteer')->find( { id => $id } );
    return $self->error( 404, "Not found volunteer: $id" ) unless $volunteer;

    my $v = $self->validation;
    $v->optional('comment');

    my $comment = $v->param('comment');
    $volunteer->update( { comment => $comment } ) if $comment;

    my $redirect = $self->url_for('/summary')->query( email => $volunteer->email );
    $self->redirect_to($redirect);
}

1;
