package OpenCloset::Volunteer;
use Mojo::Base 'Mojolicious';

use Email::Valid ();
use HTTP::Body::Builder::MultiPart;
use HTTP::Tiny;

use OpenCloset::Schema;

use version; our $VERSION = qv("v0.3.7");

has schema => sub {
    my $self = shift;
    my $conf = $self->config->{database};
    OpenCloset::Schema->connect(
        { dsn => $conf->{dsn}, user => $conf->{user}, password => $conf->{pass}, %{ $conf->{opts} }, } );
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin( Minion => { SQLite => $self->config->{minion}{SQLite} } );
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('OpenCloset::Volunteer::Plugin::Helpers');

    $self->secrets( $self->config->{secrets} );
    $self->sessions->cookie_domain( $self->config->{cookie_domain} );
    $self->sessions->cookie_name('opencloset');
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_public_routes;
    $self->_private_routes;
    $self->_extend_validator;
    $self->_add_task;
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
    $work->put('/status')->to('work#update_status');
    $work->put('/1365')->to('work#update_1365');
    $work->get('/guestbook')->to('work#add_guestbook')->name('work.guestbook');
    $work->post('/guestbook')->to('work#create_guestbook');
}

sub _private_routes {
    my $self = shift;
    my $root = $self->routes;

    my $r = $root->under('/')->to('user#auth');
    $r->get('/works')->to('work#list');
    $r->get('/summary')->to('volunteer#summary');
    $r->post('/photos')->to('photo#create');
    $r->post('/volunteer/:id')->to('volunteer#update');
}

sub _extend_validator {
    my $self = shift;

    $self->validator->add_check(
        email => sub {
            my ( $v, $name, $value ) = @_;
            return not Email::Valid->address($value);
        }
    );
}

sub _add_task {
    my $self   = shift;
    my $minion = $self->minion;
    $minion->reset;

    $minion->add_task(
        upload_photo => sub {
            my ( $job, $key, $img ) = @_;
            return unless $key;
            return unless $img;

            my $app     = $job->app;
            my $oavatar = $app->config->{oavatar};
            my ( $token, $url ) = ( $oavatar->{token}, $oavatar->{url} );
            my $multipart = HTTP::Body::Builder::MultiPart->new;
            $multipart->add_content( token => $token );
            $multipart->add_content( key   => $key );
            $multipart->add_file( img => $img );

            my $http = HTTP::Tiny->new;
            my $res  = $http->request(
                'POST', $url,
                {
                    headers => { 'content-type' => 'multipart/form-data; boundary=' . $multipart->{boundary} },
                    content => $multipart->as_string
                }
            );

            unless ( $res->{success} ) {
                $app->log->error("Failed to upload a oavatar: $res->{reason}");
            }
            else {
                $app->log->info("Photo uploaded: $res->{headers}{location}");
            }

            $img->remove;
        }
    );
}

1;
