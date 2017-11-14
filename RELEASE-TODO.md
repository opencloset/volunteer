v0.4.1

v0.4.0

v0.3.13

v0.3.12

v0.3.11

v0.3.10

v0.3.9

v0.3.8

v0.3.7

v0.3.6

    $ grunt

v0.3.5

    $ cpanm HTTP::Body::Builder::MultiPart
    $ bower install
    $ grunt
    $ MOJO_CONFIG=volunteer.conf script/volunteer minion worker    # minion worker 를 띄워야 한다

v0.3.4

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
