package Devel::DebugHooks::Terminal;

our @ISA;

BEGIN {
        $DB::options{ trace_load }  //=  0;
        $DB::options{ trace_subs }  //=  0;
        $DB::options{ trace_returns }  //=  0;
        $DB::options{ _debug }      //=  0;
        $DB::options{ dbg_frames }  //=  0;
        @DB::options{ qw/ w s / } = ( 1, 1 );
        push @ISA, 'Devel::DebugHooks';
}

sub import {
	my $class =  shift;

	$class->SUPER::import( @_ );
}

sub bbreak {
	my $self =  shift;

	# print " -- $DB::file:$DB::line\n  " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/
	$self->process( 'l .' );
}



use Devel::DebugHooks();


# use Term::ReadLine;
my $term;
# BEGIN {
# 	$term =  Term::ReadLine->new( 'Perl' );
# }
my $last_input;
sub get_command {
	my $self =  shift;

	# WORKAROUND: https://rt.cpan.org/Public/Bug/Display.html?id=110847
	# print $DB::OUT "\n";
	# print "DBG>";
	my $line =  <STDIN>; #$term->readline( 'DBG> ' );
	chomp $line;
	if( $line ne '' ) {
		$last_input =  $line;
	}
	else {
		$line =  $last_input;
	}

	return $line;
}




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

	my $command_cb =  shift @$result;
	return[sub{
		my $result =  &$command_cb;
		return   unless defined $result;

		#TODO: implement infinit proxy

		return[ \&interact, @initial ];
	}
		,@$result
	];
}

my $handler =  DB::reg( 'interact', 'terminal' );
$$handler->{ code } =  \&interact;


1;
