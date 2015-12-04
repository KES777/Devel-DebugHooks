package Devel::KP;

our $VERSION =  '0.01';

# use Log::Any '$log', default_adapter => 'Stderr';



package    # hide the package from the PAUSE indexer
    DB;

use strict;
use warnings;
# use Term::ReadKey;

use Data::Dump qw/ pp /;

use B::Deparse ();
my $deparse =  B::Deparse->new();

use Package::Stash;
my $this =  Package::Stash->new( 'DB' );

use Benchmark qw/ cmpthese /;

use PadWalker qw/ peek_my peek_our /;



our $package;   # current package
our $file;      # current file
our $line;      # current line number
our $next;      # the code at the current line
our @code;      # alias to array of the current file's source code lines



sub can_break {
	my( $line, $file ) =  @_;

	$file //=  $DB::file;
	$line //=  $DB::line;

	no strict qw/ refs /;
	no warnings qw/ uninitialized /; # do not distrub if wrong $file/$line is given
	return ${ "::_<$file" }[ $line ] != 0;
}


sub DB {
	init();

	bbreak();
	process();
	abreak();
}



sub init {
	( $DB::package, $DB::file, $DB::line ) = caller(1);

	no strict qw/ refs /;
	*DB::code =  \@{ "::_<$DB::file" };

	# print "\n\nPad:";
	# my $all =  $this->get_all_symbols;
	# delete $all->{sub};
	# print "\n" .pp $all;

	$DB::next =  $DB::code[ $DB::line ];
}



sub bbreak {
	print "\n" .'- ' x30 ."\n";

	watch();

	print "$DB::file:$DB::line    " .$DB::next;
}



sub process {
}



sub abreak {
}



use YAML ();
my $watch =  YAML::LoadFile( ".db_watch" );
print pp $watch, \@_;
print "\n";

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



sub postponed {
	my( $file ) =  @_;

	warn "Loaded '$file'\n";
}



1;
