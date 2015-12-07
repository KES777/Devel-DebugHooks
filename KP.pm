package Devel::KP;

our $VERSION =  '0.01';

# use Log::Any '$log', default_adapter => 'Stderr';



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

	print "Loaded '$file'\n"   if 0;
}



sub sub : lvalue {
	print "SUB: $DB::sub\n"                    if 0;
	print "FROM: @{[ (caller(0))[0..2] ]}\n"   if 0;

	&$DB::sub;
}

use strict;
use warnings;
# use Term::ReadKey;

use Data::Dump qw/ pp /;

use B::Deparse ();
my $deparse =  B::Deparse->new();

use Package::Stash;
my $this =  Package::Stash->new( 'DB' );

use Benchmark qw/ cmpthese /;

use PadWalker qw/ peek_my peek_our /;



our $package;    # current package
our $file;       # current file
our $line;       # current line number
our $deep =  0;  # watch the calling stack depth



sub DB {
	init();

	bbreak();
	process();
	abreak();
}


# Hooks to Perl internals data
{
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





	sub can_break {
		my( $line, $file ) =  @_;

		$file //=  $DB::file;
		$line //=  $DB::line;

		no strict qw/ refs /;
		no warnings qw/ uninitialized /; # do not distrub if wrong $file/$line is given
		return ${ "::_<$file" }[ $line ] != 0;
	}
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	die "'$DB::file' ne '" .file( $DB::file ) ."'"
		if $DB::file ne file( $DB::file );


	# print "\n\nPad:";
	# my $all =  $this->get_all_symbols;
	# delete $all->{sub};
	# print "\n" .pp $all;

}



sub bbreak {
	print "\n" .'- ' x30 ."\n";

	watch();

	print "$DB::file:$DB::line    " .source()->[ $DB::line ];
}



sub process {
}



sub abreak {
}



use YAML ();
my $watch =  YAML::LoadFile( ".db_watch" );
print pp $watch, \@_;
print "\n";

sub watch {
	my @vars =  @_ ? @_ : keys %$watch;

	return   unless @vars;

	for( @vars ) {
		my @value =  eval "package $DB::package; $_";
		# @value =  ( '><' )   if $@;
		print "$_ :  "
			.( $@  ?  '><'  :  pp @value );

		#print $@   if $@;
		print "\n";
	}
}



sub log_calls {
	my( $args, $t, $level ) =  @_;
	$t     //=  'C';
	$level //=  0;

	local $" =  ' - ';
	print "\n";
	print '- ' x15, "\n";
	print "${t}SUB: $DB::sub( @$args )\n";
	print "FROM: @{[ (caller($level))[0..2] ]}\n";
	print "TEXT: " .location ."\n";
	print "DEEP: $DB::deep\n";
	print '- ' x15, "\n";
}



my $goto =  sub {
	# HERE we get unexpected results about 'caller'
	# EXPECTED: the line number where goto called from
	log_calls( \@_, 'G', 1 );
};



# The sub is installed at compile time as soon as the body has been parsed
my $sub =  sub {
	# When we leave the scope the original value is restored.
	# So it is the same like '$DB::deep--'
	local $DB::deep =  $DB::deep +1;
	log_calls( \@_ );         # if $log_calls
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
	# Here too client's code 'caller' return wrong info
	log_calls( \@_, 'L', 1 );         # if $log_calls

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
