package Devel::Debugger;

our $VERSION =  '0.01';
our $dbg;

BEGIN {
	our $dbg =  'Devel::Debugger';
}


sub import {
	# $dbg =  caller;

	return 'HELLO';
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



our $package;        # current package
our $file;           # current file
our $line;           # current line number
our $deep;           # watch the calling stack depth
our $ext_call;       # keep silent at DB::sub/lsub while do external call from DB::*
our $prev_sub;       # keep track what is the previous sub. 'caller' lost that info while 'goto'
our %options;



# Do DB:: configuration stuff here
BEGIN {
	@options{ qw/ s w / }     =  ( 0, 0 );
	$options{ trace_subs }    =  0;
	$options{ trace_load }    =  0;
	$options{ trace_returns } =  1;

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
	if( $options{ s } ) { require 'strict.pm';    strict->import();   }
	if( $options{ w } ) { require 'warnings.pm';  warnings->import(); }
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
	#@DB::args << caller(N)

	BEGIN{ strict->unimport( 'refs' )   if $options{ s } }

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
		my $subname =  shift // $DB::sub;

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

		# do not distrub if wrong $file/$line is given
		BEGIN{ warnings->unimport( 'uninitialized' )   if $options{ w } }
		return ${ "::_<$file" }[ $line ] != 0;
	}
}



# We define posponed/sub as soon as possible to be able watch whole process
sub postponed {
	$Devel::Debugger::dbg->trace_load( @_ )   if $options{ trace_load };
}



sub trace_subs {
	my( $t, $context, $args ) =  @_;

	$level //=  0;

	local $" =  ' - ';
	print "\n";
	print '= ' x15, "\n";
	print "CNTX: " . ($context ? 'list' : (defined $context ? 'scalar' : 'void')) ."\n";
	print "${t}SUB: $DB::sub( @$args )\n";
	print "FROM: @{[ (caller($level))[0..2] ]}\n";
	print "TEXT: " .DB::location() ."\n";
	print "DEEP: $DB::deep\n";
	print '= ' x15, "\n";
}



sub sub : lvalue {
	$Devel::Debugger::dbg->trace_subs( 'C', wantarray, \@_ )   if $options{ trace_subs };

	&$DB::sub;
}



sub DB {
	init();

	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect
	$Devel::Debugger::dbg->bbreak();
	$Devel::Debugger::dbg->process();
	$Devel::Debugger::dbg->abreak();
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	die "'$DB::file' ne '" .file( $DB::file ) ."'"
		if $DB::file ne file( $DB::file );
}



my $ignore_goto =  0;
sub goto {
	do{ $ignore_goto--; return }   if $ignore_goto  ||  $ext_call;

	$prev_sub =  $DB::sub;
	# HERE we get unexpected results about 'caller'
	# EXPECTED: the line number where 'goto' called from
	if( $options{ trace_subs } ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		$Devel::Debugger::dbg->trace_subs( 'G', wantarray, \@_ );
	}
};



# The sub is installed at compile time as soon as the body has been parsed
sub sub {
	if( $ext_call ) {
		BEGIN{ strict->unimport( 'refs' )   if $options{ s } };
		return &$DB::sub
	}

	$DB::prev_sub =  $DB::sub;

	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	if( $options{ trace_subs } ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually. One way to compete this:
		# my $stub = sub { &$DB::sub };
		# local *DB::sub =  *DB::sub; *DB::sub =  $stub;
		# Another:
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		$Devel::Debugger::dbg->trace_subs( 'C', wantarray, \@_ );
	}


	do{ $ignore_goto++; goto &$DB::sub; }   if !$options{ trace_returns };

	{
		BEGIN{ strict->unimport( 'refs' )   if $options{ s } }

		if( wantarray ) {                             # list context
			my @ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			$Devel::Debugger::dbg->trace_returns( @ret );

			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			my $ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			$Devel::Debugger::dbg->trace_returns( $ret );

			return $ret;
		}
		else {                                        # void context
			&$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			$Devel::Debugger::dbg->trace_returns();

			return;
		}
	}


	die "This should be reached never";
};



sub lsub : lvalue {
	if( $ext_call ) {
		BEGIN{ strict->unimport( 'refs' )   if $options{ s } };
		return &$DB::sub
	}

	$DB::prev_sub =  $DB::sub;

	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	if( $options{ trace_subs } ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually
		local $ext_call =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		# Here too client's code 'caller' return wrong info
		$Devel::Debugger::dbg->trace_subs( 'L', wantarray, \@_ );
	}


	BEGIN{ strict->unimport( 'refs' )   if $options{ s } }
	return &$DB::sub;
	# the last statement is the sub result.
	# We can not do '$DB::deep--' here. So we use 'local $DB::deep'.
};




1;

__END__

Describe what is used by perl internals from DB:: at compile time

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
