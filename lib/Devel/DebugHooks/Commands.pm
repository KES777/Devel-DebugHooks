package Devel::DebugHooks::Commands;

# BEGIN {
# 	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
# 	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
# }


$DB::commands =  {
	'.' => sub {
		print "$DB::file:$DB::line    " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/

		1;
	},

	# In compare to 's' and 'n' commands we will not stop at each OP. The
	# true value of $DB::single will be restored at DB::sub when this sub returns
	# Therefore DB::DB will be called at the first OP followed this sub call
	,r => sub {
		$DB::single =  0;

		return;
	}

	# Actually nothing is changed. We stop at each OP in the script.
	# Only one important thing: if 'n' was called before we change the
	# $DB::single value from 2 to 1.
	,s => sub {
		$DB::single =  1;

		return;
	}

	# As for the 's' command we stop at each OP in the script. But when the
	# sub is called we turn off debugging for that sub at DB::sub. Because of
	# $DB::single localizing its value will be restored after that sub returns.
	# Therefore DB::DB will be called at the first OP followed this sub call
	,n => sub {
		$DB::single =  2;

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
		$condition //=  1;

		return   unless $line;

		DB::traps->{ $line }{ condition } =  $condition;

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

};

1;
