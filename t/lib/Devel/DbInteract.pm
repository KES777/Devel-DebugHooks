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



sub right { 'scope' };



sub nested {
	no warnings 'void';
	2;
	printf $DB::OUT "%s at %s:%s\n"
		,DB::state( 'single' ), DB::state( 'file' ), DB::state( 'line' );
	3;
}

$DB::commands->{ debug } =  sub {
	no warnings 'void';
	1;
	nested();
	4;
};

my $dbg_global;
$DB::commands->{ global } =  sub {
	print ++$dbg_global, "\n";
};
$DB::commands->{ right_global } =  sub {
	print DB::state( 'dbg_global', DB::state( 'dbg_global' )+1 ), "\n";
};



sub bbreak {
	return   if $off;

	printf $DB::OUT "%s:%04s  %s"
		,DB::state( 'file' )
		,DB::state( 'line' )
		,DB::source()->[ DB::state( 'line' ) ];
}



sub interact {
	return shift @$commands;
}



sub trace_subs {
	printf $DB::OUT "CALL FROM: %s %s %s\n"
		,DB::state( 'package' )
		,DB::state( 'file' )
		,DB::state( 'line' )
	;
}



sub trace_returns {
	printf $DB::OUT "BACK TO  : %s %s %s\n"
		,@{ DB::state( "stack" )->[-2] }{ qw/ package file line / }
	;
}



use parent '-norequire', 'Devel::DebugHooks';
use Devel::DebugHooks();

1;
