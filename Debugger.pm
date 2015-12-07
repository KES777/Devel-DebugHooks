package Devel::Debugger;

our $VERSION =  '0.01';

BEGIN {
	our $Module  =  'DebugBase';
}



package    # hide the package from the PAUSE indexer
    DB;

BEGIN {
	$^P ^= 0x80;
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


BEGIN {
	$DB::postponed{ 'DB::DB' } =  1;
}


sub postponed {
	my( $file ) =  @_;

	print "Loaded '$file'\n"   if 1;
}



sub sub : lvalue {
	print "SUB: $DB::sub\n"                    if 0;
	print "FROM: @{[ (caller(0))[0..2] ]}\n"   if 0;

	&$DB::sub;
}



use strict;
use warnings;


our $package;    # current package
our $file;       # current file
our $line;       # current line number
our $deep =  0;  # watch the calling stack depth



sub DB {
	init();

	Devel::DebugBase::bbreak();
	Devel::DebugBase::process();
	Devel::DebugBase::abreak();
}


# Hooks to Perl internals data
{
	#@DB::args << caller(N)

	no strict qw/ refs /;

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

		no warnings qw/ uninitialized /; # do not distrub if wrong $file/$line is given
		return ${ "::_<$file" }[ $line ] != 0;
	}
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	die "'$DB::file' ne '" .file( $DB::file ) ."'"
		if $DB::file ne file( $DB::file );
}



my $goto =  sub {
	# HERE we get unexpected results about 'caller'
	# EXPECTED: the line number where 'goto' called from
	Devel::DebugBase::log_calls( \@_, 'G', 1 );
};



# The sub is installed at compile time as soon as the body has been parsed
my $sub =  sub {
	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	{
		local $DB::single =  0;
		Devel::DebugBase::log_calls( \@_ );         # if $log_calls
	}


	# goto &$DB::sub;    # if return result not required
	my( $ret, @ret );
	{
	no strict 'refs';
	wantarray ?
		@ret =  &$DB::sub :
		defined wantarray ?
			$ret =  &$DB::sub :
			&$DB::sub;
			# We do not assign $ret = undef explicitly
			# It has 'undef' when is created
	}

	# watch_return_value   if $watch

	return
		wantarray ? @ret : $ret ;
};



my $lsub =  sub : lvalue {
	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	{
		local $DB::single =  0;
		# Here too client's code 'caller' return wrong info
		Devel::DebugBase::log_calls( \@_, 'L', 1 );         # if $log_calls
	}

	no strict 'refs';
	return &$DB::sub;
	# the last statement is the sub result.
	# We can not do '$DB::deep--' here. So we use 'local $DB::deep'.
};



# We delay installation until the file's runtime
{
	no warnings 'redefine';
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
