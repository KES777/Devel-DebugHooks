package Devel::DebugBase;

our $VERSION =  '0.01';



# use YAML ();
my $watch =  {}; #{ '$x' => undef, '$y' => undef};
# $watch =  YAML::LoadFile( ".db_watch" );
# print pp $watch, \@_;
# print "\n";

use Data::Dump qw/ pp /;


sub bbreak {
	print "\n" .'= ' x30 ."$DB::ext_call\n";

	# watch();

	print "$DB::file:$DB::line    " .DB::source()->[ $DB::line ];
}



sub process {
}



sub abreak {
}



sub log_calls {
	my( $args, $t, $level ) =  @_;

	$t     //=  'C';
	$level //=  0;

	local $" =  ' - ';
	print "\n";
	print '- ' x15, "\n";
	print "${t}SUB: $DB::sub( @$args )\n";
	print "FROM: @{[ (caller($level))[0..2] ]}\n";
	print "TEXT: " .DB::location() ."\n";
	print "DEEP: $DB::deep\n";
	print '- ' x15, "\n";
}



sub watch {
	my @vars =  @_ ? @_ : keys %$watch;

	return   unless @vars;

	for( @vars ) {
		my @value =  eval "package $DB::package; $_";
		# @value =  ( '><' )   if $@;
		print "$_ :  "
			.( $@  ?  '><'  :  pp @value );

		#print $@   if $@;
		print "\n";
	}
}

1;
