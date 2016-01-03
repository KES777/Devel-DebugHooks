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

	,go => sub {
		$DB::single =  0;

		return;
	}

};

1;
