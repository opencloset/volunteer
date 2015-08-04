package OpenCloset::Volunteer;
use Mojo::Base 'Mojolicious';

use OpenCloset::Schema;

has schema => sub {
    my $self = shift;
    OpenCloset::Schema->connect(
        {
            dsn      => $self->config->{database}{dsn},
            user     => $self->config->{database}{user},
            password => $self->config->{database}{pass},
            %{ $self->config->{database}{opts} },
        }
    );
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->secrets( [$ENV{VOLUNTEER_SECRET} || time] );
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_public_routes;
    $self->_private_routes;
}

sub _assets {
    my $self = shift;

    $self->plugin('AssetPack');
    $self->defaults( js => 'default.js', css => 'screen.css' );
    $self->asset( 'screen.css' => '/assets/scss/screen.scss' );
    $self->asset(
        'bundle.js' => qw{/assets/components/jquery/dist/jquery.js
            /assets/components/bootstrap/dist/js/bootstrap.js
            /assets/components/underscore/underscore.js}
    );
    $self->asset( 'default.js' => $self->asset->get('bundle.js') );
    $self->asset(
        'datepicker.js' =>
            qw{/assets/components/bootstrap-datepicker/js/bootstrap-datepicker.js
            /assets/components/bootstrap-datepicker/js/locales/bootstrap-datepicker.kr.js}
    );
    $self->asset(
        'work-add.js' => $self->asset->get('bundle.js'),
        $self->asset->get('datepicker.js'),
        qw{/assets/components/jQuery-Mask-Plugin/dist/jquery.mask.js
            /assets/coffee/work-add.coffee}
    );
    $self->asset(
        'work-add.css' =>
            '/assets/components/bootstrap-datepicker/css/datepicker3.css',
        $self->asset->get('screen.css')
    );
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    my $work = $r->under('/works');
    $work->get('/new')->to('work#add');
    $work->post('/')->to('work#create');
}

sub _private_routes { }

1;
