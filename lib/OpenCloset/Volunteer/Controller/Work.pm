package OpenCloset::Volunteer::Controller::Work;
use Mojo::Base 'Mojolicious::Controller';

use String::Random ();

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
    my $v    = $self->validation;
    $self->_validate_volunteer($v);
    $self->_validate_volunteer_work($v);
    return $self->error( 400, 'Parameter Validation Failed' ) if $v->has_error;

    my $name          = $v->param('name');
    my $activity_date = $v->param('activity_date');
    my $email         = $v->param('email');
    my $birth_date    = $v->param('birth_date');
    my $phone         = $v->param('phone');
    my $address       = $v->param('address');
    my $from       = sprintf '%02s', $v->param('activity_hour_from') || '00';
    my $to         = sprintf '%02s', $v->param('activity_hour_to') || '00';
    my $period     = $v->param('period');
    my $comment    = $v->param('comment');
    my $reasons    = $v->every_param('reason');
    my $paths      = $v->every_param('path');
    my $activities = $v->every_param('activity');

    my $schema = $self->schema;

    my $volunteer = $schema->resultset('Volunteer')->find_or_create(
        {
            name       => $name,
            email      => $email,
            phone      => $phone,
            address    => $address,
            birth_date => $birth_date
        }
    );

    return $self->error( 500, 'Failed to find or create Volunteer' )
        unless $volunteer;

    my $work = $schema->resultset('VolunteerWork')->create(
        {
            volunteer_id       => $volunteer->id,
            activity_from_date => "$activity_date $from:00:00",
            activity_to_date   => "$activity_date $to:00:00",
            period             => $period,
            reason             => join( '|', @$reasons ),
            path               => join( '|', @$paths ),
            activity           => join( '|', @$activities ),
            comment            => $comment,
            authcode => String::Random->new->randregex('[a-zA-Z0-9]{32}')
        }
    );

    return $self->error( 500, 'Failed to create Volunteer Work' ) unless $work;

    ## SMS
    my $sender = $self->app->sms_sender;
    my $msg    = $self->render_to_string(
        'work/status-reported',
        format => 'txt',
        work   => $work
    );
    chomp $msg;
    my $sent = $sender->send_sms( text => $msg, to => $phone );
    $self->log->error("Failed to send SMS: $msg, $phone") unless $sent;
    $self->render( 'work/done', work => $work );
}

sub _validate_volunteer {
    my ( $self, $v ) = @_;

    $v->required('name');
    $v->optional('email');    # TODO: check valid email
    $v->optional('birth_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->required('phone')->like(qr/^\d{3}-\d{4}-\d{3,4}$/);
    $v->optional('address');
}

sub _validate_volunteer_work {
    my ( $self, $v ) = @_;

    $v->required('activity_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->optional('activity_hour_from')->like(qr/^\d{1,2}$/);
    $v->optional('activity_hour_to')->like(qr/^\d{1,2}$/);
    $v->optional('reason');
    $v->optional('path');
    $v->optional('period');
    $v->optional('activity');
    $v->optional('comment');
}

1;
