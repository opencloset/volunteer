package OpenCloset::Volunteer;
use Mojo::Base 'Mojolicious';

use SMS::Send::KR::APIStore;
use SMS::Send::KR::CoolSMS;
use SMS::Send;

use OpenCloset::Schema;

use version; our $VERSION = qv("v0.3.2");

has schema => sub {
    my $self = shift;
    my $conf = $self->config->{database};
    OpenCloset::Schema->connect(
        { dsn => $conf->{dsn}, user => $conf->{user}, password => $conf->{pass}, %{ $conf->{opts} }, } );
};

has sms_sender => sub {
    my $self   = shift;
    my $config = $self->config;
    SMS::Send->new( $config->{sms}{driver}, %{ $config->{sms}{ $config->{sms}{driver} } } );
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('OpenCloset::Volunteer::Plugin::Helpers');

    $self->secrets( $self->config->{secrets} );
    $self->sessions->cookie_domain( $self->config->{cookie_domain} );
    $self->sessions->cookie_name('opencloset');
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_public_routes;
    $self->_private_routes;
}

sub _assets {
    my $self = shift;

    $self->defaults( jses => [], csses => [] );
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/')->to('root#home')->name('home');

    my $works = $r->under('/works');
    $works->get('/new')->to('work#add')->name('work.add');
    $works->post('/')->to('work#create');
    $works->get('/hours/:ymd')->to('work#able_hour');

    my $work = $works->under('/:id')->to('work#find_work');
    $work->get('/')->to('work#work')->name('work');
    $work->get('/cancel')->to('work#cancel')->name('work.cancel');
    $work->get('/edit')->to('work#edit')->name('work.edit');
    $work->post('/')->to('work#update')->name('work.update');
    $work->options('/status')->to('work#preflight_cors');
    $work->options('/1365')->to('work#preflight_cors');
    $work->put('/status')->to('work#update_status');
    $work->put('/1365')->to('work#update_1365');
    $work->get('/guestbook')->to('work#add_guestbook')->name('work.guestbook');
    $work->post('/guestbook')->to('work#create_guestbook');
}

sub _private_routes { }

1;
