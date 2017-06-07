v0.3.3

    $ cpanm Data::Pageset
    $ grunt

v0.3.2

    # volunteer.conf
    secrets       => [$ENV{OPENCLOSET_SECRET}],
    cookie_domain => $ENV{OPENCLOSET_DOMAIN} || 'localhost' || '.theopencloset.net',

    # env
    export OPENCLOSET_SECRET='secret'
    export OPENCLOSET_DOMAIN='.theopencloset.net'
