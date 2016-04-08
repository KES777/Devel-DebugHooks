package Devel::DebugHooks::Commands;

# BEGIN {
# 	if( $DB::options{ w } ) { require 'warnings.pm';  'warnings'->import(); }
# 	if( $DB::options{ s } ) { require 'strict.pm';    'strict'->import();   }
#	if( $options{ d } ) { require 'Data/Dump.pm'; 'Data::Dump'->import( 'pp'); }
# }

# TODO: implement 'hard_go' to go over all traps to the 'line' or end
# TODO: implement do not stop in current sub
# TODO: black box command 'T': 50..70 Black box
# TODO: enable/disable group of traps
# TODO: implement option to show full/short sub options
# TODO: split all code by two: user code and core
# TODO: implement 'r n' to rewind n stack frames
# TODO: implement distance 'T XXX'; Automatically sets XXX to the current line
# TODO: implement 'b &' to set breakpoint to current sub
# TODO: implement 'd code' command to debug given subroutine
# TODO: implement 'l ~TEXT' to list specific lines
# TODO: implement 'ge -2' to edit
# TODO: implement 's 7', 'n 7', 'go +5' commands to skip N expressions
# FIX: when returning from sub by 'r' and upper sub has no any stop point
# we out many frames out
# TODO: implement tracing subroutine which user run manually 't $subname'
# NOTICE: when return we can go into destroy
# TODO: returning from try/catch block
# Show code flow in NON stop mode
# TODO: do not exit on blocks. This is usefull when we want to see result of statement
# if() { statement; }
# TODO: implement command to list all available packages
# TODO: implement command to list all available subs in package ( DB::subs )

my $file_line =  qr/(?:(.+):)?(\d+|\.)/;


# reset $line_cursor if DB::DB were called. BUG: if DB::DB called twice for same line
my $line_cursor;
my $old_DB_line  =  -1;
my $curr_file;
sub update_fl {
	if( $old_DB_line != $DB::line ) {
		$old_DB_line =  $DB::line;
		$line_cursor =  $DB::line;
		$curr_file   =  $DB::file;
	}
}

my $cmd_f;
sub file {
	update_fl()         unless defined $curr_file;
	return $curr_file   unless defined $_[0];

	my( $file, $do_not_set ) =  @_;
	$file =  $cmd_f->[ $file ]
		if $file =~ m/^(\d+)$/  &&  exists $cmd_f->[ $file ];

	$curr_file =  $file   unless $do_not_set;

	return $file;
}



my %cmd_T = (
	G => '&',
	C => '=',
	D => '-',
	L => '\\',
);


# TODO: implement trim for wide lines to fit text into window size
sub _list {
	my( $from, $to, $file, $run_file, $run_line ) =  @_;
	$run_file //=  $DB::file;
	$run_line //=  $DB::line;


	$file =  file( $file );
	my $source =  DB::source( $file );
	my $traps  =  DB::traps( $file );

	$from =  0           if $from < 0;        # TODO: testcase; 0 exists if -d
	$to   =  $#$source   if $to > $#$source;  # TODO: testcase

	print $DB::OUT "$file\n";
	for my $line ( $from..$to ) {
		next   unless exists $source->[ $line ];

		if( exists $traps->{ $line } ) {
			print $DB::OUT exists $traps->{ $line }{ action    }? 'a' : ' ';
			print $DB::OUT exists $traps->{ $line }{ onetime } ? '!'
				: exists $traps->{ $line }{ disabled }? '-'
				: exists $traps->{ $line }{ condition }? 'b' : ' ';
		}
		else {
			print $DB::OUT '  ';
		}

		print $DB::OUT $file eq $run_file  &&  $line == $run_line ? '>>' : '  ';

		print $DB::OUT DB::can_break( $file, $line ) ? 'x' : ' ';
		print $DB::OUT "$line: " . ($source->[ $line ] =~ s/\t/    /rg ); #/
	}
}



# TODO: make variables global/configurable
my $lines_before =  15;
my $lines_after  =  15;
# TODO: tests 'l;l', 'l 0', 'f;l 19 3', 'l .'
sub list {
	update_fl();
	shift   if @_ == 1  &&   (!defined $_[0] || $_[0] eq '');

	unless( @_ ) {

		_list( $line_cursor -$lines_before, $line_cursor +$lines_after );

		$line_cursor +=  $lines_after +1 +$lines_before;
	}


	if( @_ == 1 ) {
		my $arg =  shift;
		if( ( $stack, $file, $line_cursor ) =  $arg =~ m/^(-)?${file_line}$/ ) {
			my( $run_file, $run_line );
			if( $stack ) {
				# TODO: allow to list current sub -0
				# Here $line_cursor is stack frame number from the top
				my @frames =  DB::frames();
				( $run_file, $run_line ) =  @{ $frames[ $line_cursor -1 ] }[3,4];
				# TODO: save window level to show vars automatically at that level
				$file        =  $run_file;
				$line_cursor =  $run_line;
			}
			elsif( $line_cursor eq '.' ) {
				# TODO: 'current' means file and line! FIX this in other places too
				$file        =  $DB::file;
				$line_cursor =  $DB::line;
			}

			_list( $line_cursor -$lines_before, $line_cursor +$lines_after, $file, $run_file, $run_line );

			$line_cursor +=  $lines_after +1 +$lines_before;
		}
		# NOTICE: $level take effect only if '&' sign present. In other cases (\d*) should not match
		elsif( my( $coderef, $subname, $level ) =   $arg =~ m/^(\$?)([\S]+|\&)(\d*)$/ ) {
			my $deparse =  sub {
				require B::Deparse;
				my( $coderef ) =  @_;
				return -1   unless ref $coderef eq 'CODE';

				print $DB::OUT B::Deparse->new("-p", "-sC")
					->coderef2text( $coderef );

				return 1;
			};


			# 1.List the current sub or n frames before
			# TODO: Check is it possible to spy subs from goto_frames?
			# If yes think about interface to access to them ( DB::frames??? )
			if( $subname eq '&' ) {
				$level //=  0;
				# FIX: 'eval' does not update @DB::stack.
				# Eval exists at real stack but ot does not at our
				my $coderef =  $DB::stack[ -$level -1 ]{ sub };
				print $DB::OUT "sub $coderef ";
				$coderef =  \&$coderef   unless ref $coderef;
				return $deparse->( $coderef );
			}

			# 2. List sub by code ref in the variable
			# TODO: locate this sub at '_<$file' hash and do usual _list
			# to show breakpoints, lines etc
			$coderef  &&  return {()
				,expr =>  "\$$subname"
				,code =>  $deparse
			};


			# 3. List sub from source
			$subname =  "${ DB::package }::${ subname }"
				if $subname !~ m/::/;

			# The location format is 'file:from-to'
			my $location =  DB::location( $subname );
			if( defined $location  &&  $location =~ m/^(.*):(\d+)-(\d+)$/ ) {
				_list( $2, $3, $1 );
			}

			return 1;
		}
		else {
			print $DB::OUT "Unknown paramenter: $arg\n";

			return -1;
		}
	}


	1;
}



sub watch {
	my( $file, $line, $expr ) =  shift =~ m/^${file_line}(?:\s+(.+))?$/;

	$line     =  $DB::line   if $line eq '.';
	$file     =  file( $file );

	my $traps =  DB::traps( $file );


	unless( $expr ) {
		require Data::Dump;

		for( defined $line ? ( $line ) : sort{ $a <=> $b } keys %$traps ) {
			next   unless exists $traps->{ $_ }{ watches };

			print $DB::OUT "line $_:\n";
			print $DB::OUT "  " .Data::Dump::pp( $_ ) ."\n"
				for @{ $traps->{ $_ }{ watches } };
		}

		return 1;
	}


	unless( DB::can_break( $file, $line ) ) {
		print $DB::OUT file(). "This line is not breakable. Can not watch at this point\n";
		return -1;
	}


	push @{ $traps->{ $line }{ watches } }, { expr => $expr };
	#TODO: do not add same expressions


	1;
}



sub load {
	my $self =  shift;
	my( $file ) =  @_;
	$file ||=  '/home/feelsafe/.dbgini';


	my( $stops, $traps ) =  do $file;

	for( keys %$traps ) {
		# TODO? do we need to can_break( $file, $line )?
		%{ DB::traps( $_ ) || {} } =  %{ $traps->{ $_ } };
	}

	@DB::stop_in_sub{ keys %$stops } =  values %$stops;


	return 1;
}



# TODO: implement AutoSave option
sub save {
	my $self =  shift;
	my( $file ) =  @_;
	$file ||=  '/home/feelsafe/.dbgini';

	my $traps;
	for my $source ( keys %$DB::_tfiles ) {
		$traps->{ $source } =  DB::traps( $source );
		delete $traps->{ $source } # Do not save empty hashes
			unless keys %{ $traps->{ $source } };
	}

	open my $fh, '>', $file   or die $!;
	print $fh Data::Dump::pp( \%DB::stop_in_sub, $traps );

	return 1;
}



sub trace_variable {
	my( $var ) =  shift;

	require Devel::DebugHooks::TraceAccess;

	return {()
		,expr =>  "tie $var, 'Devel::DebugHooks::TraceAccess', \\$var, desc => '$var'"
		,code =>  sub {
			return 1;
		}
	}
}



sub action {
	my( $file, $line, $expr ) =  shift =~ m/^${file_line}(?:\s+(.+))$/;

	$line     =  $DB::line   if $line eq '.';
	$file     =  file( $file );

	my $traps =  DB::traps( $file );


	unless( $expr ) {
		require Data::Dump;

		for( defined $line ? ( $line ) : sort{ $a <=> $b } keys %$traps ) {
			next   unless exists $traps->{ $_ }{ action };

			print $DB::OUT "line $_:\n";
			print $DB::OUT "  " .Data::Dump::pp( $_ ) ."\n"
				for @{ $traps->{ $_ }{ action } };
		}

		return 1;
	}


	unless( DB::can_break( $file, $line ) ) {
		print $DB::OUT file(). "This line is not breakable. Can not set action at this point\n";
		return -1;
	}


	push @{ $traps->{ $line }{ action } }, $expr;

	return 1;
}


$DB::commands =  {
	'.' => sub {
		$curr_file =  $DB::file;
		$line_cursor =  $DB::line;

		print $DB::OUT "$DB::file:$DB::line    " .(DB::source()->[ $DB::line ] =~ s/^(\s+)//r); #/

		1;
	},

	,st => sub {
		require Data::Dump;
		print $DB::OUT Data::Dump::pp( \@DB::stack, \@DB::goto_frames );
		print $DB::OUT "S: $DB::single T:$DB::trace A:$DB::signal\n";

		1;
	}

	# Return from sub call to the first OP at some outer frame
	# In compare to 's' and 'n' commands 'r' will not stop at each OP. So we set
	# 0 to $DB::single for current frame and N-1 last frames. For target N frame
	# we set $DB::single value to 1 which will be restored at &pop_frame
	# Therefore DB::DB will be called at the first OP followed this sub call
	,r => sub {
		return -1   unless @DB::stack;

		my( $frames_out, $sharp ) =  shift =~ m/^(\d+)(\^)?$/;

		$frames_out //=  1;

		$frames_out =  @DB::stack -$frames_out   if $sharp;
		return -2   if $frames_out < 0; # Do nothing for unexisting frame

		# Return to the last possible frame
		# Q: Should we return from whole script?
		$frames_out =  @DB::stack   if $frames_out > @DB::stack;

		# Skip the current frame we are in ...
		$DB::single =  0;;

		# ... skip N next frames
		$_->{ single } =  0   for @DB::stack[ -($frames_out-1) .. -1 ];

		# and stop at some outer frame
		$_->{ single } =  1   for @DB::stack[ -@DB::stack .. -$frames_out ];

		return;
	}

	# Do single step to the next OP
	# Here we force $DB::single = 1 for current frame and all outer frames.
	# Because current OP maybe the last OP in sub. It also maybe the last OP in
	# the outer frame. And so on.
	,s => sub {
		( $DB::steps_left ) =  shift =~ m/^(\d+)$/;
		$DB::single =  1;
		$_->{ single } =  1   for @DB::stack;

		return;
	}

	# Do single step to the next OP. If current OP is sub call. Step over it
	# ...As for the 's' command we stop at each OP in the script. But when the
	# sub is called we turn off debugging for that sub at DB::sub.
	# spy( 0 )   if $DB::single & 2;
	# After that sub returns $DB::single will be restored because of localizing
	# Therefore DB::DB will be called at the first OP followed this sub call
	,n => sub {
		( $DB::steps_left ) =  shift =~ m/^(\d+)$/;
		$DB::single =  2;
		# If the current OP is last OP in this sub we stop at *some* outer frame
		$_->{ single } =  2   for @DB::stack;

		return;
	}

	# Quit from the debugger
	,q => sub { $DB::single =  0; exit; }

	# TODO: print list of vars which refer this one
	,vars => sub {
		my $type  =  0;
		my $level =  0;
		my @vars  =  ();
		for( split " ", shift ) {
			$type |= ~0   if /^a|all$/;
			$type |= 1    if /^m|my$/;
			$type |= 2    if /^o|our$/;
			$type |= 4    if /^g|global$/;
			$type |= 8    if /^u|used$/;
			$type |= 16   if /^c|closured$/;
			$type |= 24   if /^s|sub$/;       #u+c

			$level =  $1  if /^(\d+)$/;
			push @vars, $1   if /^([\%\$\@]\S+)$/;
		}

		my $dbg_frames =  6;     # Count of debugger frames
		$type ||=  3;  # TODO: make defaults configurable
		$level +=  $dbg_frames;  # The first client frame

		require 'PadWalker.pm';
		require 'Package/Stash.pm'; # BUG? spoils DB:: by emacs, dbline

		my $my =   PadWalker::peek_my(  $level );
		my $our =  PadWalker::peek_our( $level );

		if( $type & 1 ) {
			# TODO: for terminals which support color show
			# 1. not used variables as grey
			# 2. closed over variables as green or bold
			print $DB::OUT "\nMY:\n", join( ', ', sort keys %$my ), "\n";
		}

		if( $type & 2 ) {
			print $DB::OUT "\nOUR:\n", join( ', ', sort keys %$our ), "\n";
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

			my @globals =  ();
			my %sigil =  ( SCALAR => '$', ARRAY => '@', HASH => '%' );
			for my $key ( keys %$stash ) {
				my $glob =  $stash->{ $key };
				for my $type ( keys %sigil ) {
					next   unless defined *{ $glob }{ $type };
					next   if $type eq 'SCALAR'  &&  !defined $$glob;
					next   if $key =~ /::/;
					push @globals, $sigil{ $type } .$key;
				}
			}

			print $DB::OUT "\nGLOBAL:\n", join( ', ', sort @globals ), "\n";
		}

		if( $type & 8 ) {
			print $DB::OUT "\nUSED:\n";

			my $sub =  $DB::stack[ -$level +$dbg_frames -1 ]{ sub };
			if( !defined $sub ) {
				# TODO: Mojolicious::__ANON__[/home/feelsafe/perl_lib/lib/perl5/Mojolicious.pm:119]
				# convert this to subroutine refs
				# print $DB::OUT "Not in a sub: $sub\n";
				print $DB::OUT "Not in a sub\n";
			}
			else {
				print $DB::OUT join( ', ', sort keys %{ PadWalker::peek_sub( $sub ) } ), "\n";
			}
		}

		if( $type & 16 ) {
			print $DB::OUT "\nCLOSED OVER:\n";

			my $sub =  $DB::stack[ -$level +$dbg_frames -1 ]{ sub };
			if( !defined $sub ) {
				print $DB::OUT "Not in a sub\n";
				# print $DB::OUT (ref $sub ) ."Not in a sub: $sub\n";
			}
			else {
				print $DB::OUT join( ', ', sort keys %{ (PadWalker::closed_over( $sub ))[0] } ), "\n";
			}
		}

		if( @vars ) {
			# print $DB::OUT @{ $my }{ @vars }, @{ $our }{ @vars };
			print $DB::OUT @vars; # FIX: use dumper
		}

		1;
	}
	,B => sub {
		my( $args, $opts ) =  @_;
		$opts->{ verbose } //=  1;

		if( $_[0] eq '*' ) {
			#TODO: implement removing all traps
			#B 3:* - remove all traps from file number 3
		}


		my( $file, $line, $subname ) =  shift =~ m/^${file_line}|([\w:]+|&)$/;


		if( defined $subname ) {
			if( $subname eq '&' ) {
				$subname =  $DB::goto_frames[ -1 ][ 3 ];
				return -1   if ref $subname; # can not set trap on coderef
			}
			delete $DB::stop_in_sub{ $subname };
			# Q: Should we remove all matched keys?
			# A: No. You may remove required keys. Maybe *subname?
		}
		else {
			$line     =  $DB::line   if $line eq '.';
			my $traps =  DB::traps( file( $file, 1 ) );
			return -1   unless exists $traps->{ $line };


			# Q: Why deleting a key does not remove a breakpoint for that line?
			# A: Because this is the internal hash
			# WORKAROUND: we should explicitly set value to 0 then delete the key
			$traps->{ $line } =  0;
			delete $traps->{ $line };
		}


		$DB::commands->{ b }->()   if $opts->{ verbose };

		1;
	}

	,b => sub {
		my( $sign, $file, $line, $subname, $condition, $tmp ) =
			shift =~ m/^([-+])?(?:${file_line}|([\w:]+|&))(?:\s+(.*?))?(!)?$/;


		if( defined $subname ) {
			if( $subname eq '&' ) {
				$subname =  $DB::goto_frames[ -1 ][ 3 ];
				return -1   if ref $subname; # can not set trap on coderef
			}
			$DB::stop_in_sub{ $subname } =
				defined $sign  &&  $sign eq '-' ? 0 : 1;
			return 1;
		}


		$line     =  $DB::line   if $line eq '.';
		$file     =  file( $file, 1 );


		# list all breakpoints
		unless( $line ) {
			$cmd_f =  [];
			my $file_no =  0;
			# First display traps in the current file
			print $DB::OUT "Breakpoints:\n";
			for my $source ( $file, grep { $_ ne $file } keys %$DB::_tfiles ) {
				my $traps =  DB::traps( $source );
				next   unless keys %$traps;

				push @$cmd_f, $source;
				print $DB::OUT $file_no++ ." $source\n";

				for( sort{ $a <=> $b } keys %$traps ) {
					# FIX: the trap may be in form '293 => {}' in this case
					# we do not see it ever
					next   unless exists $traps->{ $_ }{ condition }
						||  exists $traps->{ $_ }{ onetime }
						||  exists $traps->{ $_ }{ disabled }
						;

					printf $DB::OUT "  %-3d%s %s\n"
						,$_
						,exists $traps->{ $_ }{ onetime }      ? '!'
							:(exists $traps->{ $_ }{ disabled } ? '-' : ':')
						,$traps->{ $_ }{ condition }
						;

					warn "The breakpoint at $_ is zero and should be deleted"
						if $traps->{ $_ } == 0;
				}
			}

			print $DB::OUT "Stop on subs:\n";
			print $DB::OUT ' ' .($DB::stop_in_sub{ $_ } ? ' ' : '-') ."$_\n"
				for keys %DB::stop_in_sub;

			return 1;
		}


		# set breakpoint
		unless( DB::can_break( $file, $line ) ) {
			print $DB::OUT file(). " -- $file This line is not breakable\n";
			# Set breakpoint in any case. This is usefull when you edit file
			# and want to add traps to those new lines
			# return -1;
		}

		my $traps =  DB::traps( $file );

		# One time trap just exists or not.
		# We stop on it uncoditionally, also we can not disable it
		if( defined $tmp ) {
			$traps->{ $line }{ onetime } =  undef;
		}
		else {
			# TODO: Move trap from/into $traps into/from $disabled_traps
			# This will allow us to not trigger DB::DB if trap is disabled
			$traps->{ $line }{ disabled } =  1     if $sign eq '-';
			delete $traps->{ $line }{ disabled }   if $sign eq '+';

			$traps->{ $line }{ condition } =  $condition   if defined $condition;
			$traps->{ $line }{ condition } //=  1; # trap always triggered by default
		}

		1;
	}

	,go => sub {
		# If we supply line to go to we set temporary trap in it
		if( defined $_[0]  &&  $_[0] ne '' ) {
			return 1   if 0 > $DB::commands->{ b }->( "$_[0]!" );
		}


		$DB::single =  0;
		$_->{ single } =  0   for @DB::stack;


		return;
	}

	,f => sub {
		my( $args, $expr ) =  @_;

		# Set current file to selected one:
		if( $args ne ''  &&  $args =~ /^(\d+)$/ ) {
			print $DB::OUT file( $args ) ."\n";
			return 1;
		}

		# List available files
		$cmd_f   =  [];
		my $file_no =  0;
		for( sort $0, values %INC, DB::sources() ) {
		# for( sort $0, keys %$expr ) {
			if( /(?:$args)/ ) {
				push @$cmd_f, $_;
				print $DB::OUT $file_no++ ." $_\n";
			}
		}

		1;
	}
	,e => sub {
		require Data::Dump;

		return {
			expr => shift,
			code => sub {
				print $DB::OUT Data::Dump::pp( @_ ) ."\n";
			}
		}
	}

	# TODO: give names to ANON
	,T => sub {
		my( $level ) =  shift =~ m/^(\d+)$/;
		$level =  -1   unless $level;

		my $T =  {()
			,oneline   =>
				'"\n$d $type $context $subname$args <--  $file:$line\n"'
			,multiline =>
				'"\n$d $type $subname\n    $context $args\n    <--  $file:$line\n"'
		};
		my $format =  'multiline';

		my @frames =  DB::frames();
		my $deep   =  @frames;
		for my $frame ( @frames ) {
			my $context =  $frame->[7]? '@' : defined $frame->[7]? '$' : ';';
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
			print $DB::OUT eval $T->{ $format };
			$deep--  if $frame->[0] ne 'G';
			last   unless --$level;
		}

		return 1;
	}

	,l    => \&list
	,w    => \&watch
	,load => \&load
	,save => \&save
	,pid  => sub {
		print $DB::OUT Devel::DebugHooks::Server::tinfo();
		return 1;
	}
	,t    => \&trace_variable
	,a    => \&action
	,A    => sub {
		my( $args, $opts ) =  @_;

		if( $_[0] eq '*' ) {
			#TODO: implement removing all actions
			#B 3:* - remove all traps from file number 3
		}


		my( $file, $line ) =  shift =~ m/^${file_line}$/;


		$line     =  $DB::line   if $line eq '.';
		my $traps =  DB::traps( file( $file, 1 ) );
		return -1   unless exists $traps->{ $line };


		# TODO: remove only one action by number
		delete $traps->{ $line }{ action };
		unless( keys %{ $traps->{ $line } } ) {
			$traps->{ $line } =  0;
			delete $traps->{ $line };
		}

		1;
	}
	,ge   => sub {
		my( $file, $line ) =  shift =~ m/^${file_line}$/;
		$line =  $DB::line   unless defined $line;
		$file =  file( $file );

		`rsub $file`;

		1;
	}
	,gef   => sub {
		my( $file, $line ) =  shift =~ m/^${file_line}$/;
		$line =  $DB::line   unless defined $line;
		$file =  file( $file );

		`rsub -f $file`;

		1;
	}
	,suspend => sub {
		uwsgi::suspend();

		1;
	}
	,R => sub {
		`killall uwsgi`;
	}
};

1;

__END__
FIX:
   x380:     if( $errors =  !$self->_check( $self->validation ) ) {                     #2
    x381:         warn [ $self->validation ];
    x382:     } elsif( $errors =  $self->_save( $self->validation ) ) {       #3
     383:     }
     384:     else {
     385:         # inside 'saved' we may return uri to redirect to
  >>x386:         $redirect_page =  $self->_saved( $self->validation );          #4-a
     387:     }

 if we 'n' from last expression of _check we do not stop on _save

FIX: do not create new trap if it not exists before 'b +...' command
