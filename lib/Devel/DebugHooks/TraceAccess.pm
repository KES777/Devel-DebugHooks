package Devel::DebugHooks::TraceAccess;

use Log::Log4perl;

sub TIESCALAR {
	my $class =  shift;

	my $obj = { data => ${ shift }, @_ };

	return bless $obj, 'ScalarHistory';
}

sub TIEHASH {
	my $class =  shift;
	my $data  =  shift;
	my %arg   =  @_;

	my $obj;
	@{ $obj->{ data } }{ keys %$data } =  values %$data;
	@$obj{ keys %arg }                 =  values %arg;

	return bless $obj, 'HashHistory';
}


{
	package ScalarHistory;
	my $logger =  Log::Log4perl::get_logger( "LogVars" );


	sub FETCH {
		my $self =  shift;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( $self->{ data } ."<< $name    at $file:$line" );

		return $self->{ data };
	}


	sub STORE {
		my( $self, $value ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( "$name =  '$value'    at $file:$line" );

		$self->{ data } =  $value;
	}


	sub DESTROY {
		my $self =  shift;
	}


	sub UNTIE {
		my $self =  shift;
	}
}

{
	package HashHistory;
	my $logger =  Log::Log4perl::get_logger( "LogVars" );


	sub FETCH {
		my( $self, $key ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( $self->{ data }{ $key } ."<< $name\{ $key }    at $file:$line" );

		return $self->{ data }{ $key };
	}


	sub STORE {
		my( $self, $key, $value ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( "$name\{ $key } =  '$value'    at $file:$line" );

		$self->{ data }{ $key } =  $value;
	}


	sub DELETE {
		my( $self, $key ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( "delete $name\{ $key }'    at $file:$line" );
		delete $self->{ data }{ $key };
	}


	sub CLEAR {
		my( $self ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		$logger->info( "$name =  ()    at $file:$line" );
		%{ $self->{ data } } =  ();
	}


	sub EXISTS {
		my( $self, $key ) =  @_;

		my $name =  $self->{ desc };
		my( undef, $file, $line ) =  caller(0);
		my $exists =  exists $self->{ data }{ $key };
		$logger->info( ($exists?'':'NOT ') ."EXISTS $name\{ $key }    at $file:$line" );
		$exists;
	}


	sub FIRSTKEY {
		my( $self ) =  @_;

		keys %{ $self->{ data } };    # reset each() iterator
		each %{ $self->{ data } };
	}


	sub NEXTKEY {
		my( $self, $lastkey ) =  @_;

		each %{ $self->{ data } };
	}


	sub SCALAR {
		my $self =  shift;

		scalar %{ $self->{ data } };
	}


	sub DESTROY {
		my $self =  shift;
	}


	sub UNTIE {
		my $self =  shift;
	}
}


1;
