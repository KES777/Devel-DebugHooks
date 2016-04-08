package Devel::DbInteract;



our $commands;



sub import {
	( undef, $commands ) =  @_;

	$commands =  [ split ';', $commands ];

	shift->SUPER::import( @_ );
}



my $off;
$DB::commands->{ off } =  sub {
	$off++;
	undef $off   if $off>1;

	return 1;
};

sub bbreak {
	return   if $off;

	printf $DB::OUT "%s:%04s  %s"
		,$DB::file
		,$DB::line
		,DB::source()->[ $DB::line ];
}



sub interact {
	return shift @$commands;
}



use parent '-norequire', 'Devel::DebugHooks';
use Devel::DebugHooks();

1;
