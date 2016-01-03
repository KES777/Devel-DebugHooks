package Devel::DebugHooks;

BEGIN {
	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
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


sub import {
	my $class =  shift;

	# NOTICE: If descendats has sub calls after calling to $self->SUPER::import
	# those calls will be traced by 'trace_subs'. Localize $ext_call to disable
	# that (see below)

	if( $_[0]  and  $_[0] eq 'options' ) {
		my %params =  @_;
		@DB::options{ keys %{ $params{ options } } } =  values %{ $params{ options } };
	}
	else {
		for( @_ ) {
			if( /^(\w+)=([\w\d]+)/ ) {
				$DB::options{ $1 } =  $2;
			}
			else {
				$DB::options{ $_ } =  1;
			}
		}
	}

	# Disable tracing internal call
	# TODO: implement $DB::options{ trace_internals }
	local $DB::ext_call =  $DB::ext_call +1;
	DB::applyOptions();

	# We set default here because setting it at DB::BEGIN block will cause us
	# see third party module's gotos. Settig option to 0 at DB::BEGIN will
	# confuse us here, because we do not know it is disabled at DB::BEGIN or
	# descendant module
	$DB::options{ trace_goto } //=  1;
}



sub trace_load {
	my $self =  shift;

	return "Loaded '@_'\n"
}


sub bbreak {
	my $info =  "\n" .' =' x30 ."$DB::ext_call\n";

	$info .=  "$DB::file:$DB::line    " .DB::source()->[ $DB::line ];

	return $info;
}



sub interact {
}



sub abreak {
}


sub trace_subs {
	my( $self, $t ) =  @_;

	BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }


	my $info = '';
	local $" =  ' -';
	my $gf =  \@DB::goto_frames;
	my $DB_sub =  $gf->[-1][3]; # the last goto frame hence it has the name of called sub
	my @frames =  DB::frames();
	for my $frame ( @frames ) {
		if(    $gf->[0][0] eq $frame->[1]
			&& $gf->[0][1] eq $frame->[2]
			&& $gf->[0][2] == $frame->[3]
		) {
			$frame->[4] =  $gf->[0][3];
			$info .=  "GOTO: @{ $_ }[0..3]\n"   for reverse @$gf[ 1..$#$gf ];
			$gf =  $gf->[0][4];
		}

		$info .=  "FROM: @{$frame}[1..4]\n";
	}

	my $context = $frames[0][6] ? 'list'
			: defined $frames[0][6] ? 'scalar' : 'void';

	$" =  ', ';
	my @args =  map { !defined $_ ? '&undef' : $_ } @{ $frames[0][0] };
	$info =
	    "\n" .' =' x15 ."\n"
	    ."DEEP: $DB::deep\n"
		."CNTX: $context\n"
	    ."${t}SUB: $DB_sub( @args )\n"
		# print "TEXT: " .DB::location( $DB::sub ) ."\n";
		# NOTICE: even before function call $DB::sub changes its value to DB::location
		# A: Because @_ keep the reference to args. So
		# 1. The reference to $DB::sub is saved into @_
		# 2. The DB::location is called
		# 3. The value of $DB::sub is changed to DB::location
		# 4. my( $sub ) =  @_; # Here is too late to get the orig value of $DB::sub
	    ."TEXT: " .DB::location( $DB_sub ) ."\n\n"
	    .$info;

	$info .=  ' =' x15 ."\n";

	return $info;
}



sub trace_returns {
	my $self =  shift;

	my $info;
	$info =  $DB::options{ trace_subs } ? '' : "\n" .' =' x15 ."\n";
	$info .= $DB::goto_frames[0][3] ." RETURNS:\n";

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

	print $self->SUPER::trace_load( @_ );
}

sub trace_subs {
	my $self =  shift;

	print $self->SUPER::trace_subs( @_ );
}

sub trace_returns {
	my $self =  shift;

	print $self->SUPER::trace_returns( @_ );
}

sub bbreak {
	my $self =  shift;

	print $self->SUPER::bbreak( @_ );
}


package    # hide the package from the PAUSE indexer
    DB;


# Used perl internal variables:
# ${ ::_<filename }
# @{ ::_<filename }
# %{ ::_<filename }
# $DB::single
# $DB::signal
# $DB::trace
# $DB::sub
# %DB::sub
# %DB::postponed

our $dbg;            # debugger object/class
our $package;        # current package
our $file;           # current file
our $line;           # current line number
our $deep;           # watch the calling stack depth
our $ext_call;       # keep silent at DB::sub/lsub while do external call from DB::*
our @goto_frames;    # save sequence of places where nested gotos are called
our $commands;       # hash of commands to interact user with debugger
our %options;



# Do DB:: configuration stuff here
BEGIN {
	$options{ s }              //=  0;         # compile time option
	$options{ w }              //=  0;         # compile time option
	$options{ orig_frames }    //=  0;         # compile time & runtime option
	$options{ frames }         //=  -1;        # compile time & runtime option
	$options{ dbg_frames }     //=  0;         # compile time & runtime option
	# The differece when we set option at compile time, we see module loadings
	# and compilation order whereas setting up it at run time we lack that info
	$options{ trace_load }     //=  0;         # compile time option
	$options{ trace_subs }     //=  0;         # compile time & runtime option
	$options{ trace_returns }  //=  0;

	#options{ store_branches } # TODO: draw code path
	$DB::postponed{ 'DB::DB' } =  1;

	#NOTE: we should always trace goto frames. Hiding them will prevent
	# us to complete our work - debugging.
	# But we still allow to control this behaviou at compiletime & runtime
	# $options{ trace_goto };    #see DH:import  # compile time & runtime option
	$^P |= 0x80;
}



# This sub is called twice: at compile time and before run time of 'main' package
sub applyOptions {
}

# $^P default values
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
	# http://perldoc.perl.org/warnings.html
	# The scope of the strict/warnings pragma is limited to the enclosing block.
	# But this not truth.
	# It is limited to the first enclosing block of the BEGIN block
}

BEGIN { # Initialization goes here
	# When we 'use Something' from this module the DB::sub is called at compile time
	# If we do not we can still init them when define
	$DB::deep     =  0;
	$DB::ext_call =  0;
	applyOptions();
}


# Hooks to Perl's internals should be first.
# Because debugger descendants may call them
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



		sub traps {
			my $filename =  shift // $DB::file;

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

		# The subs from DB::* are not placed here. Why???
		# A? Maybe they are placed after module loaded?
		return $DB::sub{ $subname } || ">>$subname<<";
	}



	sub subs {
		return keys %DB::sub   unless @_;

		my $re =  shift;
		return grep { /$re/ } keys %DB::sub;
	}



	sub frames {
		my $level =  shift;
		# Note that we should ignore our frame, so +1

		if( defined $level ) {
			# https://rt.perl.org/Public/Bug/Display.html?id=126872#txn-1380132
			my @frame =  caller( $level +1 );
			return ( [ @DB::args ], @frame );
		}

		if( $options{ _all_frames } ) {
			my $lvl =  0;
			while( my @frame =  caller( $lvl ) ) {
				print "ORIG: @frame[0..3,5]\n";
				$lvl++;
			}

			print "\n";
		}

		print "\n"   if $options{ orig_frames };

		$level =  0;
		local $" =  ' -';
		# The $ext_call is an internal variable of DB:: module. If it is true
		# then we know that debugger frames are exists. In other case no sense
		# to check callstask
		if( $ext_call ) {
			while( my @frame =  caller($level++) ) {
				if( $frame[3] eq 'DB::trace_subs' ) {
					my @gframe =  caller($level);
					if( @gframe  &&  $gframe[ 3 ] eq 'DB::goto' ) {
						print "DBGF: @frame[0..3]\n"    if $options{ dbg_frames };
						print "DBGF: @gframe[0..3]\n"   if $options{ dbg_frames };
						$level++;
					}
					else {
						$level--;
					}

					last;
				}

				print "DBGF: @frame[0..3]\n"   if $options{ dbg_frames };
			}
		}


		BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }

		my @frames;
		my $count =  $options{ frames };
		while( $count  &&  (my @frame =  caller( $level++ )) ) {
			print "$count -- @frame\n"   if $options{ orig_frames };
			push @frames, [ [ @DB::args ], @frame ];
		} continue {
			$count--;
		}

		print "\n", ' ^'x15   if $options{ orig_frames };

		return @frames;
	}
} # end of provided DB::API





# We define posponed/sub as soon as possible to be able watch whole process
sub postponed {
	if( $options{ trace_load } ) {
		local $ext_call =  $ext_call +1;
		$dbg->trace_load( @_ );
	}
}



sub DB {
	init();

	# Do not stop if breakpoint condition evaluated to false value
	return   if
		exists DB::traps->{ $DB::line }
		&& !DB::eval( DB::traps->{ $DB::line }{ condition } );


	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect

	$dbg->bbreak();

	# interact() should return defined value to keep interaction
	while( defined ( my $str =  $dbg->interact() ) ) {
		my( $cmd, $args ) =  $str =~ m/^([\w.]+)(?:\s+(.*))?$/;

		if( $cmd  and  exists $DB::commands->{ $cmd } ) {
			# The command also should return defined value to keep interaction
			if( defined $DB::commands->{ $cmd }( $args ) ) {
				next;
			}
			else {
				last;
			}
		}
		# else no such command exists the entered string will be evaluated
		# in context of current __FILE__:__LINE__ of a debugged script
		DB::eval( $str );
		warn "ERROR: $@"   if $@;

		# WORKAROUND: https://rt.cpan.org/Public/Bug/Display.html?id=110847
		print "\n";
	}

	$dbg->abreak();
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	die "'$DB::file' ne '" .file( $DB::file ) ."'"
		if $DB::file ne file( $DB::file );
}




sub trace_subs {
	if( $options{ trace_subs } ) {
		my $last_frames =  shift;
		push @DB::goto_frames,
			$DB::package?
				[ $DB::package, $DB::file, $DB::line, $DB::sub, $last_frames ]:
				[ (caller(0))[0..2], $DB::sub, $last_frames ];


		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually. One way to compete this:
		# my $stub = sub { &$DB::sub };
		# local *DB::sub =  *DB::sub; *DB::sub =  $stub;
		# Another:
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		$dbg->trace_subs( @_ );
	}
}



# HERE we get unexpected results about 'caller'
# EXPECTED: the line number where 'goto' called from

# 1 sub t { }
# 2 sub sb {
# 3    goto &t;  # << The DB::goto is called from here
# 4 }
# 5 sub sb( a => 3 )

# But caller called form DB::goto return next info:
# main - t3.pl - 5 - DB::goto - 1 -  -  -  - 256 -  -  -- >><<
# main - t3.pl - 5 - main::t - 1 - 1 -  -  - 256 -  -  -- >>a - 3<<
# Because the DB::goto is called as ordinary sub. So its call frame should be right
# I mean the (caller(0))[2] should be 3 instead of 5
#        the (caller(0))[5] shold be 1 instead of undef (The value of caller(1)[5])
# Becase @list = goto &sub is useless at any case


sub goto {
	return   unless $options{ trace_goto };
	return   if $ext_call;

	trace_subs( undef, 'G' );
};



# The sub is installed at compile time as soon as the body has been parsed
sub sub {
	if( $ext_call ) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub
	}

	my $root =  \@DB::goto_frames;
	local @DB::goto_frames;
	local $DB::deep =  $DB::deep +1;
	trace_subs( $root, 'C' );


	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		# BUG: without +0 the localized value is broken
		local $DB::single =  ($DB::single & 2) ? 0 : $DB::single+0;
		return &$DB::sub   if !$options{ trace_returns };


		if( wantarray ) {                             # list context
			local $DB::single =  ($DB::single & 2) ? 0 : $DB::single+0;
			my @ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			$DB::single =  0;
			$dbg->trace_returns( @ret );

			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			local $DB::single =  ($DB::single & 2) ? 0 : $DB::single+0;
			my $ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			$DB::single =  0;
			$dbg->trace_returns( $ret );

			return $ret;
		}
		else {                                        # void context
			local $DB::single =  ($DB::single & 2) ? 0 : $DB::single+0;
			&$DB::sub;

			local $ext_call   =  $ext_call +1;
			$DB::single =  0;
			$dbg->trace_returns();

			return;
		}
	}


	die "This should be reached never";
};



sub lsub : lvalue {
	if( $ext_call ) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } };
		return &$DB::sub
	}

	my $root =  \@DB::goto_frames;
	local @DB::goto_frames;
	# HERE TOO client's code 'caller' return wrong info
	trace_subs( $root, 'L' );
	local $DB::deep =  $DB::deep +1;


	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub;
	}
};



# It is better to load modules at the end of DB::
# because of they will be visible to 'trace_load'
use Devel::DebugHooks::Commands;



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
