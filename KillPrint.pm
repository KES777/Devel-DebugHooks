package Devel::KillPrint;


our $VERSION =  '0.01';

sub import {
}

BEGIN {
	$DB::dbg =  __PACKAGE__;
	$DB::options{ frames }     =  0;
	$DB::options{ trace_subs } =  1;
	$DB::options{ trace_load } =  1;
	push @ISA, 'Devel::DebugHooks';
}


sub trace_subs {
	my $self =  shift;

	$self->SUPER::trace_subs( @_ );
}


use Devel::DebugHooks options => {
		trace_subs     =>  2,
		frames         =>  -1,
		# trace_load     =>  1,
		# trace_returns  =>  1,
		# goto_callstack =>  1,
	};




1;
