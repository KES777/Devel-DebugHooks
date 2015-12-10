package Devel::KillPrint;

our $VERSION =  '0.01';

sub import {
}

BEGIN {
	$DB::dbg =  __PACKAGE__;
	$DB::options{ trace_subs } =  1;
	$DB::options{ trace_load } =  1;
	push @ISA, 'Devel::DebugHooks';
}


use Devel::DebugHooks options => {
		# trace_subs     =>  1,
		# trace_load     =>  1,
		# trace_returns  =>  1,
	};




1;
