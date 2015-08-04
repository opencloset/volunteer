package OpenCloset::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app, $conf ) = @_;

    $app->helper( log => sub { shift->app->log } );
    $app->helper( error => \&error );
}

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
        html => {
            status => $status,
            error => $error || q{},
            template => "error/$template"
        },
    );

    return;
}

1;

=pod

=encoding utf8

=head1 NAME

OpenCloset::Plugin::Helpers

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'Evid::Plugin::Helpers';
    # Mojolicious
    $self->plugin('OpenCloset::Plugin::Helpers');

=head1 HELPERS

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
