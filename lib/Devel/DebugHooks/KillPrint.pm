package Devel::DebugHooks::KillPrint;



my $actions =  {};

#FIX: Do this after script is compiled. Look for some hook...
sub trace_load {
	my( $self ) =  shift;

	if( $_[0] eq "*main::_<$0" ) { #<-- This is tricky
		while( my( $key, $value ) =  each %$actions ) {
			$DB::commands->{ a }->( "$key $value" );
		}
	}

	return $self->SUPER::trace_load( @_ );
}



BEGIN{
	$DB::options{ trace_load } =  1;
	push @ISA, 'Devel::DebugHooks';
}
use Devel::DebugHooks();
use Filter::Util::Call;



sub import {
	# Pay attention to $actions, because it is module global
	# We do not expect here that we would be used twice or more times!
	filter_add( bless $actions );

	shift->SUPER::import( @_[ 1..$#_ ] )
}



sub filter {
	my( $self ) =  @_;

	my $status;
	if( ( $status =  filter_read() ) > 0 ) {

		if( /#DBG: (.*) #$/ ) {
			my( $file, $line ) =  (caller 0)[1,2];
			$self->{ "$file:$line" } =  $1;
		}
	}

	$status;
}



1;
