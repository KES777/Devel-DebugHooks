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


$DB::commands =  {
	'.' => sub {
		print "$DB::file:$DB::line    " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/

		1;
	},

	# In compare to 's' and 'n' commands 'r' will not stop at each OP. The
	# true value of $DB::single will be restored at DB::sub when this sub returns
	# Therefore DB::DB will be called at the first OP followed this sub call
	,r => sub {
		my( $frames_out ) =  shift =~ m/^(\d+)$/;
		$frames_out //=  1;
		# TODO: implement testcase when $frames_out >= $DB::deep
		$frames_out =  $frames_out >= $DB::deep ? $DB::deep : $frames_out;

		# TODO: implement testcase and feature
		# (r > $DB::deep) should run until end of programm

		# TODO: implement testcase
		# go into sub by breakpoint, then check r, r 1, r N works fine

		$#DB::stack =  $DB::deep -1;
		$DB::stack[ -$frames_out ]{ single } =  1;

		$_->{ single } =  0   for @DB::stack[ - --$frames_out .. -1 ];

		$DB::single =  0;

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
		$#DB::stack =  $DB::deep -1;
		$DB::stack[ -1 ]{ single } =  1;

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
		$#DB::stack =  $DB::deep -1;
		$DB::stack[ -1 ]{ single } =  2;

		return;
	}

	,q => sub { exit; }

	,vars => sub {
		my $type =  0;
		for( split " ", shift ) {
			$type |= ~0   if /^a|all$/;
			$type |= 1    if /^m|my$/;
			$type |= 2    if /^o|our$/;
			$type |= 4    if /^g|global$/;
			$type |= 8    if /^u|used$/;
			$type |= 16   if /^c|closured$/;
			$type |= 24   if /^s|sub$/;
		}

		$type ||= 7;

		require 'PadWalker.pm';
		require 'Data/Dump.pm';
		require 'Package/Stash.pm'; # BUG? spoils DB:: by emacs, dbline

		if( $type & 1 ) {
			print "\nMY:\n", Data::Dump::pp( PadWalker::peek_my( 2 ) ), "\n";
		}

		if( $type & 2 ) {
			print "\nOUR:\n", Data::Dump::pp( PadWalker::peek_our( 2 ) ), "\n";
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
				delete @$stash{ qw# ARGV ARGVOUT , . / \ | # };
				delete @$stash{ qw# % - : = ^ ~ # };
				delete @$stash{ qw# ! @ ? # };
			}
			delete $stash->{ sub }   if $DB::package eq 'DB';

			print "\nGLOBAL:\n", Data::Dump::pp( $stash ), "\n";
		}

		if( $type & 8 ) {
			print "\nUSED:\n";

			if( !defined $DB::sub ) {
				print "Not in a sub\n";
			}
			else {
				print Data::Dump::pp( PadWalker::peek_sub( \&$DB::sub ) ), "\n";
			}
		}

		if( $type & 16 ) {
			print "\nCLOSED OVER:\n";

			if( !defined $DB::sub ) {
				print "Not in a sub\n";
			}
			else {
				print Data::Dump::pp( (PadWalker::closed_over( \&$DB::sub ))[0] ), "\n";
			}
		}

		1;
	}

	,b => sub {
		my( $line, $condition ) =  shift =~ m/^([\d]+|\.)(?:\s+(.*))?$/;
		my $traps =  DB::traps();


		# list all breakpoints
		unless( $line ) {
			for( sort keys %$traps ) {
				print "$_: ". $traps->{ $_ }{ condition } ."\n";
				warn "The breakpoint at $_ is zero and should be deleted"
					if $traps->{ $_ } == 0;
			}

			return 1;
		}


		# set or delete breakpoint
		$traps->{ $line }?
			# BUG? deleting a key does not remove a breakpoint for that line
			# WORKAROUND: we should explicitly set value to 0 then delete the key
			do{ $traps->{ $line } =  0; delete $traps->{ $line } }:
			($traps->{ $line }{ condition } =  $condition // 1);

		1;
	}

	,go => sub {
		$DB::single =  0;

		# The $DB::single will be restored when sub returns. So we set this flag
		# to continue ignoring debugger traps
		$DB::options{ NonStop } =  1;
		# TODO: implement testcase
		# $script = 'sub t{ #go }; t(); my $x';
		# Stopped at 'my $x' w/o NonStop

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
					print "$DB::file\n";
					return 1;
				}

				# List available files
				$cmd_f   =  [];
				my $line =  0;
				for( sort $0, values %INC ) {
				# for( sort $0, keys %$expr ) {
					if( /(?:$args)/ ) {
						push @$cmd_f, $_;
						print $line++ ." $_\n";
					}
				}

				1;
		# 	}
		# }
	}

	# TODO: give names to ANON
	,T => sub {
		my $deep =  $DB::deep;
		for my $frame ( DB::frames ) {
			my $context =  $frame->[7]? '@' : defined $frame->[7]? '$' : '.';
			my $type    =  $cmd_T{ $frame->[0] };
			my $subname =  $frame->[5];
			my $args    =  $frame->[1]   if $frame->[6];
			my $file    =  $frame->[3];
			my $line    =  $frame->[4];

			if( $args ) {
				$args =  join ', ', map{ defined $_ ? $_ : '&undef' } @$args;
				$args = "($args)";
			}

			my $d =  $frame->[0] eq 'D' ? 'D' : $deep;
			print "$d $type $context $subname$args <--  $file:$line\n";
			$deep--  if $frame->[0] ne 'G'  &&  $frame->[0] ne 'D';
		}
	}

};

1;
