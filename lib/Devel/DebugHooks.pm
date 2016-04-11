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
# Also do not forget to 'push @ISA, "YourModule"' if you set these DB:: options at
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



# This sub is called for each DB::DB call when $DB::trace is true
sub trace_line {
	print "$DB::line\n";
}



sub watch {
	my $self =  shift;
	my( $watches ) =  @_;


	my $changed =  0;
	my $smart_match =  eval 'sub{ @{ $_[0] } ~~ @{ $_[1] } }';
	for my $item ( @$watches ) {
		unless( $smart_match->( $item->{ old }, $item->{ new } ) ) {
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



# Q: May this unit pull other units so we will not be able to see loading process?
# A: No, this will be done at run time. Until that trace_load will be visible
eval 'require ' .$DB::options{ cmd_processor }; die $@   if $@;
sub process {
	BEGIN{ 'strict'->unimport( 'refs' )   if $DB::options{ s } }
	# TODO: if we set trap on sub that loaded at CT, this will FAIL
	# move require here
	&{ $DB::options{ cmd_processor } .'::process' }( @_ );
}



# NOTICE: &DB::sub is not called because of DB::namespace
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

package
	x;

sub x { # This is 'invader' :)
	# When we returns from this sub the $DB::single is restored at 'DB::sub_returns'
	$DB::stack[-1]{ single } =  1   if !@_  ||  $_[0];
	# TODO: Allow to disable trap
}

# NOTICE: x::x; does not work at the end of sub

package
	X;
sub X {
	local $^D |= (1<<30);
	$DB::stack[-1]{ single } =  1;
	$DB::single =  1;
	1;
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
	my( $count ) =  @_;
	$count //=  -1; # infinite

	my $lvl =  0;
	# $x  &&  $y = 3 in this case '=' op precedence should be higher then &&
	while( $count--  &&  (my @frame =  caller( $lvl )) ) {
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
# ${ ::_<filename }  # maintained at 'file' and 'sources'
# @{ ::_<filename }  # maintained at 'source' and 'can_break'
# %{ ::_<filename }  # maintained at 'traps'
# $DB::single
# $DB::signal
# $DB::trace
# $DB::sub   # NOTICE: this maybe the reference to sub, not just the name of it
# %DB::sub   # maintained at 'location' and 'subs'
# %DB::postponed
# @DB::args  # maintained at 'frames'

# Perl sets up $DB::single to 1 after the 'script.pl' is compiled, so we are able
# to debug it from first OP. We can disable this feature through NonStop option.

our $dbg;            # debugger object/class
our $package;        # current package
our $file;           # current file
our $line;           # current line number
our $ext_call;       # keep silent at DB::sub/lsub while do external call from DB::*
our @goto_frames;    # save sequence of places where nested gotos are called
our $commands;       # hash of commands to interact user with debugger
our @stack;          # array of hashes that keeps aliases of DB::'s ours for current frame
                     # This allows us to spy the DB::'s values for a given frame
our $ddlvl;          # Level of debugger debugging
# TODO? does it better to implement TTY object?
our $IN;
our $OUT;
our %options;
our $interaction;    # True if we interact with dbg client
our %stop_in_sub;    # In this hash the key is a sub name we want to stop on
                     # maintained at 'trace_subs'



# Do DB:: configuration stuff here
BEGIN {
	$IN                        //= \*STDIN;
	#TODO: cache output until debugger is connected
	$OUT                       //= \*STDOUT;

	$options{ _debug }         //=  0;
	$options{ dd }             //=  0;         # controls debugger debugging
	$options{ ddd }            //=  0;         # print debug info

	$options{ s }              //=  0;         # compile time option
	$options{ w }              //=  0;         # compile time option
	# TODO: camelize options. Q: Why?
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
# otherwise sub calls and module loading will not be tracked
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
	$DB::ext_call //=  0;
	$DB::ddlvl    //=  0;
	$DB::interaction //=  0;
	# TODO: set $DB::trace at CT
	applyOptions();
}



# Hooks to Perl's internals should be first.
# Because debugger or its descendants may call them at compile time
{
	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }

		# Returns TRUE if $filename was compiled/evaled
		# The file is evaled if it looks like (eval 34)
		# But this may be changed by #file:line. See ??? for info
		sub file {
			my $filename =  shift // $DB::file;

			unless( exists ${ 'main::' }{ "_<$filename" } ) {
				warn "File '$filename' is not compiled yet";

				return;
			}

			return ${ "::_<$filename" };
		}



		# Returns source for $filename
		sub source {
			my $filename =  shift // $DB::file;

			return   unless file( $filename );

			return \@{ "::_<$filename" };
		}



		# Returns list of compiled files/evaled strings
		# The $filename for evaled strings looks like (eval 34)
		sub sources {
			return grep{ s/^_<//r } keys %{ 'main::' }; #/
		}



		# Returns hashref of traps for $filename keyed by $line
		sub traps {
			my $filename =  shift // $DB::file;

			return   unless file( $filename );

			# Keep list of $filenames we perhaps manipulate traps
			$DB::_tfiles->{ $filename } =  1;

			return \%{ "::_<$filename" };
		}



		# Returns TRUE if we can set trap for $file:line
		sub can_break {
			my( $file, $line ) =  @_;

			($file, $line) =  split ':', $file
				unless defined $line;

			return   unless file( $file );

			# TODO: testcase for negative lines
			return ($line<0?-$line-1:$line) <= $#{ "::_<$file" }
				&& ${ "::_<$file" }[ $line ] != 0;

			# http://perldoc.perl.org/perldebguts.html#Debugger-Internals
			# Values in this array are magical in numeric context:
			# they compare equal to zero only if the line is not breakable.
		}
	}



	# We put code here to execute it only once
	my $usercontext =  <<'	CODE' =~ s#^\t\t##rgm;
		BEGIN{
			( $^H, ${^WARNING_BITS} ) =  @DB::context[1..2];
			my $hr =  $DB::context[3];
			%^H =  %$hr   if $hr;
		}
	CODE
	# http://perldoc.perl.org/functions/eval.html
	# We may define eval in other package if we want to place eval into other
	# namespace. It will still "doesn't see the usual surrounding lexical scope"
	# because "it is defined in the DB package"
	# sub My::eval {
	sub eval {
		my( $expr ) =  @_;
		# BUG: PadWalker does not show DB::eval's lexicals
		# Q? It is better that PadWalker return undef instead of warn when out of level

		local $^D;

		local @_ =  @{ $DB::context[0] };
		eval "$usercontext; package $DB::package;\n$expr";
		#NOTICE: perl implicitly add semicolon at the end of expression
		#HOWTO reproduce. Run command: X::X;1+2
	}



	# Returns the location where $subname is defined in the form:
	# filename:startline-endline
	sub location {
		my $subname =  shift;

		return   unless $subname;
		return   ">>$subname<<"   if ref $subname; # The subname maybe a coderef

		# The subs from DB::* are not placed here. Why???
		# A? Maybe they are placed after module loaded?
		return $DB::sub{ $subname };
	}



	# Returns list of all defined not ANON subs.
	# We may limit the list by supplying regex
	sub subs {
		return keys %DB::sub   unless @_;

		my $re =  shift;
		return grep { /$re/ } keys %DB::sub;
	}



	# Returns caller frame info with arguments at given level
	# or all call stack with goto frames
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
				push @frames, [ 'D', [ @DB::args ], @frame]   if $options{ dbg_frames };

				if( $frame[3] eq 'DB::trace_subs' ) {
					$found =  1;
					# my $args =  [ @DB::args ];
					my @gframe =  caller($level);
					if( @gframe  &&  $gframe[ 3 ] eq 'DB::goto' ) {
						# print "DBGF: @gframe[0..3,5]\n"       if $options{ dbg_frames };
						# TODO: implement testcase: 'T' should show args for sub calls
						push @frames, [ 'D', [ @DB::args ], @gframe]   if $options{ dbg_frames };
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
		my $method =  shift;
		my $context =  $_[0];
		my $sub =  $context->can( $method );

		print "mcall ${context}->$method\n"   if $DB::options{ ddd };
		scall( $sub, @_ );
	}



use Guard;

	sub scall {

		# TODO: implement debugger debugging
		# local $^D |= (1<<30);
		my( $from, $f, $l, $sub );
		if( $DB::options{ ddd } ) {
			$lvl =  0;
			if( (caller 1)[3] eq 'DB::mcall' ) {
				$lvl++;
				$sub =  "$DB::args[1]::$DB::args[0]";
			}
			else {
				$sub =  $DB::_sub;
			}

			($f, $l) =  (caller $lvl)[1,2];
			$f =~ s".*?([^/]+)$"$1";
			$from =  (caller $lvl+1)[3];

			print $DB::OUT "scall from $from($f:$l) --> $sub\n"
		}


		$ext_call--; # $ext_call++ before scall prevents reenterance to DB::sub
		# FIX: http://perldoc.perl.org/perldebguts.html#Debugger-Internals
		# (This doesn't happen if the subroutine -was compiled in the DB package.)
		# ...was called and compiled in the DB package

		# Any subroutine call invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite DB::sub reentrance manually. One way to compete this:
		# my $stub = sub { &$DB::sub };
		# local *DB::sub =  *DB::sub; *DB::sub =  $stub;
		# Another:
		local $ext_call      =  $ext_call +1;


		# Manual localization
		my $osingle =  $DB::single;
		scope_guard {
			spy( $osingle );

			print $DB::OUT "scall back $from($f:$l) <-- $sub\n"
				if $DB::options{ ddd };
		};

		scope_guard {
			print $DB::OUT "OUT DEBUGGER  <<<<<<<<<<<<<<<<<<<<<< \n"
				if $DB::options{ ddd };
		}   if $DB::options{ dd };

		# TODO: testcase 'a 3 $DB::options{ dd } = 1'
		local $ddlvl          =  $ddlvl            if $DB::options{ dd };
		local $options{ dd }  =  $options{ dd }    if $DB::options{ dd };
		local $options{ ddd } =  $options{ ddd }   if $DB::options{ dd };


		if( $DB::options{ dd } ) {
			spy( 1 );

			print $DB::OUT "IN  DEBUGGER  >>>>>>>>>>>>>>>>>>>>>> \n"
				if $DB::options{ ddd };

			$DB::ddlvl++;
			$DB::options{ dd  } =  0;
			$DB::options{ ddd } =  0;
			$ext_call   =  0;
		}
		else {
			spy( 0 ); # Prevent debugging for next call # THIS CONTROLS NESTING
		}

		return shift->( @_[ 1..$#_ ] );

		# my $method =  shift;
		# my $context =  shift;
		# &{ "$context::$method" }( @_ );
	}



	sub save_context {
		@DB::context =  ( \@_, (caller 1)[8..10] );
	}



	sub restore_context {
	}



	my $x;
	sub spy {
		return $DB::single   unless @_;

		if( $DB::options{ ddd } ) {
			my($file, $line) =  (caller 0)[1,2];
			$file =~ s'.*?([^/]+)$'$1'e;
			print $DB::OUT "!! DB::single state changed $DB::single -> $_[0]"
				." at $file:$line\n"
				unless $x;
		}

		$DB::single =  $_[0]   unless $x;
		$x =  $_[1];
	}
} # end of provided DB::API





my %RT_options;
sub import { # NOTE: The import is called at CT yet
	# CT of callers module. For this one it is RT
	my $class =  shift;

	if( $_[0]  and  $_[0] eq 'options' ) {
		my %params =  @_; # FIX? the $_[1] should be HASHREF; $options = @_[1]
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

	# FIX? should I call applyOptions here and not at trace_load
	# What is the benefit?
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

	&save_context;

	print $DB::OUT "DB::DB called; e:$DB::ext_call n:$DB::ddlvl s:$DB::single t:$DB::trace <-- $file:$line\n"
		."    cursor(DB) => $DB::package, $DB::file, $DB::line\n"
		if $DB::options{ _debug } || $DB::options{ ddd };
	if( $DB::options{ _debug } ) {
		$ext_call++; scall( $DB::commands->{ T } );
	}

	do{ $ext_call++; mcall( 'trace_line', $DB::dbg ); }   if $DB::trace;
	return   if $DB::steps_left && --$DB::steps_left;

	my $stop =  0;
	my $traps =  DB::traps();
	if( my $trap =  $traps->{ $DB::line } ) {
		print $DB::OUT "Meet breakpoint $DB::file:$DB::line\n"   if $DB::options{ _debug };
		# NOTE: the stop events are not exclusive so we can not use elsif
		# FIX: rename: action -> actions
		if( exists $trap->{ action } ) {
			# Run all actions
			for( @{ $trap->{ action } } ) {
				# NOTICE: if we do not use scall the $DB::file:$DB::line is broken
				$ext_call++; scall( \&process, $_ );
			}

			# Actions do not stop execution
			$stop ||=  0;
		}

		# Stop on watch expression
		if( exists $trap->{ watches } ) {
			# Calculate new values for watch expressions
			for my $watch_item ( @{ $trap->{ watches } } ) {
				# FIX: why we use [ undef ]
				$watch_item->{ old } =  $watch_item->{ new } // [ undef ];
				$watch_item->{ new } =  [ DB::eval( $watch_item->{ expr } ) ];
			}

			$ext_call++;
			# The 'watch' method should compare 'old' and 'new' values and return
			# true value if they are differ. Additionaly it may print to $DB::OUT
			# to show comparison results
			$stop ||=  mcall( 'watch', $DB::dbg, $trap->{ watches } );
		}

		# Stop if onetime trap
		if( exists $trap->{ onetime } ) {
			# Delete temporary breakpoint
			delete $trap->{ onetime };

			# Remove info about trap from perl internals if no common traps left
			unless( keys %$trap ) {
				# Just trap deleting does not help. We should signal internals
				# about that we should not stop here anymore
				$traps->{ $DB::line } =  0; # Perl does not do this automanically. Why?
				delete $traps->{ $DB::line };
			}

			$stop ||=  1;
		}

		# Stop if trap is not disabled and condition evaluated to TRUE value
		if( !exists $trap->{ disabled }
			&&  exists $trap->{ condition }  &&  DB::eval( $trap->{ condition } )
		) {
			$stop ||=  1;
		}
	}
	# We ensure here that we stopped by $DB::trace and not any of:
	# trap, single, signal
	elsif( $DB::trace  &&  !$DB::single  &&  !$DB::signal ) {
		# FIX? Actually the '$DB::trace' were processed when we do
		# mcall( 'trace_line', $DB::dbg )
		# So this condition block is pretty useless
		$stop ||=  0;
	}
	# TODO: elseif $DB::signal

	return   unless $stop || $DB::single || $DB::signal;
	# Stop if required or we are in step-by-step mode

	# TODO: Implement on_stop event
	print $DB::OUT "Stopped\n"   if $DB::options{ _debug };


	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect
	# WRONG!!! It has. See mcall/scall

	print "\n\ne:$DB::ext_call n:$DB::ddlvl s:$DB::single\n\n"
		if $DB::options{ ddd };
	$ext_call++; mcall( 'bbreak', $DB::dbg );
	1 while( defined interact() );
	$ext_call++; mcall( 'abreak', $DB::dbg );
}



sub init {
	# For each step at client's script we should update current position
	# Also we should do same thing at &DB::sub
	( $DB::package, $DB::file, $DB::line ) = caller(1);


	# Commented out because of:
	# https://rt.perl.org/Ticket/Display.html?id=127249
	# die ">$DB::file< ne >" .file( $DB::file ) ."<"
	# 	if $DB::file ne file( $DB::file );
}



# Get a string and process it.
sub process {
	my( $str ) =  @_;

	my @args =  ( $DB::dbg, $str );
	my $code =  $DB::dbg->can( 'process' );
	PROCESS: {
		# 0 means : no command found so 'eval( $str )' and keep interaction
		# TRUE    : command found, keep interaction
		# HASHREF : eval given { expr } and pass results to { code }
		# negative: something wrong happened while running the command
		my $result =  $code->( @args );
		return   unless defined $result;
		if( $result ) {
			return $result   unless ref $result  &&  ref $result eq 'HASH';

			$code =  $result->{ code };
			@args =  DB::eval( $result->{ expr } );
			redo PROCESS;
		}
	}

	# else no such command exists the entered string will be evaluated
	# in __FILE__:__LINE__ context of script we are debugging
	print $DB::OUT ( DB::eval( $str ) // 'undef' ) ."\n";
	print $DB::OUT "ERROR: $@"   if $@;

	# WORKAROUND: https://rt.cpan.org/Public/Bug/Display.html?id=110847
	# print $DB::OUT "\n";

	return 0;
}



# TODO: remove clever things out of core. This modules should implement
# only interface features
sub interact {
	return   if @_  &&  $DB::interaction;

	local $DB::interaction =  $DB::interaction +1;

	$ext_call++;
	if( my $str =  mcall( 'interact', $DB::dbg, @_ ) ) {
		return process( $str );
	}

	return;
}



# TODO: Before run the programm we could deparse sources and insert some code
# in the place of 'goto'. This code may save __FILE__:__LINE__ into DB::
sub goto {
	#FIX: IT: when trace_goto disabled we can not step over goto
	return   unless $options{ trace_goto };
	return   if $ext_call;


	spy( 0 )   if $DB::single & 2;
	my $old =  $DB::single;
	$ext_call++; scall( \&DB::Tools::push_frame, $old, 'G' );
};



{ package DB::Tools;
# my $x = 0;
# use Data::Dump qw/ pp /;
sub test {
	1;
	2;
}

sub pop_frame {
	# $ext_call++; scall( sub{
	# 	if( $x++ > 0 ) { # SEGFAULT when $x == 0 (run tests)
	# 		print $DB::OUT pp( \@DB::stack, \@DB::goto_frames );
	# 	}
	# });

	my $last;
	do{ $last =  pop @DB::stack } while $last->{ type } eq 'G';
	print $DB::OUT "POP  FRAME <<<< e:$ext_call n:$ddlvl s:$DB::single  --  $last->{ sub }\n"
		. "    @{ $last->{ caller } }\n\n"
		if $DB::options{ ddd };
	if( $DB::options{ _debug } ) {
		print $DB::OUT "Returning from " .$last->{ sub } ." to level ". @DB::stack ."\n";
	}

	# The current FILE:LINE is the subroutine call place.
	# That is the first frame in the @DB::goto_frames, which is recorded at
	# 'trace_subs' by calling 'caller' like DB::DB does. You may read code as:
	# The point this sub was called from is: (--the sub we are returning from)
	# FIX: when the action exists at the line while running the 'n' or 's' command
	# it will break $DB::file, $DB::line. See description for action
	( $DB::package, $DB::file, $DB::line ) =  @{ $last->{ caller } };

	@DB::goto_frames =  @{ $last->{ goto_frames } };

	DB::spy( $last->{ single } );
}



sub push_frame {
	# this two lines exists for testing purpose
	test();
	3;

	print $DB::OUT "PUSH FRAME >>>>  e:$ext_call n:$ddlvl s:$DB::single  --  $DB::sub\n"
		if $DB::options{ ddd };

	if( $_[1] ne 'G' ) {
		# http://stackoverflow.com/questions/34595192/how-to-fix-the-dbgoto-frame
		# WORKAROUND: for broken frame. Here we are trying to be closer to goto call
		# Most actual info we get when we trace script step-by-step at this case
		# those vars have sharp last opcode location.
		( $DB::package, $DB::file, $DB::line ) =  caller 2;
		print $DB::OUT "    cursor(PF) => $DB::package, $DB::file, $DB::line\n"
			if $DB::options{ ddd };

		push @DB::stack, {
			single      =>  $_[0],
			sub         =>  $DB::sub,
			caller      =>  [ $DB::package, $DB::file, $DB::line ],
			goto_frames =>  [ @DB::goto_frames ],
			type        =>  $_[1],
		};

		@DB::goto_frames =  ();
	}
	else {
		push @DB::goto_frames,
			[ $DB::package, $DB::file, $DB::line, $DB::sub, $_[1] ]
	}


	if( $options{ trace_subs } ) {
		$DB::dbg->trace_subs();
	}

	# Stop on the first OP in a given subroutine
	my $sis =  \%DB::stop_in_sub;
	DB::spy( 1, 1 )
		# First of all we check full match ...
		if $sis->{ $DB::sub }
		# ... then check not disabled partially matched subnames
		|| grep{ $sis->{ $_ }  &&  $DB::sub =~ m/$_$/ } keys %$sis;
		# TODO: implement condition to stop on
}
}



sub trace_returns {
	$ext_call++; mcall( 'trace_returns', $DB::dbg, @_ );
}



sub push_frame {
	$ext_call++; scall( \&DB::Tools::push_frame, @_ );

	if( $DB::options{ ddd } ) {
		print $DB::OUT "STACK:\n";
		print $DB::OUT '    ' .$_->{ single } .' ' .$_->{ sub }
			." -- @{ $_->{ caller } }\n"
			for @DB::stack;
		print $DB::OUT "Frame created for $DB::sub\n\n";
	}
}



# The sub is installed at compile time as soon as the body has been parsed
sub sub {
	$DB::_sub =  $DB::sub;
	print $DB::OUT "DB::sub called; e:$DB::ext_call n:$DB::ddlvl s:$DB::single  --  "
		.sub{ "$DB::sub <-- @{[ map{ s#.*?([^/]+)$#$1#r } (caller 0)[1,2] ]}" }->()
		."\n"
		if $DB::options{ ddd } && $DB::sub ne 'DB::can_break';

	if( $ext_call
		||  $DB::sub eq 'DB::spy'
	) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		# TODO: Here we may log internall subs call chain
		return &$DB::sub
	}

	if( $DB::sub eq 'DB::Tools::pop_frame' ) {
		$DB::single =  0   unless $DB::options{ dd };

		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub;
	}

	print $DB::OUT "DB::sub called; $DB::sub -- $DB::single\n"   if $DB::options{ _debug };


	# manual localization
	print $DB::OUT "\nCreating frame for $DB::sub\n"   if $DB::options{ ddd };
	scope_guard \&DB::Tools::pop_frame; # This should be first because we should
	# start to guard frame before any external call

	my $old =  $DB::single; # WORKAROUND FOR GLOBALS (see Guide)
	push_frame( $old, 'C' );

	sub{ spy( 0 ) }->()   if $DB::single & 2;

	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub   if !$options{ trace_returns };


		if( wantarray ) {                             # list context
			my @ret =  &$DB::sub;
			trace_returns( @ret );
			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			my $ret =  &$DB::sub;
			trace_returns( $ret );
			return $ret;
		}
		else {                                        # void context
			&$DB::sub;
			trace_returns;
			return;
		}
	}


	die "This should be reached never";
	#NOTICE: This reached when someone leaves sub by 'next/last'
	#Then 'return' is not called at all???
};



# FIX: debugger dies when lsub is not defined but the call is to an lvalue subroutine
# The perl may not "...fall back to &DB::sub (args)."
# http://perldoc.perl.org/perldebguts.html#Debugger-Internals
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

	spy( 0 )   if $DB::single & 2;
	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub;
	}
};



# It is better to load modules at the end of DB::
# because of they will be visible to 'trace_load'
use Devel::DebugHooks::Commands;
BEGIN {
	# NOTICE: it is useless to set breakpoints for not compiled files
	# TODO: spy module loading and set breakpoints
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


Breakpoint does not work for this when hash key is initialized
  b  x64:   my $hash = $c->stash->{'mojo.content'} ||= {};

#TODO: $X=(condition)

The debugger do not single step into sub called from string
