package Devel::DebugHooks::Server;

use strict;
use warnings;



## IO::Async stuff
# global DATA
my $loop;
my $stream;


# event handlers
sub handle_write_eof {
	die "Write error: >>@_<<";
}


sub handle_write_error {
	die "Write error: >>@_<<";
}


sub handle_closed {
	$DB::OUT =  \*STDOUT;
	undef $stream;
	warn "Session closed";
}


sub read_command {
	my( $self, $buffref, $eof ) =  @_;

	if( $$buffref =~ s/^(.*?)\r?(\n)// ) {
		$$buffref = "$1$2$$buffref"   unless defined &readline( "$1$2" );

		return 0;
	}

	warn "Text '$$buffref' is left in buffer"   if $$buffref;

	if( $eof ) {
		warn "DBG $self EOF";
		$self->close_when_empty();
	}

	return 0;
}


sub start_dbg_session {
	if( defined $stream ) {
		$_[0]->write( "Debugging session is attached already\n" );
		$_[0]->close_when_empty();
		return;
	}

	( $stream ) =  @_;

	$stream->configure(
		close_on_read_eof =>  0
		,on_read          =>  \&read_command
		,on_write_eof     =>  \&handle_write_eof
		,on_write_error   =>  \&handle_write_error
		,on_closed        =>  \&handle_closed
		,autoflush        =>  1
	);

	$DB::OUT =  $stream->read_handle();

	$loop->add( $stream );
}



# Setup and process $loop
use IO::Async::Loop;
$loop = IO::Async::Loop->new;
$loop->listen(
	# family =>  'unix',
	# path   =>  'file.sock',
	family   =>  'inet',
	socktype =>  'stream',
	host     =>  '127.0.0.1',
	service  =>  9000,
	on_resolve_error =>  sub { die "Cannot resolve - $_[1] <<< @_\n"; },
	on_listen_error  =>  sub { die "Cannot listen  - $_[1] <<< @_\n"; },
	on_listen        =>  sub {
		my( $s ) =  @_;

		warn "listening on: " . $s->sockhost . ':' . $s->sockport . "\n";
	},

	# This sub is invoked for each new incoming connection
	on_stream =>  \&start_dbg_session,
);


my $dbg_buffer;
sub readline {
	# set
	if( @_ ) {
		return   if defined $dbg_buffer;

		return( $dbg_buffer =  shift )
	}


	# get
	while( !defined $dbg_buffer ) {
		if( $stream ) {
			$stream->invoke_event( 'on_read', \$stream->{ readbuff } );
			last   if defined $dbg_buffer;
		}

		$loop->loop_once();
	}


	my $result =  $dbg_buffer;
	undef $dbg_buffer;
	return $result;
}

# END OF IO::Async stuff




our @ISA;

BEGIN {
	$DB::options{ trace_load }  //=  1;
	$DB::options{ trace_subs }  //=  0;
	$DB::options{ trace_returns }  //=  0;
	$DB::options{ _debug }      //=  0;
	$DB::options{ dbg_frames }  //=  0;
	$DB::options{ NonStop    }  //=  0;
	@DB::options{ qw/ w s / } = ( 1, 1 );
	push @ISA, 'Devel::DebugHooks::Verbose';
}



sub import {
	my $class =  shift;

	$class->SUPER::import( @_ );
}



use Devel::DebugHooks( 'trace_subs=0' );

my $last_input;
sub interact {
	my $self =  shift;

	print $DB::OUT "DBG>"; # flush buffers
	my $line =  &readline();
	chomp $line;
	if( $line ne '' ) {
		$last_input =  $line;
	}
	else {
		$line =  $last_input;
	}


	return $line;
}


#$loop->loop_once;

1;
