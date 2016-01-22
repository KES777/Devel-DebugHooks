package Devel::DebugHooks;

BEGIN {
	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
	if( $options{ d } ) { require 'Data/Dump.pm'; 'Data::Dump'->import( 'pp'); }
}

our $VERSION =  '0.01';


# We should init $DB::dbg as soon as possible, because if trace_subs/load are
# enabled at compile time (at the BEGIN block) the DB:: module will make call
# to $dbg->trace_subs/load. Also these subs should be declared before the
# 'use Devel::DebugHooks' in other case you will get:
# 'Call to undefined sub YourModule::trace_subs/load is made...'
# That is because perl internals make calls to DB::* as soon as the subs in it
# are compiled even whole file is not processed yet.
# Also do not forget to 'push @ISA, "YourModule"' if you set these options at
# compile time: trace_load, trace_subs,
BEGIN {
	unless( defined $DB::dbg ) {
		my $level =  0;
		while( my @frame =  caller($level++) ) {
			$DB::dbg =  $frame[0]   if $frame[0] =~ /^Devel::/;
		}
		# ISSUE: We can not make 'main' package as descendant of 'Devel::DebugHooks'
		# because of broken info from 'caller', so I restrict pkg_names to 'Devel::'
		# TODO: Ask #p5p about that 'caller' shows strange file:line for (eval)
		# https://rt.perl.org/Public/Bug/Display.html?id=127083

		unless( defined $DB::dbg ) {
			$DB::dbg =  'Devel::DebugHooks::Verbose';
			@DB::options{ qw/ trace_load trace_subs trace_returns / } = ( 1, 1, 1 );
		}
	}
}



sub init {
}



sub import {
	DB::import( @_ );
}



sub trace_load {
	my $self =  shift;

	return "Loaded '@_'\n"
}



# This sub is called for each DB::DB call while $DB::trace is true
sub trace_line {
	print "$DB::line\n";
}



sub watch {
	my $self =  shift;
	my( $watches ) =  @_;


	my $changed =  0;
	for my $item ( @$watches ) {
		BEGIN{ 'warnings'->unimport( 'experimental::smartmatch' )   if $DB::options{ w } }
		unless( @{ $item->{ old } }  ~~  @{ $item->{ new } } ) {
			$changed ||=  1;
			# print $DB::OUT "The value of " .$item->{ expr } ." is changed:\n"
			# 	."The old value: ". Data::Dump::pp( @{ $item->{ old } } ) ."\n"
			# 	."The new value: ". Data::Dump::pp( @{ $item->{ new } } ) ."\n"
		}
	}


	return 1;
}


sub bbreak {
	my $info =  "\n" .' =' x30 ."$DB::ext_call\n";

	$info .=  "$DB::file:$DB::line    " .DB::source()->[ $DB::line ];

	return $info;
}



sub interact {
}



eval 'require ' .$DB::options{ cmd_processor };
sub process {
	BEGIN{ 'strict'->unimport( 'refs' )   if $DB::options{ s } }
	# TODO: if we set trap on sub that loaded at CT, this will FAIL
	# move require here
	&{ $DB::options{ cmd_processor } .'::process' }( @_ );
}



sub abreak {
}



my %frame_name;
BEGIN {
	%frame_name =  (
		G => 'GOTO',
		D => 'DBGF',
		C => 'FROM',
	);
}

sub trace_subs {
	my( $self ) =  @_;

	BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }


	my $info = '';
	local $" =  ' -';
	my( $orig_frame, $last_frame );
	for my $frame ( DB::frames() ) {
		$last_frame //=  $frame   if $frame->[0] ne 'D';
		$orig_frame //=  $frame   if $frame->[0] ne 'D'  &&  $frame->[0] ne 'G';

		$info .=  $frame_name{ $frame->[0] } .": @$frame[2..5]\n";
	}

	my $context = $orig_frame->[7] ? 'list'
			: defined $orig_frame->[7] ? 'scalar' : 'void';

	$" =  ', ';
	my @args =  map { !defined $_ ? '&undef' : $_ } @{ $orig_frame->[1] };
	$info =
	    "\n" .' =' x15 ."\n"
	    ."DEEP: ". @DB::stack ."\n"
		."CNTX: $context\n"
	    .$last_frame->[0] ."SUB: " .$last_frame->[5] ."( @args )\n"
		# print "TEXT: " .DB::location( $DB::sub ) ."\n";
		# NOTICE: even before function call $DB::sub changes its value to DB::location
		# A: Because @_ keep the reference to args. So
		# 1. The reference to $DB::sub is saved into @_
		# 2. The DB::location is called
		# 3. The value of $DB::sub is changed to DB::location
		# 4. my( $sub ) =  @_; # Here is too late to get the orig value of $DB::sub
	    ."TEXT: " .DB::location( $last_frame->[5] ) ."\n\n"
	    .$info;

	$info .=  ' =' x15 ."\n";

	return $info;
}



sub trace_returns {
	my $self =  shift;

	my $info;
	$info =  $DB::options{ trace_subs } ? '' : "\n" .' =' x15 ."\n";
	# FIX: uninitializind value while 'n'
	# A: Can not reproduce...
	$info .= join '->', map { $_->[3] } @DB::goto_frames;
	$info .= " RETURNS:\n";

	$info .=  @_ ?
		'  ' .join "\n  ", map { defined $_ ? $_ : '&undef' } @_:
		'>>NOTHING<<';

	return $info ."\n" .' =' x15 ."\n";
}


package    # hide the package from the PAUSE indexer
	Devel::DebugHooks::Verbose;

our @ISA;

BEGIN {
	push @ISA, 'Devel::DebugHooks';
}

sub trace_load {
	my $self =  shift;

	print $DB::OUT $self->SUPER::trace_load( @_ );
}

sub trace_subs {
	my $self =  shift;

	print $DB::OUT $self->SUPER::trace_subs( @_ );
}

sub trace_returns {
	my $self =  shift;

	print $DB::OUT $self->SUPER::trace_returns( @_ );
}

sub bbreak {
	my $self =  shift;

	print $DB::OUT $self->SUPER::bbreak( @_ );
}


package    # hide the package from the PAUSE indexer
    DB;



## Utility subs
sub _all_frames {
	BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }

	my $lvl =  1;
	while( my @frame =  caller( $lvl ) ) {
		print $DB::OUT "ORIG: @frame[0..3,5]\n";
		$lvl++;
	}

	print $DB::OUT "\n";
}


# This sub is called twice: at compile time and before run time of 'main' package
sub applyOptions {
	# Q: is warn expected when $DB::trace == undef?
	$DB::trace =  $DB::options{ trace_line } || 0
		if defined $DB::options{ trace_line };

	$^P &= ~0x20   if $DB::options{ NonStop };

}



# Used perl internal variables:
# ${ ::_<filename }
# @{ ::_<filename }
# %{ ::_<filename }
# $DB::single
# $DB::signal
# $DB::trace
# $DB::sub  # NOTICE: this maybe the reference to sub, not just the name of it
# %DB::sub
# %DB::postponed
# @DB::args

# Perl sets up $DB::single to 1 after the 'script.pl' is compiled, so we are able
# to debug it from first OP. We can disable this feature through NonStop option.

our $dbg;            # debugger object/class
our $package;        # current package
our $file;           # current file
our $line;           # current line number
our $ext_call;       # keep silent at DB::sub/lsub while do external call from DB::*
our @goto_frames;    # save sequence of places where nested gotos are called
our $commands;       # hash of commands to interact user with debugger
our @stack;          # array of hashes that alias DB:: ours of current frame
                     # This allows us to spy the DB:: values for the given frame
# TODO? does it better to implement TTY object?
our $IN;
our $OUT;
our %options;



# Do DB:: configuration stuff here
BEGIN {
	$IN                        //= \*STDIN;
	#TODO: cache output until debugger connected
	$OUT                       //= \*STDOUT;

	$options{ _debug }         //=  0;

	$options{ s }              //=  0;         # compile time option
	$options{ w }              //=  0;         # compile time option
	# TODO: camelize options
	$options{ frames }         //=  -1;        # compile time & runtime option
	$options{ dbg_frames }     //=  0;         # compile time & runtime option
	# The differece when we set option at compile time, we see module loadings
	# and compilation order whereas setting up it at run time we lack that info
	$options{ trace_load }     //=  0;         # compile time option
	$options{ trace_subs }     //=  0;         # compile time & runtime option
	$options{ trace_returns }  //=  0;

	$options{ cmd_processor }  //=  'Devel::DebugHooks::CmdProcessor';

	#options{ save_path } # TODO: save code path for displaying by graphviz
	$DB::postponed{ 'DB::DB' } =  1;

	#NOTE: we should always trace goto frames. Hiding them will prevent
	# us to complete our work - debugging.
	# But we still allow to control this behaviour at compiletime & runtime
	# $options{ trace_goto };    #see DH:import  # compile time & runtime option
	$^P |= 0x80;
}

# TODO: describe qw/ frames dbg_frames trace_load trace_subs
# trace_returns / options


# $options{ NonStop } - if true then 0x20 flag is flushed




# $^P default values
#      ! x
# 0111 0011 1111
# |||| |||| |||^-- Debug subroutine enter/exit.
# |||| |||| ||^--- Line-by-line debugging.
# |||| |||| |^---- Switch off optimizations.
# |||| |||| ^----- Preserve more data for future interactive inspections.
# |||| ||||
# |||| |||^------- Keep info about source lines on which a subroutine is defined.
# |||| ||^-------- Start with single-step on.
# |||| |^--------- Use subroutine address instead of name when reporting.
# |||| ^---------- Report goto &subroutine as well.
# ||||
# |||^------------ Provide informative "file" names for evals based on the place they were compiled.
# ||^------------- Provide informative names to anonymous subroutines based on the place they were compiled.
# |^-------------- Save source code lines into @{"_<$filename"}.
# ^--------------- When saving source, include evals that generate no subroutines.
# < When saving source, include source that did not compile.



# NOTICE: it is better to not use any modules from this one
# because we do not want that they appear to compiler before
# we can track module loading and subs calling process
# Also it is safe that descendant debugger module 'use' us. BUT BE AWARE!!!
# That module should not use any module before this one
# if they want track when each sub call occour and each module is loaded
#
# When we 'use' descendant debugger at the end our module appears last at load chain.
# Also there is a problem how to pass descendant class name to 'use' it.
# Keep this comment for history. Find this commit at 'git blame' to see what was changed
BEGIN {
	if( $options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
	if( $options{ s } ) { require 'strict.pm';    'strict'->import();   }
	if( $options{ d } ) { require 'Data/Dump.pm'; 'Data::Dump'->import( 'pp'); }
	# http://perldoc.perl.org/warnings.html
	# The scope of the strict/warnings pragma is limited to the enclosing block.
	# But this not truth.
	# It is limited to the first enclosing block of the BEGIN block
}

BEGIN { # Initialization goes here
	# When we 'use Something' from this module the DB::sub is called at compile time
	# If we do not we can still init them when define
	$DB::ext_call =  0;
	# TODO: set $DB::trace at CT
	applyOptions();
}



# Hooks to Perl's internals should be first.
# Because debugger or its descendants may call them at compile time
{
	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }

		sub file {
			my $filename =  shift // $DB::file;

			return ${ "::_<$filename" };
		}



		sub source {
			my $filename =  shift // $DB::file;

			return \@{ "::_<$filename" };
		}



		sub sources {
			return grep{ s/^_<// } keys %{ 'main::' };
		}



		sub traps {
			my $filename =  shift // $DB::file;

			$DB::_tfiles->{ $filename } =  1;

			return \%{ "::_<$filename" };
		}



		sub can_break {
			my( $file, $line ) =  @_;

			($file, $line) =  split ':', $file
				unless defined $line;

			return defined ${ "::_<$file" }  &&  $line <= $#{ "::_<$file" }
				&& ${ "::_<$file" }[ $line ] != 0;
		}
	}

	sub eval {
		my $package; # BUG: PadWalker does not show DB::eval's lexicals
		# BUG? It is better that PadWalker return undef instead of warn

		$package =  $#_ > 1 ? shift : $DB::package;
		eval "package $package; $_[0]";
	}


	sub location {
		my $subname =  shift;

		return   unless $subname;
		return   ">>$subname<<"   if ref $subname; # The subname maybe a coderef

		# The subs from DB::* are not placed here. Why???
		# A? Maybe they are placed after module loaded?
		return $DB::sub{ $subname };
	}



	sub subs {
		return keys %DB::sub   unless @_;

		my $re =  shift;
		return grep { /$re/ } keys %DB::sub;
	}



	sub frames {
		my $level =  shift;

		if( defined $level ) {
			# https://rt.perl.org/Public/Bug/Display.html?id=126872#txn-1380132
			# Note that we should ignore our frame, so +1
			my @frame =  caller( $level +1 );
			return ( [ @DB::args ], @frame );
		}


		_all_frames()   if $options{ _all_frames };


		# For uninitialized values in frames
		# $wantarray is undefined in void context, for example
		BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }

		my @frames;
		$level =  0;
		local $" =  ' -';

		# The $ext_call is an internal variable of DB:: module. If it is true
		# then we know that debugger frames are exists. In other case no sense
		# to check callstask for frames generated by debugger subs
		if( $ext_call ) {

			my $found =  0;
			# Skip debugger frames from stacktrace
			while( my @frame =  caller($level++) ) {
				# print "DBGF: @frame[0..3,5]\n"        if $options{ dbg_frames };
				push @frames, [ 'D', undef, @frame]   if $options{ dbg_frames };

				if( $frame[3] eq 'DB::trace_subs' ) {
					$found =  1;
					# my $args =  [ @DB::args ];
					my @gframe =  caller($level);
					if( @gframe  &&  $gframe[ 3 ] eq 'DB::goto' ) {
						# print "DBGF: @gframe[0..3,5]\n"       if $options{ dbg_frames };
						push @frames, [ 'D', undef, @gframe]   if $options{ dbg_frames };
						$level++;
					}
					else {
						# Because there is no DB::goto frame in stack
						# we are sure that the @DB::goto_frames will not contain
						# goto frames also. But only one initial sub frame
						$level--;
						# use Data::Dump qw/ pp /;
						# print pp \@DB::goto_frames, \@gframe; print "<<<<<<<\n";

						# $frame[3] =  $DB::goto_frames[0][3];
						# push @frames, [ $DB::goto_frames[0][5], $args, @frame ];
					}

					last;
				}

				if( $frame[3] eq 'DB::DB' ) {
					$found =  1;
					last;
				};
			}

			# We can not make $DB::ext_call variable private because we use localization
			# In theory someone may change the $DB::ext_call from outside
			# Therefore we prevent us from empty results when debugger frames
			# not exist at the stack
			$level =  0   unless $found;
		}

		my $count =  $options{ frames };
		my $ogf =  my $gf =  \@DB::goto_frames;
		while( $count  &&  (my @frame =  caller( $level++ )) ) {
			# The call to DB::trace_subs replaces right sub name of last call
			# We fix that here:
			$frame[3] =  $goto_frames[-1][3]
				if $count == $options{ frames }  && $frame[3] eq 'DB::trace_subs';

			my $args =  [ @DB::args ];
			if( $options{ trace_goto }
				&& $gf->[0][0] eq $frame[0]
				&& $gf->[0][1] eq $frame[1]
				&& $gf->[0][2] == $frame[2]
			) {
				$frame[3] =  $gf->[0][3];
				push @frames, [ $_->[5], $args, @$_[0..3] ]   for @$gf[ reverse 1..$#$gf ];
				$ogf =  $gf;
				$gf  =  $gf->[0][4];
			}

			push @frames, [ $ogf->[0][5], $args, @frame ];
		} continue {
			$count--;
		}


		return @frames;
	}


	# TODO: implement $DB::options{ trace_internals }
	sub mcall {
		$ext_call--; # $ext_call++ before mcall prevents reenterance to DB::sub

		# Any subroutine call invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite DB::sub reentrance manually. One way to compete this:
		# my $stub = sub { &$DB::sub };
		# local *DB::sub =  *DB::sub; *DB::sub =  $stub;
		# Another:
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call


		my $method =  shift;
		my $context =  $_[0];
		my $sub =  $context->can( $method );

		$sub->( @_ );

	}



	sub scall {
		$ext_call--; # $ext_call++ before scall prevents reenterance to DB::sub

		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call

		return shift->( @_[ 1..$#_ ] );

		# my $method =  shift;
		# my $context =  shift;
		# &{ "$context::$method" }( @_ );
	}
} # end of provided DB::API





my %RT_options;
sub import { # NOTE: The import is called at CT yet
	my $class =  shift;

	if( $_[0]  and  $_[0] eq 'options' ) {
		my %params =  @_;
		@RT_options{ keys %{ $params{ options } } } =  values %{ $params{ options } };
	}
	else {
		for( @_ ) {
			if( /^(\w+)=([\w\d]+)/ ) {
				$RT_options{ $1 } =  $2;
			}
			else {
				$RT_options{ $_ } =  1;
			}
		}
	}


	# if we set trace_load we want to see which modules are used in main::
	# So we apply this just before main:: is compiled but after debugger is loaded
	$DB::options{ trace_load } =  $RT_options{ trace_load }
		if defined $RT_options{ trace_load };


	# The RT options are applied after 'main::' is loaded
	$RT_options{ trace_goto } //=  1;
}


# We define posponed/sub as soon as possible to be able watch whole process
sub postponed {
	if( $options{ trace_load } ) {
		$ext_call++; mcall( 'trace_load', $DB::dbg, @_ );
	}

	# RT options applied after main program is loaded
	if( $_[0] eq "*main::_<$0" ) {
		my @keys =  keys %RT_options;
		@DB::options{ @keys } =  @RT_options{ @keys };
		$ext_call++; scall( \&applyOptions );
	}
}



# TODO: implement: on_enter, on_leave, on_compile
sub DB {
	init();

	print $DB::OUT "DB::DB called; s:$DB::single t:$DB::trace\n"   if $DB::options{ _debug };
	if( $DB::options{ _debug } ) {
		$ext_call++; scall( $DB::commands->{ T } );
	}

	do{ $ext_call++; mcall( 'trace_line', $DB::dbg ); }   if $DB::trace;

	my $traps =  DB::traps();
	if( exists $traps->{ $DB::line } ) {
		print $DB::OUT "Meet breakpoint $DB::file:$DB::line\n"   if $DB::options{ _debug };

		# NOTE: the stop events are not exclusive so we can not use elsif
		my $stop =  0;
		my $trap =  $traps->{ $DB::line };

		# Stop on watch expression
		if( exists $trap->{ watches } ) {
			# Calculate new values for watch expressions
			for my $watch_item ( @{ $trap->{ watches } } ) {
				$watch_item->{ old } =  $watch_item->{ new } // [ undef ];
				$watch_item->{ new } =  [ DB::eval( $watch_item->{ expr } ) ];
			}

			$ext_call++;
			# The 'watch' method should compare 'old' and 'new' values and return
			# true value if they are differ. Additionaly it may print to $DB::OUT
			# to show comparison results
			$stop ||=  mcall( 'watch', $DB::dbg, $trap->{ watches } );
		}

		# Stop if temporary breakpoint
		if( exists $trap->{ tmp } ) {
			# Delete temporary breakpoint
			delete $trap->{ tmp };
			unless( keys %$trap ) {
				$traps->{ $DB::line } =  0;
				delete $traps->{ $DB::line };
			}

			$stop ||=  1;
		}

		# Stop if breakpoint condition evaluated to true value
		if( exists $trap->{ condition }  &&  DB::eval( $trap->{ condition } ) ) {
			$stop ||=  1;
		}


		return   unless $stop;


		# TODO: Implement on_stop event
	}
	# We ensure here that we stopped by $DB::trace and not any of:
	# trap, single, signal
	elsif( $DB::trace  &&  !$DB::single  &&  !$DB::signal ) {
		return;
	}
	# TODO: elseif $DB::signal


	print $DB::OUT "Stopped\n"   if $DB::options{ _debug };

	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect
	# Actually to make things same we should call 'scall' here, despite on
	# $DB::single has no effect

	$DB::dbg->bbreak();
	1 while( defined interact() );
	$DB::dbg->abreak();
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	# Commented out because of:
	# https://rt.perl.org/Ticket/Display.html?id=127249
	# die ">$DB::file< ne >" .file( $DB::file ) ."<"
	# 	if $DB::file ne file( $DB::file );
}



# TODO: remove clever things out of core. This modules should implement
# only interface features
sub interact {
	# interact() should return defined value to keep interaction
	if( my $str =  $DB::dbg->interact( @_ ) ) {
		my $result =  $DB::dbg->process( $str );
		return   unless defined $result;
		return $result   if $result;


		# else no such command exists the entered string will be evaluated
		# in __FILE__:__LINE__ context of script we are debugging
		print $DB::OUT DB::eval( $str );
		print $DB::OUT "ERROR: $@"   if $@;

		# WORKAROUND: https://rt.cpan.org/Public/Bug/Display.html?id=110847
		print $DB::OUT "\n";
	}

	return;
}



sub trace_subs {
	my $last_frames =  $_[0] ne 'G'?
		$DB::stack[ -1 ]{ goto_frames }:
		undef;

	# TODO: implement testcase
	# We we run script in NonStop mode the $DB::package/file/line are not updated
	# because of &DB::DB is not called. If we update them here the GOTO frames
	# will get more actual info about that from which place the GOTO was done
	# $DB::package/file/line will be more closer to that place

	# TODO: check goto context, args, flags etc
	# [ (caller(1))[0..2], $DB::sub, $last_frames ];
	# http://stackoverflow.com/questions/34595192/how-to-fix-the-dbgoto-frame
	# WORKAROUND: for broken frame. Here we are trying to be closer to goto call
	# Most actual info we get when we trace script step-by-step so these vars
	# has sharp last opcode location.
	( $DB::package, $DB::file, $DB::line ) =  (caller(0))[0..2]
		if $_[0] ne 'G';

	push @DB::goto_frames,
		[ $DB::package, $DB::file, $DB::line, $DB::sub, $last_frames, $_[0] ];

	if( $options{ trace_subs } ) {
		$ext_call++; mcall( 'trace_subs', $DB::dbg, @_ );
	}
}



# TODO: Before run the programm we could deparse sources and insert some code
# in the place of 'goto'. This code may save __FILE__:__LINE__ into DB::
sub goto {
	return   unless $options{ trace_goto };
	return   if $ext_call;

	# TODO: implement testcase
	# sub t1{} sub t2{ goto &t1; #n } sub t3{ t2() } t3() #b 2;go;
	$DB::single =  0   if $DB::single & 2;
	trace_subs( 'G' );
};


# my $x = 0;
# use Data::Dump qw/ pp /;
use Hook::Scope;
sub sub_returns {
	# $ext_call++; scall( sub{
	# 	if( $x++ > 0 ) { # SEGFAULT when $x == 0 (run tests)
	# 		print $DB::OUT pp( \@DB::stack, \@DB::goto_frames );
	# 	}
	# });

	my $last =  pop @DB::stack;
	if( $DB::options{ _debug } ) {
		print $DB::OUT "Returning from " .$last->{ sub } ." to level ". @DB::stack ."\n";
		print $DB::OUT "DB::single state changed " . $DB::single ."->" .$last->{ single };
		print $DB::OUT "\n";
	}

	# The current FILE:LINE is the subroutine call place.
	# That is the first frame in the @DB::goto_frames, which is recorded at
	# 'trace_subs' by calling 'caller' like DB::DB does. You may read code as:
	# The point this sub was called from is: (--the sub we are returning from)
	( $DB::package, $DB::file, $DB::line ) =  @{ $DB::goto_frames[0] }[0..2];

	@DB::goto_frames =  @{ $last->{ goto_frames } };

	$DB::single =  $last->{ single };
}


# The sub is installed at compile time as soon as the body has been parsed
sub sub {
	if( $ext_call  ||  $DB::sub eq 'DB::sub_returns' ) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub
	}
	print $DB::OUT "DB::sub called; $DB::sub -- $DB::single\n"   if $DB::options{ _debug };


	# manual localization
	Hook::Scope::POST( \&sub_returns );
	# TODO: implement testcase
	# after retruning from level 1 to 0 the @DB::stack should be empty
	push @DB::stack, {
		single      =>  $DB::single,
		sub         =>  $DB::sub,
		goto_frames =>  [ @DB::goto_frames ],
	};

	@DB::goto_frames =  ();

	trace_subs( 'C' );

	$DB::single =  0   if $DB::single & 2;
	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub   if !$options{ trace_returns };


		if( wantarray ) {                             # list context
			my @ret =  &$DB::sub;
			$ext_call++; mcall( 'trace_returns', $DB::dbg, @ret );
			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			my $ret =  &$DB::sub;
			$ext_call++; mcall( 'trace_returns', $DB::dbg, $ret );
			return $ret;
		}
		else {                                        # void context
			&$DB::sub;
			$ext_call++; mcall( 'trace_returns', $DB::dbg );
			return;
		}
	}


	die "This should be reached never";
	#NOTICE: This reached when someone leaves sub by 'next/last'
	#Then 'return' is not called at all???
};



sub lsub : lvalue {
	if( $ext_call ) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } };
		return &$DB::sub
	}


	# manual localization
	Hook::Scope::POST( \&sub_returns );
	push @DB::stack, {
		single      =>  $DB::single,
		sub         =>  $DB::sub,
		goto_frames =>  [ @DB::goto_frames ],
	};

	@DB::goto_frames =  ();


	# HERE TOO client's code 'caller' return wrong info
	trace_subs( 'L' );


	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub;
	}
};



# It is better to load modules at the end of DB::
# because of they will be visible to 'trace_load'
use Devel::DebugHooks::Commands;
BEGIN {
	$DB::dbg->init();
}



1;

__END__

Describe what is used by perl internals from DB:: at compile time
${ "::_<$filename" } - $filename
@{ "::_<$filename" } - source lines. Line in compare to 0 shows trapnessability
%{ "::_<$filename" } - traps keyed by line number ***
$DB::sub - the current sub
%DB::sub - the location of sub definition
@DB::args - ref to the @_ at the given level at caller(N)
if the sub returns the @DB::args becomes dirty and we can not access its values
&DB::goto, &DB::sub, &DB::lsub, &DB::postponed - called at appropriate events
$^P - flags to control behaviour
$DB::postponed{subname} - trace sub loads        ***
$DB::trace, $DB::single, $DB::signal - controls if the program should break

initialization steps: rc -> env


goto implicitly changes the value of $DB::sub

At compile time $DB::single is 0

Which data is preserved by forth bit of $^P?

How to debug lvalue subs?

The DOC must describe that DB::sub should have :lvalue attribute
if DB::lsub is not defined. Whithout that the:
'falling back to &DB::sub (args).' is not possible



Can not control what value is assigned to lvalue sub


+
if sub does not exists lsub is not called at all

+
The caller behaves differently in lsub in compare to sub
http://paste.scsys.co.uk/502493
http://paste.scsys.co.uk/502494

no description/link for the $DEBUGGING variable in perlvar
>>perl -Dxxx command described in perlrun

Why the 'DB::' namespace is exluded from loading subs process?
whereas 'DB::postpone' is works fine for whole module
BEGIN {
	$DB::postponed{ 'DB::DB' } =  1;
} # The DB::postpone( 'DB::DB' ) is not called



+
Why the DB::DB is called twice for:
print "@{[ (caller(0))[0..2] ]}\n";
but only one for this:
print sb();
A: It is called once for caller(0) and second for whole line.
It is called once for each statement at line, maybe.


+
use should have args. and the caller called from DB:: namespace should set @DB::args
at compile time 'caller' also does not fill @DB::args
BEGIN {
	print caller, @DB::args
}
A: Try, to ensure the DB::args used after the call ot caller
BEGIN {
	@caller =  caller
	print @caller, @DB::args
}



How 'the first non-DB piece of code' is calculated for the 'eval'?



#BUG? I can ${ '!@#$' } =  3, but can not my ${ '!@#$' }


BUG?
The localization of $DB::single works fine, but the reference to it does not work:
	{
		$DB::single =  7; my $x =  \$DB::single;
		print "Before: ". \$DB::single ." <<$x $$x\n";
		local $DB::single =  0;
		print "After: ". \$DB::single ." <<$x $$x\n";
	}

The output:
Before: SCALAR(0x10f8310) <<SCALAR(0x10f8310) 7
After: SCALAR(0x110cbc8) <<SCALAR(0x10f8310) 0

Where as works fine:
	{
		$DB::z =  7; my $x =  \$DB::z;
		print "Before: ". \$DB::z ." <<$x $$x\n";
		local $DB::z =  0;
		print "After: ". \$DB::z ." <<$x $$x\n";
	}
The output:
Before: SCALAR(0x134d398) <<SCALAR(0x134d398) 7
After: SCALAR(0x1239bc8) <<SCALAR(0x134d398) 7

We see that in *first* example the new variable is created: The new address of $DB::single is SCALAR(0x110cbc8)
but when assigning to $DB::single the value by old reference (SCALAR(0x10f8310) changed too.
In *second* example we see that addressing works in same manner, but value 7 is preserved as expected.

Why the value of $DB::single is not preserved?

	# my $y =  \$DB::single;
	# # Can not use weaken. See error at 'reports/readline' file
	# use Scalar::Util 'weaken';
	# weaken $y;
	# Because of $DB::single magic we can not access to old value by reference
	# The localization is broken if we save a reference to $DB::single
	# {
	# 	my $x =  $DB::single;
	# 	print "Before: ". \$DB::single ." <<$DB::single $x >$y $$y\n"; # $$x == 0
	# 	local $DB::single =  $DB::single +1;
	# 	print "After: ". \$DB::single ." <<$DB::single $x >$y $$y\n";  # $$x == 1, not 0
	# }
	# print "OUT: ". \$DB::single ." <<$DB::single - $x - $$x >$y\n";

	# {
	# 	print "BEFORE: $DB::single\n";
	# 	local $DB::single =  7;
	# 	print "AFTER $DB::single\n";
	# }
	# print "OUT $DB::single\n";

	# BUG: The perl goes tracing if you uncomment this
	# { local $DB::trace =  1; }
	# # But it shows us the value 0 but internally it is 1
	# die $DB::trace   if $DB::trace != 0;



sub sub {
	...
	# BUG: without +0 the localized value is broken
	local $DB::single =  ($DB::single & 2) ? 0 : $DB::single+0;
