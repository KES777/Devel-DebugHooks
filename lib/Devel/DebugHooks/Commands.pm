package Devel::DebugHooks::Commands;

# BEGIN {
# 	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
# 	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
# }

my $cmd_f;
my %cmd_T = (
	G => '&',
	C => '=',
	D => '-',
	L => '\\',
);



sub _list {
	my( $from, $to, $file ) =  @_;


	my $source =  DB::source( $file );
	my $traps  =  DB::traps( $file );

	$from =  0           if $from < 0;        # TODO: testcase; 0 exists if -d
	$to   =  $#$source   if $to > $#$source;  # TODO: testcase

	for my $line ( $from..$to ) {
		if( exists $traps->{ $line } ) {
			print $DB::OUT exists $traps->{ $line }{ action    }? 'a' : ' ';
			print $DB::OUT exists $traps->{ $line }{ condition }? 'b' : ' ';
		}
		else {
			print $DB::OUT '  ';
		}

		print $DB::OUT $line == $DB::line ? '>>' : '  ';

		print $DB::OUT "$line: " .$source->[ $line ];
	}
}


# TODO: make variables global/configurable
my $lines_before =  8;
my $lines_after  =  12;
my $line_cursor;
my $old_DB_line  =  -1;
# TODO: tests 'l;l', 'l 0', 'f;l 19 3', 'l .'
sub list {
	shift   if @_ == 1  &&   (!defined $_[0] || $_[0] eq '');

	unless( @_ ) {
		if( $old_DB_line != $DB::line ) {
			$old_DB_line =  $DB::line;
			$line_cursor =  $DB::line;
		}

		_list( $line_cursor -$lines_before, $line_cursor +$lines_after );

		$line_cursor +=  $lines_after +1 +$lines_before;
	}


	if( @_ == 1 ) {
		my $arg =  shift;
		if( ( $line_cursor ) =  $arg =~ m/^(\d+|\.)$/ ) {
			$line_cursor =  $DB::line   if $line_cursor eq '.';

			_list( $line_cursor -$lines_before, $line_cursor +$lines_after );

			$line_cursor +=  $lines_after +1 +$lines_before;
		}
		elsif( my( $subname ) =   $arg =~ m/^([\w:]+)$/ ) {
			$subname =  "${ DB::package }::${ subname }"
				if $subname !~ m/::/;

			# The location format is 'file:from-to'
			my $location =  DB::location( $subname );
			if( defined $location  &&  $location =~ m/^(.*):(\d+)-(\d+)$/ ) {
				_list( $2, $3, $1 );
			}
		}
		else {
			print $DB::OUT "Unknown paramenter: $arg\n";

			return 1;
		}
	}


	1;
}


$DB::commands =  {
	'.' => sub {
		print $DB::OUT "$DB::file:$DB::line    " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/

		1;
	},

	# In compare to 's' and 'n' commands 'r' will not stop at each OP. The
	# true value of $DB::single will be restored at DB::sub when this sub returns
	# Therefore DB::DB will be called at the first OP followed this sub call
	,r => sub {
		my( $frames_out, $sharp ) =  shift =~ m/^(\d+)(\^)?$/;

		# TODO: implement testcase 'r', 'r 0^'
		$frames_out //=  1;

		# TODO: implement testcase r 5^
		$frames_out =   @DB::stack -$frames_out +1   if $sharp;

		# TODO: implement testcase when $frames_out > @DB::stack
		$frames_out =  $frames_out > @DB::stack ? @DB::stack+1 : $frames_out;

		# TODO: implement testcase and feature
		# (r > @DB::stack) should run until end of programm

		# TODO: implement testcase
		# go into sub by breakpoint, then check r, r 1, r N works fine


		# Skip the current frame we are in ...
		$DB::single =  0;

		# ... skip N next frames
		# $#DB::stack =  @DB::stack -1;
		$_->{ single } =  0   for @DB::stack[ -$frames_out+1 .. -1 ];

		# and stop only at this one
		$DB::stack[ -$frames_out ]{ single } =  1   if $frames_out <= @DB::stack;

		return;
	}

	# Actually nothing is changed. We stop at each OP in the script.
	# Only one important thing: if 'n' was called before we change the
	# $DB::single value from 2 to 1.
	,s => sub {
		$DB::single =  1;
		# TODO: implement testcase
		# n behaves as s for non sub calls
		# TODO: implement testcase
		# sub t1{ 1; } sub t2{ t1(); #n t1(); } sub t3{ t2(); 2; } t3() #b 2;go
		# If next executed OP will be return from sub, the $DB::single will be
		# overwrited by the value for that frame. We prevent that here:
		# $#DB::stack =  $DB::deep -1;
		# TODO: implement testcase for case when we 's' in main script before
		# any sub call. At this moment the $DB::stack has no frames at all.
		$DB::stack[ -1 ]{ single } =  1   if exists $DB::stack[ -1 ];

		return;
	}

	# As for the 's' command we stop at each OP in the script. But when the
	# sub is called we turn off debugging for that sub at DB::sub. Because of
	# $DB::single localizing its value will be restored after that sub returns.
	# Therefore DB::DB will be called at the first OP followed this sub call
	,n => sub {
		$DB::single =  2;
		# TODO: implement testcase
		# sub t1{ 1; #s } sub t2{ t1(); 1; } sub t3{ t2(); 2; } t3() #b 1;go
		# If next executed OP will be return from sub, the $DB::single will be
		# overwrited by the value for that frame. We prevent that here:
		# $#DB::stack =  $DB::deep -1;
		$DB::stack[ -1 ]{ single } =  2   if exists $DB::stack[ -1 ];

		return;
	}

	,q => sub { $DB::single =  0; exit; }

	# TODO: print list of vars which refer this one
	,vars => sub {
		my $type =  0;
		my $level =  0;
		for( split " ", shift ) {
			$type |= ~0   if /^a|all$/;
			$type |= 1    if /^m|my$/;
			$type |= 2    if /^o|our$/;
			$type |= 4    if /^g|global$/;
			$type |= 8    if /^u|used$/;
			$type |= 16   if /^c|closured$/;
			$type |= 24   if /^s|sub$/;

			$level =  $1  if /^(\d+)$/;
		}

		$type ||= 7;  # TODO: make defaults configurable
		$level +=  4; # The first client frame

		require 'PadWalker.pm';
		require 'Data/Dump.pm';
		require 'Package/Stash.pm'; # BUG? spoils DB:: by emacs, dbline

		if( $type & 1 ) {
			print $DB::OUT "\nMY:\n", Data::Dump::pp( PadWalker::peek_my( $level ) ), "\n";
		}

		if( $type & 2 ) {
			print $DB::OUT "\nOUR:\n", Data::Dump::pp( PadWalker::peek_our( $level ) ), "\n";
		}

		if( $type & 4 ) {
			my $stash =  Package::Stash->new( $DB::package )->get_all_symbols();
			# Show only user defined variables
			# TODO? implement verbose flag
			if( $DB::package eq 'main' ) {
				for( keys %$stash ) {
					delete $stash->{ $_ }   if /::$/;
					delete $stash->{ $_ }   if /^_</;
					delete $stash->{ $_ }   if /^[\x00-0x1f]/; #Remove $^ variables
				}

				delete @$stash{ qw# STDERR stderr STDIN stdin STDOUT stdout # };
				delete @$stash{ qw# SIG INC F ] ENV ; > < ) ( $ " _ # }; # a b
				delete @$stash{ qw# - + ` & ' #, 0..99 };
				# BUG? warning still exists despite on explicit escaping of ','
				delete @$stash{ qw# ARGV ARGVOUT \, . / \\ | # };
				delete @$stash{ qw# % - : = ^ ~ # };
				delete @$stash{ qw# ! @ ? # };
			}
			delete $stash->{ sub }   if $DB::package eq 'DB';

			print $DB::OUT "\nGLOBAL:\n", Data::Dump::pp( $stash ), "\n";
		}

		if( $type & 8 ) {
			print $DB::OUT "\nUSED:\n";

			if( !defined $DB::sub ) {
				print $DB::OUT "Not in a sub\n";
			}
			else {
				print $DB::OUT Data::Dump::pp( PadWalker::peek_sub( \&$DB::sub ) ), "\n";
			}
		}

		if( $type & 16 ) {
			print $DB::OUT "\nCLOSED OVER:\n";

			if( !defined $DB::sub ) {
				print $DB::OUT "Not in a sub\n";
			}
			else {
				print $DB::OUT Data::Dump::pp( (PadWalker::closed_over( \&$DB::sub ))[0] ), "\n";
			}
		}

		1;
	}

	,b => sub {
		my( $line, $condition ) =  shift =~ m/^([\d]+|\.)(?:\s+(.*))?$/;
		$line =  $DB::line   if $line eq '.';
		my $traps =  DB::traps();


		# list all breakpoints
		unless( $line ) {
			for( sort keys %$traps ) {
				print $DB::OUT "$_: ". $traps->{ $_ }{ condition } ."\n";
				warn "The breakpoint at $_ is zero and should be deleted"
					if $traps->{ $_ } == 0;
			}

			return 1;
		}


		unless( DB::can_break( $DB::file, $line ) ) {
			print $DB::OUT "This line is not breakable\n";
			return -1;
		}


		# set or delete breakpoint
		# TODO: testcase: trap remains if condition supplied
		$traps->{ $line }  &&  !$condition ?
			# BUG? deleting a key does not remove a breakpoint for that line
			# WORKAROUND: we should explicitly set value to 0 then delete the key
			do{ $traps->{ $line } =  0; delete $traps->{ $line } }:
			($traps->{ $line }{ condition } =  $condition // 1);

		1;
	}

	,go => sub {
		my( $line, $file ) =  shift =~ m/^(\d+)(?:\s+(.+))?$/;

		if( $file  &&  $file =~ m/^\d+$/ ) {
			$file =  $cmd_f->[ $file ]   if exists $cmd_f->[ $file ];
		}

		if( defined $line ) {
			$DB::file =  $file   if defined $file;
			return 1   if 0 > $DB::commands->{ b }->( $line );
			DB::traps()->{ $line }{ tmp } =  1;

		}


		$DB::single =  0;
		$_->{ single } =  0   	for( @DB::stack );

		# TODO: implement testcase
		# $script = 'sub t{ #go }; t(); my $x';
		# Should not stop at 'my $x'

		return;
	}

	,f => sub {
		# return {
		# 	expr => '\%INC'
		# 	,code => sub {
				my( $args, $expr ) =  @_;

				# Set current file to selected one:
				if( @$cmd_f  &&  $args =~ /^\d+$/  &&  $#$cmd_f >= $args ) {
					$DB::file =  $cmd_f->[ $args ];
					print $DB::OUT "$DB::file\n";
					return 1;
				}

				# List available files
				$cmd_f   =  [];
				my $line =  0;
				for( sort $0, values %INC ) {
				# for( sort $0, keys %$expr ) {
					if( /(?:$args)/ ) {
						push @$cmd_f, $_;
						print $DB::OUT $line++ ." $_\n";
					}
				}

				1;
		# 	}
		# }
	}

	# TODO: give names to ANON
	,T => sub {
		my $deep =  @DB::stack;
		for my $frame ( DB::frames ) {
			my $context =  $frame->[7]? '@' : defined $frame->[7]? '$' : '.';
			my $type    =  $cmd_T{ $frame->[0] };
			my $subname =  $frame->[5];
			my $args    =  $frame->[6] ? $frame->[1] : '';
			my $file    =  $frame->[3];
			my $line    =  $frame->[4];

			if( $args ) {
				$args =  join ', ', map{ defined $_ ? $_ : '&undef' } @$args;
				$args = "($args)";
			}

			my $d =  $frame->[0] eq 'D' ? 'D' : $deep;
			print $DB::OUT "$d $type $context $subname$args <--  $file:$line\n";
			$deep--  if $frame->[0] ne 'G'  &&  $frame->[0] ne 'D';
		}

		return 1;
	}

	,l => \&list,
};

1;
