    $ cd /path/to/OpenCloset-Schema/
    $ mysql < db/alter/129-volunteer-comment.sql
    $ closetpan OpenCloset::Schema    # v0.053
    $ grunt
    $ cpanm Email::Valid

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
