package Devel::Debugger;

our $VERSION =  '0.01';

BEGIN {
	our $Module  =  'DebugBase';
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
our $deep =  0;      # watch the calling stack depth
our $ext_call =  0;  # keep silent at DB::sub/lsub while do external call from DB::*
our %options;



# Do DB:: configuration stuff here
BEGIN {
	@options{ qw/ s w / }     =  ( 0, 0 );
	$options{ trace_subs }    =  0;
	$options{ trace_load }    =  0;
	$options{ trace_returns } =  1;

	$DB::postponed{ 'DB::DB' } =  1;
}


# We define posponed/sub as soon as possible to be able watch whole process
sub postponed {
	trace_load( @_ )   if $options{ trace_load };
}



sub trace_subs {
	my( $args, $t, $level ) =  @_;

	$t     //=  'C';
	$level //=  0;

	local $" =  ' - ';
	print "\n";
	print '= ' x15, "\n";
	print "${t}SUB: $DB::sub( @$args )\n";
	print "FROM: @{[ (caller($level))[0..2] ]}\n";
	print "DEEP: $DB::deep\n";
	print '= ' x15, "\n";
}



sub sub : lvalue {
	trace_subs( \@_ )   if $options{ trace_subs };

	&$DB::sub;
}



# NOTICE: it is better to not use any modules from this one
# because they will appear to compiler first, but we do not want that
BEGIN {
	if( $options{ s } ) { require 'strict.pm';    strict->import();   }
	if( $options{ w } ) { require 'warnings.pm';  warnings->import(); }
	# http://perldoc.perl.org/warnings.html
	# The scope of the strict/warnings pragma is limited to the enclosing block.
	# But this not truth.
	# It is limited to the first enclosing block of the BEGIN block
}



# Hooks to Perl's internals
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
		return $DB::sub{ $subname };
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



sub DB {
	init();

	local $ext_call =  $ext_call +1;
	# local $DB::single =  0;          # Inside DB::DB the $DB::single has no effect
	Devel::DebugBase::bbreak();
	Devel::DebugBase::process();
	Devel::DebugBase::abreak();
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	die "'$DB::file' ne '" .file( $DB::file ) ."'"
		if $DB::file ne file( $DB::file );
}



my $goto =  sub {
	# HERE we get unexpected results about 'caller'
	# EXPECTED: the line number where 'goto' called from
	if( $options{ trace_subs }  &&  !$ext_call ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		Devel::DebugBase::trace_subs( \@_, 'G', 1 );
	}
};



# The sub is installed at compile time as soon as the body has been parsed
my $sub =  sub {
	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	if( $options{ trace_subs }  &&  !$ext_call ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually
		local $ext_call   =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		Devel::DebugBase::trace_subs( \@_ );
	}


	goto &$DB::sub   if $ext_call  ||  !$options{ trace_returns };

	{
		BEGIN{ strict->unimport( 'refs' )   if $options{ s } }

		if( wantarray ) {                             # list context
			my @ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			Devel::DebugBase::trace_returns( @ret );

			return @ret;
		}
		elsif( defined wantarray ) {                  # scalar context
			my $ret =  &$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			Devel::DebugBase::trace_returns( $ret );

			return $ret;
		}
		else {                                        # void context
			&$DB::sub;

			local $ext_call   =  $ext_call +1;
			local $DB::single =  0;
			Devel::DebugBase::trace_returns();

			return;
		}
	}


	die "This should be reached never";
};



my $lsub =  sub : lvalue {
	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	if( $options{ trace_subs }  &&  !$ext_call ) {
		# Any subsequent sub call inside next sub will invoke DB::sub again
		# The right way is to turn off 'Debug subroutine enter/exit'
		# local $^P =  $^P & ~1;      # But this works at compile time only.
		# So prevent infinite reentrance manually
		local $ext_call =  $ext_call +1;
		local $DB::single =  0;     # Prevent debugging for next call
		# Here too client's code 'caller' return wrong info
		Devel::DebugBase::trace_subs( \@_, 'L', 1 );
	}


	BEGIN{ strict->unimport( 'refs' )   if $options{ s } }
	return &$DB::sub;
	# the last statement is the sub result.
	# We can not do '$DB::deep--' here. So we use 'local $DB::deep'.
};



# We delay installation until the file's runtime
{
	BEGIN{ warnings->unimport( 'redefine' )   if $options{ w } }
	*sub  =  $sub;
	*lsub =  $lsub;
	*goto =  $goto;
}



BEGIN {
	eval "use Devel::$Devel::Debugger::Module";
}

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
