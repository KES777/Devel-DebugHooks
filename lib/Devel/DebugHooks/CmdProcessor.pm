package Devel::DebugHooks::CmdProcessor;





sub process {
	my( $dbg ) =  shift;

	my( $cmd, $args_str ) =  shift =~ m/^([\w.]+)(?:\s+(.*))?$/;
	$args_str //=  '';


	return 0   unless  $cmd and exists $DB::commands->{ $cmd };

	# The command also should return defined value to keep interaction
	if( defined (my $result =  $DB::commands->{ $cmd }( $args_str )) ) {
		return $result   unless ref $result;

		# Allow commands to evaluate $expr at a debugged script context
		if( ref( $result ) eq 'HASH' ) {
			return $result->{ code }->(
				$args_str
				,DB::eval( $result->{ expr } ) # FIX: it is not evaled at script context
			);
		}

		return $result;
	}
	else {
		return;
	}


	return 0;
}

1;
