package Devel::DbInteract;



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
