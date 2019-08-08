#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use OpenCloset::Schema;
use DateTime;
use Data::Dump;

my $config = require 'volunteer.conf';
my $conf   = $config->{database};

our $MAX_VOLUNTEERS = 6;

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

    my $dow            = $dt->day_of_week;                  # 1-7 (Monday is 1)
    my $max_volunteers = $config->{max_volunteers};

    my %result;
    my @templates = qw/09:00-12:00 12:00-16:00 17:00-20:00 09:00-16:00/;
    for my $template (@templates) {
        my $able = 1;
        my ( $start, $end ) = split /-/, $template;
        $start = substr $start, 0, 2;
        $end   = substr $end,   0, 2;
        for my $hour ( $start .. $end ) {
            my $max
                = defined $max_volunteers->{$dow}{$hour} ? $max_volunteers->{$dow}{$hour} : $max_volunteers->{default};
            if ( $max == 0 || $schedule{$hour} && $schedule{$hour} >= $max ) {
                $able = 0;
                last;
            }
        }

        $result{$template} = $able;
    }

    dd %result;
}

__END__

=encoding utf-8

=pod

=head1 SYNOPSIS

    $ available.pl <yyyy-mm-dd>
      -h --help                Display the help information

=cut
