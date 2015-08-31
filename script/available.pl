#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use OpenCloset::Schema;
use DateTime;

my $config = require 'volunteer.conf';
my $conf   = $config->{database};

my %options;
GetOptions( \%options, '--help' );
run( \%options, @ARGV );

sub run {
    my ( $opts, @args ) = @_;
    pod2usage(0) if $opts->{help};
    pod2usage(0) unless @args;

    my ($ymd) = @args;
    my ( $year, $mm, $dd ) = split /-/, $ymd;
    my $schema = OpenCloset::Schema->connect(
        { dsn => $conf->{dsn}, user => $conf->{user}, password => $conf->{pass}, %{ $conf->{opts} } } );
    my $parser = $schema->storage->datetime_parser;
    my $dt     = DateTime->new( year => $year, month => $mm, day => $dd );
    my $rs     = $schema->resultset('VolunteerWork')->search(
        {
            activity_from_date => {
                -between => [$parser->format_datetime($dt), $parser->format_datetime( $dt->clone->add( days => 1 ) )]
            }
        }
    );

    my %schedule;
    while ( my $row = $rs->next ) {
        my $from = $row->activity_from_date;
        my $to   = $row->activity_to_date;
        $schedule{$_}++ for ( $from->hour .. $to->hour );
    }
}

__END__

=encoding utf-8

=pod

=head1 SYNOPSIS

    $ available.pl <yyyy-mm-dd>
      -h --help                Display the help information

=cut
