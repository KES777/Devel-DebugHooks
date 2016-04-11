package Devel::DebugHooks::Terminal;

our @ISA;

BEGIN {
        $DB::options{ trace_load }  //=  0;
        $DB::options{ trace_subs }  //=  0;
        $DB::options{ trace_returns }  //=  0;
        $DB::options{ _debug }      //=  0;
        $DB::options{ dbg_frames }  //=  0;
        @DB::options{ qw/ w s / } = ( 1, 1 );
        push @ISA, 'Devel::DebugHooks';
}

sub import {
	my $class =  shift;

	$class->SUPER::import( @_ );
}

sub bbreak {
	my $self =  shift;

	# print " -- $DB::file:$DB::line\n  " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/
	$self->process( 'l .' );
}



use Devel::DebugHooks();


# use Term::ReadLine;
my $term;
# BEGIN {
# 	$term =  Term::ReadLine->new( 'Perl' );
# }
my $last_input;
sub interact {
	my $self =  shift;

	my $line =  <>; #$term->readline( 'DBG> ' );
	chomp $line;
	if( $line ne '' ) {
		$last_input =  $line;
	}
	else {
		$line =  $last_input;
	}

	return $line;
}



1;
