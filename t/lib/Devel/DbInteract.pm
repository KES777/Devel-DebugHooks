package Devel::DbInteract;



# Can not use 'parent' because DB:: do calls to subs at its compile time
# So we should establish relationship before require
# use parent 'Devel::DebugHooks';
BEGIN {
	push @ISA, 'Devel::DebugHooks';
}



our $commands;



sub import {
	( undef, $commands ) =  @_;

	$commands =  [ split ';', $commands ];

	shift->SUPER::import( @_ );
}



sub bbreak {
	print $DB::OUT "$DB::file:$DB::line    " .DB::source()->[ $DB::line ];
}



sub interact {
	return shift @$commands;
}


use Devel::DebugHooks();

1;
