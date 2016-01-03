package Devel::DebugHooks::Commands;


$DB::commands =  {
	'.' => sub {
		print "$DB::file:$DB::line    " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/

		1;
	},

	,s => sub {
		$DB::single =  1;

		return;
	}

	,n => sub {
		$DB::single =  2;

		return;
	}

	,q => sub { exit; }

	,vars => sub {
		require 'PadWalker.pm';
		require 'Data/Dump.pm';
		require 'Package/Stash.pm'; # BUG? spoils DB:: by emacs, dbline

		my $stash =  Package::Stash->new( $DB::package )->get_all_symbols();
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

		print
			"MY:\n",         Data::Dump::pp( PadWalker::peek_my( 2 ) )
			,"\n\nOUR:\n",   Data::Dump::pp( PadWalker::peek_our( 2 ) )
			,"\n\nSTASH:\n", Data::Dump::pp( $stash )
			,"\n";
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

		return;
	}

};

1;
