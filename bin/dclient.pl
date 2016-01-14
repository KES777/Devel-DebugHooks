#!/usr/bin/env perl

use warnings;
use strict;


our $session_stream;


my ( $host, $port ) =  @ARGV[ 1, 2 ];
$host //=  '127.0.0.1';
$port //=  9000;


use IO::Async::Loop;
my $loop = IO::Async::Loop->new;

use IO::Async::Timer::Periodic;
my $timer = IO::Async::Timer::Periodic->new(
    first_interval =>  0,
    interval       =>  5,

    on_tick        =>  sub {
        warn ">>@_<<<< Retrying";
        my $self =  shift;

        unless( $session_stream  &&  $session_stream->loop ) {
            create_dbg_session( $loop, $host, $port );
        } else {
            warn "Stopping the timer";
            $self->stop;
        }
    },
);



# - - - - -
sub handle_write_eof {
    warn "Write EOF: >>@_<<";
}


sub handle_write_error {
    warn "Write error: >>@_<<";
}


sub handle_closed {
    warn "Closed >>@_<<$session_stream<<";

    $timer->start;
}


sub handle_read_eof {
    warn "Read EOF: >>@_<<";
}


sub handle_read_error {
    warn "Read error: >>@_<<";
}


sub handle_read {
    my( $self, $buffref, $eof ) =  @_;


    while( $$buffref =~ s/^(.*)(\n)// ) {
        on_data( "$1$2" );
    }

    if( $eof ) {
        warn "SESSION $self EOF";
        $self->close_when_empty();
    }


    return 0;
};


sub on_data {
    print @_;
}



# - - - -
sub on_dbg_session {
    ( $session_stream ) =  @_;


    $session_stream->configure(
        close_on_read_eof =>  0
        ,autoflush        =>  1

        ,on_write_eof     =>  \&handle_write_eof
        ,on_write_error   =>  \&handle_write_error
        ,on_closed        =>  \&handle_closed

        ,on_read_eof      =>  \&handle_read_eof
        ,on_read_error    =>  \&handle_read_error
        ,on_read          =>  \&handle_read
    );


    $loop->add( $session_stream );

    warn "DBG session activated";
}


# Подключение по протоколу TCP к хосту на порт
sub create_dbg_session {
    my( $loop, $host, $port ) =  @_;


    $loop->connect(
        host     =>  $host,
        service  =>  $port,
        socktype =>  'stream',

        on_resolve_error => sub { die "Cannot resolve - $_[0]\n"; },
        on_connect_error => sub { warn "Cannot connect\n"; },

        # Успешное подключение
        on_stream =>  \&on_dbg_session
    );
}

# - - - - -

$timer->start;
$loop->add( $timer );
$loop->run;
