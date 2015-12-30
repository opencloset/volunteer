#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::ICal;
use DateTime::Format::ISO8601;

my %options;
GetOptions( \%options, '--help' );
run( \%options, @ARGV );

sub run {
    my ( $opts, @args ) = @_;
    pod2usage(0) if $opts->{help};
    pod2usage(0) if @args < 2;

    # https://www.google.com/calendar/ical/ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics
    my $year    = $args[0];
    my $obj     = Data::ICal->new( filename => $args[1] );
    my $entries = $obj->entries;

    my @holidays;
    my $parser = DateTime::Format::ISO8601->new;
    for my $entry (@$entries) {
        my $ref = ref $entry;
        next if $ref ne 'Data::ICal::Entry::Event';

        my $properties = $entry->properties;
        my @keys       = keys %$properties;

        my $summary = get( $properties, 'summary' );
        my $dtstart = get( $properties, 'dtstart' );

        if ( $dtstart =~ /^$year/ ) {
            push @holidays, { summary => $summary, dt => $parser->parse_datetime($dtstart) };
            next;
        }

        if ( "@keys" =~ /rrule/ ) {
            my $rrule = get( $properties, 'rrule' );
            if ( $rrule eq 'FREQ=YEARLY' ) {
                $dtstart =~ s/^..../$year/;
                push @holidays, { summary => $summary, dt => $parser->parse_datetime($dtstart), yearly => 1 };
                next;
            }
        }
    }

    my $coffee = 'holidays = [';
    my @dates;
    print "Edit file public/assets/coffee/work-add.coffee\n";
    for my $holiday ( sort { $a->{dt} <=> $b->{dt} } @holidays ) {
        printf "# [%s] %s\n", $holiday->{dt}->ymd, $holiday->{summary};
        push @dates, "'" . $holiday->{dt}->ymd . "'";
    }

    $coffee .= join( ',', @dates ) . ']';

    print "$coffee\n";
}

sub get {
    my ( $properties, $key ) = @_;
    return unless $key;
    return $properties->{$key}[0]->value;
}

__END__

=encoding utf-8

=pod

=head1 SYNOPSIS

    $ generate-holiday-as-coffee-code.pl <year> <ics-file>
      -h --help                Display the help information

=cut
