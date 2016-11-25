package OpenCloset::Volunteer::Controller::Work;
use Mojo::Base 'Mojolicious::Controller';

use DateTime::Format::ISO8601;
use DateTime;
use Email::Simple;
use Encode qw/encode_utf8/;
use HTML::FillInForm::Lite;
use String::Random ();

has schema => sub { shift->app->schema };
has max_volunteers => sub { shift->config->{max_volunteers} || 4 };

=head1 METHODS

=head2 add

    GET /works/new

=cut

sub add {
    my $self = shift;

    my $now = DateTime->now;
    $self->render( holidays => [$self->holidays( $now->year )] );
}

=head2 create

    POST /works

=cut

sub create {
    my $self = shift;
    my $v    = $self->validation;
    $self->_validate_volunteer($v);
    $self->_validate_volunteer_work($v);
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $name           = $v->param('name');
    my $gender         = $v->param('gender');
    my $activity_date  = $v->param('activity-date');
    my $email_addr     = $v->param('email');
    my $birth_date     = $v->param('birth_date');
    my $phone          = $v->param('phone');
    my $address        = $v->param('address');
    my $activity_hours = $v->param('activity-hours');
    my $need_1365      = $v->param('need_1365');
    my $org_username   = $v->param('org_username');
    my $org_region     = $v->param('org_region');
    my $period         = $v->param('period');
    my $talent         = $v->param('talent');
    my $comment        = $v->param('comment');
    my $activity       = $v->param('activity');
    my $reasons        = $v->every_param('reason');
    my $paths          = $v->every_param('path');
    my $job            = $v->param('job');
    my ( $from, $to ) = split /-/, $activity_hours;

    my $able_hours = $self->_able_hour($activity_date);
    return $self->error( 400, "Not allow activity hours: $activity_hours" ) unless $able_hours->{$activity_hours};

    my $dt = DateTime::Format::ISO8601->parse_datetime($activity_date);
    ## now Sunday is working day.
    ## return $self->error( 400, "Not allow activity date: Sunday" ) if $dt->day_abbr =~ /Sun/;

    my $schema    = $self->schema;
    my $volunteer = $schema->resultset('Volunteer')->find_or_create(
        {
            name       => $name,
            gender     => $gender,
            email      => $email_addr,
            phone      => $phone,
            address    => $address,
            birth_date => $birth_date
        }
    );

    return $self->error( 500, 'Failed to find or create Volunteer' ) unless $volunteer;

    my $parser = $self->schema->storage->datetime_parser;
    my $rs     = $self->schema->resultset('VolunteerWork')->search(
        {
            volunteer_id       => $volunteer->id,
            activity_from_date => {
                -between => [$parser->format_datetime($dt), $parser->format_datetime( $dt->clone->add( days => 1 ) )]
            },
            status => 'reported',
        }
    );

    return $self->error( 400, '같은날 두번 이상 신청할 수 없습니다' ) if $rs->count;

    my $work = $schema->resultset('VolunteerWork')->create(
        {
            volunteer_id       => $volunteer->id,
            activity_from_date => "$activity_date $from:00:00",
            activity_to_date   => "$activity_date $to:00:00",
            need_1365          => $need_1365,
            org_username       => $org_username,
            org_region         => $org_region,
            period             => $period,
            reason             => join( '|', @$reasons ),
            path               => join( '|', @$paths ),
            job                => $job,
            activity           => $activity,
            talent             => $talent,
            comment            => $comment,
            authcode           => String::Random->new->randregex('[a-zA-Z0-9]{32}')
        }
    );

    return $self->error( 500, 'Failed to create Volunteer Work' ) unless $work;

    ## SMS
    my $sender = $self->app->sms_sender;
    my $msg = $self->render_to_string( 'sms/status-reported', format => 'txt', work => $work );
    chomp $msg;
    my $sent = $sender->send_sms( text => $msg, to => $phone );
    $self->log->error("Failed to send SMS: $msg, $phone") unless $sent;

    my $email = Email::Simple->create(
        header => [
            From => $self->config->{email_notify_from},
            To   => $self->config->{email_notify_to},
            Subject =>
                sprintf( "[열린옷장 봉사활동 신청접수] %s님이 봉사활동을 신청하셨습니다.",
                $name ),
        ],
        body => '--',
    );

    $self->send_mail( encode_utf8( $email->as_string ) );
    $self->render( 'work/done', work => $work );
}

=head2 find_work

    under /works/:id

=cut

sub find_work {
    my $self = shift;
    my $id   = $self->param('id');

    my $work = $self->schema->resultset('VolunteerWork')->find($id);
    unless ($work) {
        $self->error( 404, "Not found volunteer work: $id" );
        return;
    }

    $self->stash( work => $work );
    return 1;
}

=head2 work

    # work
    GET /works/:id

=cut

sub work {
    my $self = shift;
    my $work = $self->stash('work');

    my $volunteer = $work->volunteer;
    my $works     = $volunteer->volunteer_works( { id => { '!=' => $work->id } } );
    my $guestbook = $work->volunteer_guestbooks->next;

    $self->render( works => [$works->all], guestbook => $guestbook );
}

=head2 edit

    # work.edit
    GET /works/:id/edit

=cut

sub edit {
    my $self      = shift;
    my $authcode  = $self->param('authcode') || '';
    my $work      = $self->stash('work');
    my $volunteer = $work->volunteer;

    return $self->error( 400, 'Wrong authcode' ) if $authcode ne $work->authcode;

    my $now  = DateTime->now;
    my $from = $work->activity_from_date;
    my $to   = $work->activity_to_date;

    my %filled = ( $work->get_columns, $volunteer->get_columns );
    $filled{reason} = [split /\|/, $filled{reason}];
    $filled{path}   = [split /\|/, $filled{path}];
    $filled{'activity-date'}  = $from->ymd;
    $filled{'activity-hours'} = $from->hour . '-' . $to->hour;
    $filled{birth_date} = $volunteer->birth_date->ymd if $volunteer->birth_date;
    $self->stash( holidays => [$self->holidays( $now->year )] );

    my $html = $self->render_to_string( 'work/edit', format => 'html' );
    my $fill = HTML::FillInForm::Lite->new;
    $self->render( text => $fill->fill( \$html, \%filled ), format => 'html' );
}

=head2 update

    # work.update
    POST /works/:id

=cut

sub update {
    my $self      = shift;
    my $authcode  = $self->param('authcode') || '';
    my $work      = $self->stash('work');
    my $volunteer = $work->volunteer;

    return $self->error( 400, error => 'Wrong authcode' ) if $authcode ne $work->authcode;

    my $v = $self->validation;
    $self->_validate_volunteer_work($v);
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error( 400, 'Parameter Validation Failed: ' . join( ', ', @$failed ) );
    }

    my $activity_date  = $v->param('activity-date');
    my $activity_hours = $v->param('activity-hours');
    my $need_1365      = $v->param('need_1365');
    my $org_username   = $v->param('org_username');
    my $period         = $v->param('period');
    my $talent         = $v->param('talent');
    my $comment        = $v->param('comment');
    my $activity       = $v->param('activity');
    my $reasons        = $v->every_param('reason');
    my $paths          = $v->every_param('path');
    my $job            = $v->param('job');
    my ( $from, $to ) = split /-/, $activity_hours;

    $work->update(
        {
            activity_from_date => "$activity_date $from:00:00",
            activity_to_date   => "$activity_date $to:00:00",
            need_1365          => $need_1365,
            org_username       => $org_username,
            period             => $period,
            reason             => join( '|', @$reasons ),
            path               => join( '|', @$paths ),
            job                => $job,
            activity           => $activity,
            talent             => $talent,
            comment            => $comment,
        }
    );

    if ( $work->event_id ) {
        $self->delete_event( $work->event_id );
        my $from = $work->activity_from_date;
        my $to   = $work->activity_to_date;
        my $text = sprintf "%s %s on %s %s %s%s-%s%s", $volunteer->name, $work->activity, $from->month_name,
            $from->day, $from->hour_12, $from->am_or_pm, $to->hour_12, $to->am_or_pm;
        $self->log->debug($text);
        my $event_id = $self->quickAdd("$text");
        $work->update( { event_id => $event_id } );
    }

    $self->render( 'work/done', work => $work );
}

=head2 preflight_cors

    OPTIONS /works/:id/status

=over

=item https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS

=item http://www.html5rocks.com/en/tutorials/cors/

=back

=cut

sub preflight_cors {
    my $self = shift;

    my $origin = $self->req->headers->header('origin');
    my $method = $self->req->headers->header('access-control-request-method');

    return $self->error( 400, "Not Allowed Origin: $origin" ) unless $origin =~ m/theopencloset\.net/;

    $self->res->headers->header( 'Access-Control-Allow-Origin'  => $origin );
    $self->res->headers->header( 'Access-Control-Allow-Methods' => $method );
    $self->respond_to( any => { data => '', status => 200 } );
}

=head2 update_status

    PUT /works/:id/status?status=reported|approved|done|canceled

=cut

sub update_status {
    my $self      = shift;
    my $work      = $self->stash('work');
    my $volunteer = $work->volunteer;

    my $origin = $self->req->headers->header('origin');
    $self->res->headers->header( 'Access-Control-Allow-Origin' => $origin );

    my $validation = $self->validation;
    $validation->required('status')->in(qw/reported approved done canceled drop/);
    return $self->error( 400, 'Parameter Validation Failed' ) if $validation->has_error;

    my $status = $validation->param('status');
    $work->update( { status => $status } );

    my $sender = $self->app->sms_sender;
    if ( $status eq 'approved' ) {
        my $phone = $volunteer->phone;
        my $msg = $self->render_to_string( 'sms/status-approved', format => 'txt', work => $work );
        chomp $msg;
        my $sent = $sender->send_sms( text => $msg, to => $phone );
        $self->log->error("Failed to send SMS: $msg") unless $sent;

        $msg = $self->render_to_string( 'sms/opencloset-location', format => 'txt' );
        chomp $msg;
        $sent = $sender->send_sms( text => $msg, to => $phone );
        $self->log->error("Failed to send SMS: $phone, $msg") unless $sent;

        ## Google Calendar
        my $volunteer = $work->volunteer;
        my $from      = $work->activity_from_date;
        my $to        = $work->activity_to_date;
        my $text      = sprintf "%s %s on %s %s %s%s-%s%s", $volunteer->name, $work->activity, $from->month_name,
            $from->day, $from->hour_12, $from->am_or_pm, $to->hour_12, $to->am_or_pm;
        $self->log->debug($text);
        my $event_id = $self->quickAdd("$text");
        $work->update( { event_id => $event_id } );
    }
    elsif ( $status =~ /canceled|drop/ ) {
        my $event_id = $work->event_id;
        $self->delete_event($event_id) if $event_id;
    }

    $self->render( json => { $work->get_columns } );
}

=head2 update_1365

    PUT /works/:id/1365

=cut

sub update_1365 {
    my $self  = shift;
    my $work  = $self->stash('work');
    my $_1365 = $self->param('1365') || 0;

    my $origin = $self->req->headers->header('origin');
    $self->res->headers->header( 'Access-Control-Allow-Origin' => $origin );

    $work->update( { done_1365 => $_1365 } );
    $self->render( json => { $work->get_columns } );
}

=head2 add_guestbook

    GET /works/:id/guestbook?authcode=xxxx

=cut

sub add_guestbook {
    my $self     = shift;
    my $authcode = $self->param('authcode') || '';
    my $work     = $self->stash('work');

    return $self->error( 400, 'Wrong authcode' ) if $authcode ne $work->authcode;
    $self->render;
}

=head2 create_guestbook

    POST /works/:id/guestbook

=cut

sub create_guestbook {
    my $self     = shift;
    my $authcode = $self->param('authcode') || '';
    my $work     = $self->stash('work');

    return $self->error( 400, 'Wrong authcode' ) if $authcode ne $work->authcode;

    my $name       = $self->param('name');
    my $age_group  = $self->param('age-group');
    my $impression = $self->param('impression');
    my $imprss_etc = $self->param('impression-etc');
    my $activities = $self->every_param('activity');
    my $atvt_etc   = $self->param('activity-etc');
    my $want_to_do = $self->every_param('want-to-do');
    my $todo_etc   = $self->param('want-to-do-etc');
    my $comment    = $self->param('comment');

    my $guestbook = $self->schema->resultset('VolunteerGuestbook')->create(
        {
            volunteer_work_id => $work->id,
            name              => $name,
            age_group         => $age_group,
            impression        => $impression || $imprss_etc,
            activity          => join( '|', @$activities ) || $atvt_etc,
            want_to_do        => join( '|', @$want_to_do ) || $todo_etc,
            comment           => $comment,
        }
    );

    return $self->error( 500, 'Failed to create Volunteer Guestbook' ) unless $guestbook;

    my $email = Email::Simple->create(
        header => [
            From => $self->config->{email_notify_guestbook_from},
            To   => $self->config->{email_notify_guestbook_to},
            Subject =>
                sprintf( "[열린옷장 봉사활동 방명록] %s님의 방명록이 등록되었습니다.", $name ),
        ],
        body => $self->url_for( 'work', { id => $work->id } )->query( authcode => $authcode )->to_abs
    );

    $self->send_mail( encode_utf8( $email->as_string ) );
    $self->render( 'work/thanks', guestbook => $guestbook );
}

=head2 able_hour

    GET /works/hours/:ymd

=cut

sub able_hour {
    my $self = shift;
    my $ymd  = $self->param('ymd');
    $self->render( json => $self->_able_hour($ymd) );
}

sub _validate_volunteer {
    my ( $self, $v ) = @_;

    $v->required('name');
    $v->required('gender');
    $v->required('email');    # TODO: check valid email
    $v->required('birth_date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->required('phone')->like(qr/^\d{3}-\d{4}-\d{3,4}$/);
    $v->required('address');
}

sub _validate_volunteer_work {
    my ( $self, $v ) = @_;

    $v->required('activity-date')->like(qr/^\d{4}-\d{2}-\d{2}$/);
    $v->required('activity-hours')->like(qr/^\d{2}-\d{2}$/);
    $v->optional('need_1365');
    $v->optional('org_username');
    $v->optional('org_region');
    $v->required('reason');
    $v->required('path');
    $v->required('job');
    $v->required('period');
    $v->optional('talent');
    $v->optional('comment');
}

sub _able_hour {
    my ( $self, $ymd ) = @_;
    my ( $year, $mm, $dd ) = split /-/, $ymd;
    my $parser = $self->schema->storage->datetime_parser;
    my $dt     = DateTime->new( year => $year, month => $mm, day => $dd );
    my $rs     = $self->schema->resultset('VolunteerWork')->search(
        {
            activity_from_date => {
                -between => [$parser->format_datetime($dt), $parser->format_datetime( $dt->clone->add( days => 1 ) )]
            },
            status => { '!=' => 'canceled' }
        }
    );

    my %schedule;
    while ( my $row = $rs->next ) {
        my $from = $row->activity_from_date;
        my $to   = $row->activity_to_date;
        $schedule{$_}++ for ( $from->hour .. $to->hour );
    }

    my %result;
    my @templates = qw/10-11 10-12 10-13 14-18 10-16 10-17 10-18/;
    for my $template (@templates) {
        my $able = 1;
        my ( $start, $end ) = split /-/, $template;
        for my $hour ( $start .. $end ) {
            if ( $schedule{$hour} && $schedule{$hour} >= $self->max_volunteers ) {
                $able = 0;
                last;
            }
        }

        $result{$template} = $able;
    }

    return {%result};
}

1;
