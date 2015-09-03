package OpenCloset::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use HTTP::Tiny;
use JSON::WebToken;
use JSON;
use Path::Tiny;
use Try::Tiny;
use MIME::Base64 'encode_base64url';

=encoding utf8

=head1 NAME

OpenCloset::Plugin::Helpers

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'Evid::Plugin::Helpers';
    # Mojolicious
    $self->plugin('OpenCloset::Plugin::Helpers');

=head1 HELPERS

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    $app->helper( log => sub { shift->app->log } );
    $app->helper( error        => \&error );
    $app->helper( auth_google  => \&auth_google );
    $app->helper( quickAdd     => \&quickAdd );
    $app->helper( delete_event => \&delete_event );
    $app->helper( send_mail    => \&send_mail );
}

=head2 error

    get '/foo' => sub {
        my $self = shift;
        my $required = $self->param('something');
        return $self->error(400, 'oops wat the..') unless $required;
    } => 'foo';

=head2 log

shortcut for C<$self->app->log>

    $self->app->log->debug('message');    # OK
    $self->log->debug('message');         # OK, shortcut

=cut

sub error {
    my ( $self, $status, $error ) = @_;

    $self->log->error($error);

    no warnings 'experimental';
    my $template;
    given ($status) {
        $template = 'bad_request' when 400;
        $template = 'forbidden' when 403;
        $template = 'not_found' when 404;
        $template = 'exception' when 500;
        default { $template = 'unknown' }
    }

    $self->respond_to(
        json => { status => $status, json => { error => $error || q{} } },
        html => { status => $status, error => $error || q{}, template => "error/$template" },
    );

    return;
}

=head2 auth_google

=cut

sub auth_google {
    my $self = shift;

    my $private_key = $self->config->{google_private_key};
    return unless $private_key;

    my $json_private = path($private_key);
    return unless $json_private;

    my $private = try {
        decode_json( $json_private->slurp );
    }
    catch {
        $self->log->error("Failed to decode json: $_");
    };

    return unless $private;

    my $time               = time;
    my $private_key_string = $private->{private_key};
    my $claim_set          = {
        iss => $private->{client_email},
        scope =>
            'https://www.googleapis.com/auth/calendar https://mail.google.com https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.send',
        aud => 'https://www.googleapis.com/oauth2/v3/token',
        exp => $time + 3600,
        iat => $time
    };

    my $jwt  = encode_jwt $claim_set, $private_key_string, 'RS256', { typ => 'JWT' };
    my $http = HTTP::Tiny->new;
    my $res  = $http->post_form( "https://www.googleapis.com/oauth2/v3/token",
        { grant_type => 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion => $jwt } );
    unless ( $res->{success} ) {
        $self->log->error("Google Authorization Failed");
        $self->log->error("$res->{status}: $res->{reason}\n$res->{content}\n");
        return;
    }

    my $token = try {
        decode_json( $res->{content} );
    }
    catch {
        $self->log->error("Failed to decode json: $_");
    };

    return unless $token;

    $self->session( token => { %$token, exp => $time + 3600, iat => $time } );
    return 1;
}

=head2 quickAdd

=cut

sub quickAdd {
    my ( $self, $text ) = @_;

    my $time  = time;
    my $token = $self->session('token');
    if ( !$token || $token->{exp} < $time ) {
        my $is_auth = $self->auth_google;
        unless ($is_auth) {
            $self->log->debug("Failed to add calendar event: Authorization failed");
            return;
        }

        $token = $self->session('token');
    }

    my $calendarId = $self->config->{google_calendar_id};
    my $url        = "https://www.googleapis.com/calendar/v3/calendars/$calendarId/events/quickAdd";
    my $http       = HTTP::Tiny->new;
    my $res        = $http->post_form(
        "$url",
        { text    => $text },
        { headers => { authorization => "$token->{token_type} $token->{access_token}" } }
    );

    unless ( $res->{success} ) {
        $self->log->error("Failed to posting a new calendar event");
        $self->log->error("$res->{status}: $res->{reason}\n$res->{content}\n");
        return;
    }

    $self->log->debug("Added an event successfully");
    return decode_json( $res->{content} )->{id};
}

=head2 delete_event

=cut

sub delete_event {
    my ( $self, $event_id ) = @_;

    my $time  = time;
    my $token = $self->session('token');
    if ( !$token || $token->{exp} < $time ) {
        my $is_auth = $self->auth_google;
        unless ($is_auth) {
            $self->log->debug("Failed to add calendar event: Authorization failed");
            return;
        }

        $token = $self->session('token');
    }

    my $calendarId = $self->config->{google_calendar_id};
    my $url        = "https://www.googleapis.com/calendar/v3/calendars/$calendarId/events/$event_id";
    my $http       = HTTP::Tiny->new;
    my $res
        = $http->delete( "$url", { headers => { authorization => "$token->{token_type} $token->{access_token}" } } );

    unless ( $res->{success} ) {
        $self->log->error("Failed to delete event");
        $self->log->error("$res->{status}: $res->{reason}\n$res->{content}\n");
        return;
    }

    $self->log->debug("Deleted an event successfully");
    return 1;
}

=head2 send_mail

=over parameters

=item $email - RFC 5322 formatted String.

=back

=cut

sub send_mail {
    my ( $self, $email ) = @_;

    my $time  = time;
    my $token = $self->session('token');
    if ( !$token || $token->{exp} < $time ) {
        my $is_auth = $self->auth_google;
        unless ($is_auth) {
            $self->log->debug("Failed to add calendar event: Authorization failed");
            return;
        }

        $token = $self->session('token');
    }

    my $userId = $self->config->{google_user_id};
    $self->log->debug( encode_base64url($email) );

    # https://www.googleapis.com/gmail/v1/users/$userId/messages/send
    # https://www.googleapis.com/upload/gmail/v1/users/$userId/messages/send?uploadType=media
    my $url  = "https://www.googleapis.com/upload/gmail/v1/users/$userId/messages/send?uploadType=media";
    my $http = HTTP::Tiny->new;
    my $res  = $http->request(
        'POST', "$url",
        {
            headers =>
                { authorization => "$token->{token_type} $token->{access_token}", 'content-type' => 'message/rfc822' },
            content => encode_base64url($email)
        }
    );

    unless ( $res->{success} ) {
        $self->log->error("Failed to send email");
        $self->log->error("$res->{status}: $res->{reason}\n$res->{content}\n");
        return;
    }

    $self->log->debug("Sent an email successfully");
    return 1;
}

1;
