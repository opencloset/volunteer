package OpenCloset::Volunteer::Controller::Work;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime::Format::ISO8601;
use DateTime;
use Email::Simple;
use Encode qw/encode_utf8/;
use HTML::FillInForm::Lite;
use String::Random ();

has schema => sub { shift->app->schema };

=head1 METHODS

=head2 add

    GET /works/new

=cut

sub add {
    my $self = shift;

    my $now = DateTime->now( time_zone => $self->config->{timezone} );
    my $year = $now->year;

    my $user_id = $self->session('access_token');
    my $staff;
    if ($user_id) {
        my $user = $self->schema->resultset('User')->find( { id => $user_id } );
        my $user_info = $user->user_info;
        $staff = $user_info->staff;
    }

    $self->render( now => $now, holidays => [$self->holidays( $year, $year + 1 )], staff => $staff );
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

    my $name   = $v->param('name');
    my $gender = $v->param('gender');

    my $activity_datetime = $v->every_param('activity-datetime');

    my $email_addr   = $v->param('email');
    my $birth_date   = $v->param('birth_date');
    my $phone        = $v->param('phone');
    my $address      = $v->param('address');
    my $need_1365    = $v->param('need_1365');
    my $org_username = $v->param('org_username');
    my $org_region   = $v->param('org_region');
    my $period       = $v->param('period');
    my $talent       = $v->param('talent');
    my $comment      = $v->param('comment');
    my $activity     = $v->param('activity');
    my $reasons      = $v->every_param('reason');
    my $paths        = $v->every_param('path');
    my $job          = $v->param('job');

    my @added;
    my $tz = $self->config->{timezone};
    my $volunteer;
    for my $datetime (@$activity_datetime) {
        my ( $date, $hours ) = split / /, $datetime;
        my ( $from, $to )    = split /-/, $hours;

        my $able_hours = $self->_able_hour($date);
        return $self->error( 400, "Not allow activity hours: $hours" ) unless $able_hours->{$hours};

        my $dt = DateTime::Format::ISO8601->parse_datetime($date);
        $dt->set_time_zone($tz);

        $volunteer = $self->schema->resultset('Volunteer')->find_or_create(
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
                    -between =>
                        [$parser->format_datetime($dt), $parser->format_datetime( $dt->clone->add( days => 1 ) )]
                },
                status => 'reported',
            }
        );

        return $self->error( 400, '같은날 두번 이상 신청할 수 없습니다' ) if $rs->count;

        my $work = $self->schema->resultset('VolunteerWork')->create(
            {
                volunteer_id       => $volunteer->id,
                activity_from_date => "$date $from:00",
                activity_to_date   => "$date $to:00",
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
        push @added, sprintf( '%d월 %d일', $dt->month, $dt->day );
    }

    my $msg = $self->render_to_string( 'sms/status-reported', format => 'txt', name => $name, dates => \@added );
    $phone =~ s/-//g;
    $self->sms( $phone, $msg );

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
    $self->render( 'work/done', volunteer => $volunteer, dates => \@added );
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

=head2 cancel

    # work.cancel
    GET /works/:id/cancel?phone=xxxx (뒷자리)

=cut

sub cancel {
    my $self      = shift;
    my $work      = $self->stash('work');
    my $phone     = $self->param('phone');
    my $volunteer = $work->volunteer;

    return $self->error( 400, '본인확인을 할 수 없습니다.' ) unless $phone;
    return $self->error( 400, '신청자의 휴대폰번호와 일치하지 않습니다.' )
        if substr( $volunteer->phone, -4 ) ne $phone;

    $self->stash( volunteer => $volunteer );
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
    my $year = $now->year;
    my $from = $work->activity_from_date;
    my $to   = $work->activity_to_date;

    my %filled = ( $work->get_columns, $volunteer->get_columns );
    $filled{reason} = [split /\|/, $filled{reason}];
    $filled{path}   = [split /\|/, $filled{path}];
    $filled{'activity-date'}  = $from->ymd;
    $filled{'activity-hours'} = $from->hour . '-' . $to->hour;
    $filled{birth_date} = $volunteer->birth_date->ymd if $volunteer->birth_date;
    $self->stash( holidays => [$self->holidays( $year, $year + 1 )] );

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
            activity_from_date => "$activity_date $from:00",
            activity_to_date   => "$activity_date $to:00",
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
        my $from     = $work->activity_from_date;
        my $to       = $work->activity_to_date;
        my $event_id = $self->calendar_insert( $volunteer->name, $from, $to );
        $work->update( { event_id => $event_id } );
    }

    $self->render( 'work/done', work => $work );
}

=head2 update_status

    PUT /works/:id/status?status=reported|approved|done|canceled

=cut

sub update_status {
    my $self      = shift;
    my $work      = $self->stash('work');
    my $volunteer = $work->volunteer;

    my $validation = $self->validation;
    $validation->required('status')->in(qw/reported approved done canceled drop/);
    return $self->error( 400, 'Parameter Validation Failed' ) if $validation->has_error;

    my $from_status = $work->status;
    my $status      = $validation->param('status');
    $work->update( { status => $status } );

    if ( $status eq 'approved' ) {
        my $phone = $volunteer->phone =~ s/\-//gr;
        my $msg = $self->render_to_string( 'sms/status-approved', format => 'txt', work => $work );
        chomp $msg;
        my $sent = $self->sms( $phone, $msg );
        $self->log->error("Failed to send SMS: $msg") unless $sent;

        $msg = $self->render_to_string( 'sms/opencloset-location', format => 'txt' );
        chomp $msg;
        $sent = $self->sms( $phone, $msg );
        $self->log->error("Failed to send SMS: $phone, $msg") unless $sent;

        ## Google Calendar
        my $volunteer = $work->volunteer;
        my $from      = $work->activity_from_date;
        my $to        = $work->activity_to_date;
        my $event_id  = $self->calendar_insert( $volunteer->name, $from, $to );
        $work->update( { event_id => $event_id } );
    }
    elsif ( $status =~ /canceled|drop/ ) {
        my $event_id = $work->event_id;
        $self->delete_event($event_id) if $event_id;

        if ( $from_status eq 'approved' ) {
            my $email = Email::Simple->create(
                header => [
                    From => $self->config->{email_notify_from},
                    To   => $self->config->{email_notify_to},
                    Subject =>
                        sprintf(
                        "[열린옷장 승인된 봉사활동 취소] %s님이 봉사활동을 취소하였습니다.",
                        $volunteer->name ),
                ],
                body => '--',
            );
            $self->send_mail( encode_utf8( $email->as_string ) );
        }
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

    $v->required('activity-datetime')->like(qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}-\d{2}:\d{2}$/);
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

    my $tz     = $self->config->{timezone};
    my $parser = $self->schema->storage->datetime_parser;
    my $dt     = DateTime->new( year => $year, month => $mm, day => $dd, time_zone => $tz );
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

    my $dow            = $dt->day_of_week;                  # 1-7 (Monday is 1)
    my $max_volunteers = $self->config->{max_volunteers};

    my %result;
    my @templates = qw/10:00-11:00 10:00-12:30 10:00-12:30 14:00-18:00 10:00-16:00 10:00-17:00 10:00-18:00/;
    for my $template (@templates) {
        my $able = 1;
        my ( $start, $end ) = split /-/, $template;
        $start = substr $start, 0, 2;
        $end   = substr $end,   0, 2;
        for my $hour ( $start .. $end ) {
            my $max
                = defined $max_volunteers->{$dow}{$hour} ? $max_volunteers->{$dow}{$hour} : $max_volunteers->{default};
            if ( $schedule{$hour} && $schedule{$hour} >= $max ) {
                $able = 0;
                last;
            }
        }

        $result{$template} = $able;
    }

    return {%result};
}

=head2 list

    GET /works

=cut

sub list {
    my $self   = shift;
    my $status = $self->param('status') || 'reported';
    my $query  = $self->param('q') // '';

    $self->stash( pageset => '' );    # prevent undefined error in template

    my $tz = $self->config->{timezone} || 'Asia/Seoul';
    my ( $works, $standby );
    my $parser = $self->schema->storage->datetime_parser;
    $works = $self->schema->resultset('VolunteerWork')
        ->search( { status => $status }, { order_by => 'activity_from_date' } );

    if ( $status eq 'done' ) {
        $works = $works->search(
            {
                activity_from_date =>
                    { '>' => $parser->format_datetime( DateTime->now( time_zone => $tz )->subtract( days => 7 ) ) },
                need_1365 => 1,
                done_1365 => { '<>' => 0 },
            },
            { order_by => [{ -desc => 'need_1365' }, { -asc => 'done_1365' }, { -desc => 'activity_from_date' }] }
        );
        $standby
            = $self->schema->resultset('VolunteerWork')->search( { status => $status, need_1365 => 1, done_1365 => 0, },
            { order_by => [{ -desc => 'need_1365' }, { -asc => 'done_1365' }, { -desc => 'activity_from_date' }] } );
    }
    elsif ( $status eq 'canceled' or $status eq 'drop' ) {
        my $p = $self->param('p') || 1;
        $works = $works->search( undef, { page => $p, rows => 10, order_by => { -desc => 'id' } } );

        my $pageset = Data::Pageset->new(
            {
                total_entries    => $works->pager->total_entries,
                entries_per_page => $works->pager->entries_per_page,
                pages_per_set    => 5,
                current_page     => $p,
            }
        );

        $self->stash( pageset => $pageset );
    }

    if ($query) {
        $works = $self->schema->resultset('VolunteerWork')->search(
            {
                -or => {
                    'volunteer.name'  => $query,
                    'volunteer.phone' => $self->phone_format($query),
                    'volunteer.email' => $query
                }
            },
            { join => 'volunteer' }
        );
    }

    $self->render( works => $works, standby => $standby );
}

1;
