package Devel::DebugHooks;

BEGIN {
	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
}

our $VERSION =  '0.01';


BEGIN {
	$DB::dbg //=  'Devel::DebugHooks';
}


sub import {
	my $class =  shift;
	my %params =  @_;

	$DB::dbg //=  $class;
	@DB::options{ keys %{ $params{ options } } } =  values %{ $params{ options } };
}


sub trace_load {
	my $self =  shift;

	print "Loaded '@_'\n"
}


sub bbreak {
	print "\n" .'= ' x30 ."$DB::ext_call\n";

	# watch();

	print "$DB::file:$DB::line    " .DB::source()->[ $DB::line ];
}



sub process {
}



sub abreak {
}



sub trace_subs {
	my( $self, $t ) =  @_;

	BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }


	my $info = '';
	my $first_frame;
	local $" =  ' - ';
	my $gf =  \@DB::goto_frames;
	for my $frame ( DB::frames() ) {
		$first_frame //=  $frame;
		if(    $gf->[0][0] eq $frame->[1]
			&& $gf->[0][1] eq $frame->[2]
			&& $gf->[0][2] == $frame->[3]
		) {
			$first_frame =  $gf->[0];
			$info .=  "GOTO: @{ $_ }[0..3]\n"   for reverse @$gf[ 1..$#$gf ];
			$gf =  $DB::goto_frames[0][4];
		}

		$info .=  "FROM: @{$frame}[1..4] \n";
	}

	my $context = $first_frame->[5] ? 'list'
			: defined $first_frame->[5] ? 'scalar' : 'void';

	$info =
	    "\n" .'= ' x15 ."\n"
		."CNTX: $context\n"
	    ."${t}SUB: @{ $first_frame }[4]( @{ $first_frame->[0] } )\n"
	    .$info;


	# print "TEXT: " .DB::location( $DB::sub ) ."\n";
	# WORKAROUND: even before function call $DB::sub changes its value to DB::location
	my $sub =  $DB::sub;
	$info .=  "TEXT: " .DB::location( @{ $first_frame }[4] ) ."\n";

	$info .=  "DEEP: $DB::deep\n";
	$info .=  '= ' x15 ."\n";

	print $info;
}


package    # hide the package from the PAUSE indexer
    DB;



BEGIN {
	$^P |= 0x80;
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


our $dbg;            # debugger object/class
our $package;        # current package
our $file;           # current file
our $line;           # current line number
our $deep;           # watch the calling stack depth
our $ext_call;       # keep silent at DB::sub/lsub while do external call from DB::*
our @goto_frames;    # save sequence of places where nested gotos are called
our %options;



# Do DB:: configuration stuff here
BEGIN {
	$options{ s }              //=  0;         # compile time options
	$options{ w }              //=  0;         # compile time options
	$options{ orig_frames }    //=  0;         # compile time & runtime option
	$options{ frames }         //=  -1;        # compile time & runtime option
	$options{ dbg_frames }     //=  0;         # compile time & runtime option
	$options{ trace_subs }     //=  0;         # compile time & runtime option
	# The differece when we set it compile time, we trace internal call and
	# Module::import calls at runtime we do not see those
	$options{ trace_load }     //=  0;         # compile time option
	$options{ trace_returns }  //=  0;

	$options{ goto_callstack } //=  0;
	#options{ store_branches }

	$DB::postponed{ 'DB::DB' } =  1;
}



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
}


# Hooks to Perl's internals should be first.
# Because debugger descendants may call them
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



	sub location {
		my $subname =  shift;

		# The subs from DB::* are not placed here. Why???
		# A? Maybe they are placed after module loaded?
		return $DB::sub{ $subname } || ">>$subname<<";
	}



	sub subs {
		return keys %DB::sub   unless @_;

		my $re =  shift;
		return grep { /$re/ } keys %DB::sub;
	}



	sub can_break {
		my( $file, $line ) =  @_;

		($file, $line) =  split ':', $file
			unless defined $line;

		return defined ${ "::_<$file" }  &&  $line <= $#{ "::_<$file" }
			&& ${ "::_<$file" }[ $line ] != 0;
	}


	sub frames {
		my $level =  shift;
		# Note that we should ignore our frame, so +1

		if( defined $level ) {
			# https://rt.perl.org/Public/Bug/Display.html?id=126872#txn-1380132
			my @frame =  caller( $level +1 );
			return ( [ @DB::args ], @frame );
		}

		if( $options{ orig_frames } ) {
			my $lvl =  0;
			while( my @frame =  caller( $lvl ) ) {
				print "ORIG: @frame[0..3]\n";
				$lvl++;
			}
		}


		$level =  0;
		local $" =  ' - ';
		while( $ext_call ) {
			my @frame =  caller($level++);
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


		BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $DB::options{ w } }

		my @frames;
		my $count =  $options{ frames };
		while( $count  &&  (my @frame =  caller( $level++ )) ) {
			last   if !@frame;
			push @frames, [ [ @DB::args ], @frame ];
		} continue {
			$count--;
		}

		return @frames;
	}
}



# We define posponed/sub as soon as possible to be able watch whole process
sub postponed {
	$dbg->trace_load( @_ )   if $options{ trace_load };
}



sub DB {
	init();

	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect
	$dbg->bbreak();
	$dbg->process();
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
			[ $DB::package, $DB::file, $DB::line, $DB::sub, $last_frames ];

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
	return   if $ext_call;

	trace_subs( undef, 'G' );

	if( $DB::options{ goto_callstack } ) {
		BEGIN{ 'warnings'->unimport( 'uninitialized' )   if $options{ w } }
		local $" = ' - ';
		for( DB::frames() ) {
			my $args =  shift @$_;
			print "@$_ ( @$args )\n";
		}
	}
};



# The sub is installed at compile time as soon as the body has been parsed
sub sub {
	if( $ext_call ) {
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub
	}

	my $root =  \@DB::goto_frames;
	local @DB::goto_frames;
	trace_subs( $root, 'C' );
	local $DB::deep =  $DB::deep +1;


	{
		BEGIN{ 'strict'->unimport( 'refs' )   if $options{ s } }
		return &$DB::sub   if !$options{ trace_returns };


		if( wantarray ) {                             # list context
			my @ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			$dbg->trace_returns( @ret );

			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			my $ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			$dbg->trace_returns( $ret );

			return $ret;
		}
		else {                                        # void context
			&$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
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




1;

__END__

Describe what is used by perl internals from DB:: at compile time
${ "::_<$filename" } - $filename
@{ "::_<$filename" } - source lines. Line in compare to 0 shows trapnessability
%{ "::_<$filename" } - traps keyed by line number ***
$DB::sub - the current sub
%DB::sub - the sub definition
@DB::args - ref to the @_ at the given level at caller(N)
&DB::goto, &DB::sub, &DB::lsub, &DB::postponed - called at appropriate events
$^P - flags to control behaviour
$DB::postponed{subname} - trace sub loads        ***
$DB::trace, $DB::single, $DB::signal - controls if the program should break

initialization steps: rc -> env


goto implicitly changes the value of $DB::sub

At compile time $DB::single is 0

Which data is preserved by forth bit of $^P?

How to debug lvalue subs?

+
"segmentation fault when 'print @_'" (30 lines) at http://paste.scsys.co.uk/502490

The DOC must describe that DB::sub should have :lvalue attribute
if DB::lsub is not defined



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


Write test that checks that Devel::Debugger is loaded first



Why the DB::DB is called twice for:
print "@{[ (caller(0))[0..2] ]}\n";
but only one for this:
print sb();


use should have args. and the caller called from DB:: namespace should set @DB::args
at compile time 'caller' also does not fill @DB::args
BEGIN {
	print caller, @DB::args
}
