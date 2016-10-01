package Devel::DebugHooks::CmdProcessor;





sub process {
	my( $dbg, $str ) =  @_;

	my( $cmd, $args_str ) =  $str =~ m/^([\w.]+)(?:\s+(.*))?$/;
	$args_str //=  '';


	unless(  $cmd  &&  exists $DB::commands->{ $cmd } ) {
		print $DB::OUT "No such command: '$str'\n"   if DB::state( 'ddd' );
		return 0;
	}

	# The command also should return defined value to keep interaction
	print $DB::OUT "Start to process '$cmd' command\n"   if DB::state( 'ddd' );
	my $result =  eval { $DB::commands->{ $cmd }( $args_str ) };
	print $DB::OUT "Command '$cmd' processed\n"   if DB::state( 'ddd' );
	do{ print $DB::OUT "'$cmd' command died: $@"; return -1; }   if $@;

	return $result;
}

1;
