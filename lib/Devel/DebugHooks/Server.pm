package Devel::DebugHooks::Server;

use strict;
use warnings;


# We should define utility subs first...
## IO::Async stuff
# global DATA
my $loop;
my $stream;



sub tinfo {
	return " - $$ ($loop) w:" .uwsgi::worker_id();
}


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


	my $caller;
	my $level =  0;
	1 while( ($caller =  (caller( $level++ ))[3])  &&  $caller ne 'DB::DB' );
	# Is debugger sleeping at the current moment?
	if( $caller ne 'DB::DB' ) {
		if( $$buffref =~ s/^([\w.]+)(?:\s+(.*))?\n// ) {
			$DB::commands->{ $1 }->( $2 );

			return 1;
		}

		return 0;
	}


	if( $$buffref =~ s/^(.*?)\r?(\n)// ) {
		print $DB::OUT "\nThis is the thread (RC): " .tinfo() ."\n\n";

		$$buffref = "$1$2$$buffref"   unless defined &readline( "$1$2" );

		return 0;
	}

	warn "Text '$$buffref' is left in buffer"   if $$buffref;

	if( $eof ) {
		warn "TTYIN EOF";
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


	warn "New client connected";
	( $stream ) =  @_;

	$stream->configure(
		close_on_read_eof =>  0
		,on_read          =>  \&read_command
		,on_write_eof     =>  \&handle_write_eof
		,on_write_error   =>  \&handle_write_error
		,on_closed        =>  \&handle_closed
		,autoflush        =>  1
		,write_all        =>  1
	);

	$loop->add( $stream );

	$DB::OUT =  $stream->read_handle();
	printflush $DB::OUT "DBG>>\n";

	my $str =  "\nThis is the thread (Start): " .tinfo() ."\n\n";
	`echo '$str' > /home/feelsafe/loop`;
	$stream->write( $str );
}


sub listen {
	my( $loop ) =  @_;

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

			warn "listening on: " .$s->sockhost . ':' .$s->sockport;
			warn "\nThis is the thread(Listen): " .tinfo();
		},

		# This sub is invoked for each new incoming connection
		on_stream =>  \&start_dbg_session,
	);
}





# Setup and process $loop
# We can uncoment this if we want debugger messages were sent to dbg client
# BEGIN {
# 	use IO::Async::Loop;
# 	$loop =  IO::Async::Loop->new;
# 	# As soon as possible
# 	# But, it is better that only worker listens to :9000
# 	# And because of BEGIN block the IO::Async modules are noticed by debugger
# 	&listen( $loop );
# 	sleep 2; # wait dbg client to connect
# 	$loop->loop_once( 0 );
# }
use IO::Async::Loop;
$loop =  IO::Async::Loop->new;


sub uwsgi_signal_handler {
	# print $DB::OUT time() ." Singal" .tinfo() ."\n";

	$loop->loop_once( 0 );
}



uwsgi::postfork( sub{
	&listen( $loop );
	$loop->loop_once( 0 );
	# Useless. Signals are sended to worker only after it is forked
	# uwsgi::signal( 1 );
	print $DB::OUT time() ." Forked\n";
});


uwsgi::register_signal( 1, 'workers', \&uwsgi_signal_handler );
uwsgi::add_timer( 1, 1 );



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



sub init {
	my $self =  shift;

	$DB::ext_call++;
	DB::scall( $DB::commands->{ load } );
}



# ... define another utilities that can be called at CT
my $last_input =  's';
sub interact {
	my $self =  shift;

	# DB::_all_frames();

	printflush $DB::OUT tinfo() ."\nDBG>"; # TODO: print promt only when session is active

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



# ... now we can use DebugHooks
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



use Devel::DebugHooks();

1;
