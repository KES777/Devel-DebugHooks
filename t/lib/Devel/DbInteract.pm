package Devel::DbInteract;


# TODO: Turn off debugging for this
# END { print $DB::OUT "Commands left"   if @$commands }

our $commands;



sub import {
	( my $class, $commands ) =  ( shift, shift );

	$commands =~ s/^\$(.)//s;
	my $endline =  $1 // ';';
	$commands =  [ split $endline, $commands ];

	$class->SUPER::import( @_ );
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



sub trace_subs {
	print $DB::OUT "CALL FROM: $DB::package $DB::file $DB::line\n";
}



sub trace_returns {
	printf $DB::OUT "BACK TO  : %s %s %s\n", @{ $DB::stack[-1]->{ caller } };
}



use parent '-norequire', 'Devel::DebugHooks';
use Devel::DebugHooks();

1;
