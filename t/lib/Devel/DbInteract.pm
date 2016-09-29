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



$DB::commands->{ 'list.conf' } =  sub {
	$Devel::DebugHooks::Commands::lines_before =  3;
	$Devel::DebugHooks::Commands::lines_after  =  3;
};



$DB::commands->{ 'list.conf2' } =  sub {
	$Devel::DebugHooks::Commands::lines_before =  3;
	$Devel::DebugHooks::Commands::lines_after  =  2;
};



sub bbreak {
	return   if $off;

	printf $DB::OUT "%s:%04s  %s"
		,DB::state( 'file' )
		,DB::state( 'line' )
		,DB::source()->[ DB::state( 'line' ) ];
}



sub get_command {
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

#FIX: remove copy/paste
sub interact {
	my @initial;
	my $str =  get_command();
	return   unless defined $str;
	my $result =  Devel::DebugHooks::CmdProcessor::process( undef, $str );
	return   unless defined $result;

	if( $result == 0 ) {
		# No command found
		# eval $str; print eval results; goto interact again
		return[ sub{
			# Devel::DebugHooks::Commands::dd( @_ );

			# We got ARRAYREF if EXPR was evalutated
			DB::state( 'db.last_eval', $str );

			if( ref $_[0] eq 'SCALAR' ) {
				print $DB::OUT "ERROR: ${ $_[0] }";
			}
			else {
				print $DB::OUT "\nEvaluation result:\n"   if DB::state( 'ddd' );
				my @res =  map{ $_ // $DB::options{ undef } } @{ $_[0] };
				local $" =  $DB::options{ '"' }  //  $";
				print $DB::OUT "@res\n";
			}

			return[ \&interact, @initial ];
		}
			,$str
		];
	}

	return[ \&interact, @initial ]   unless ref $result;

	return $result;
}

my $handler =  DB::reg( 'interact', 'terminal' );
$$handler->{ code } =  \&interact;

*Devel::DebugHooks::Commands::interact =  \&interact;

1;
