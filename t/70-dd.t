#!/usr/bin/env perl


use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;
use FindBin qw/ $Bin /;  my $lib =  "-I$Bin/lib -I$Bin/../lib";
use Data::Section::Simple qw/ get_data_section /;

use Test::Differences;
unified_diff();
{
	no warnings qw/ redefine prototype /;
	*is =  \&eq_or_diff;
}



sub n {
	$_ =  join '', @_;

	s#\t#  #gm;
	s#(?:[^\s]*?)?([^/]+\.p(?:m|l))#xxx/$1#gm;

	$_;
}



sub nl {
	$_ =  n( @_ );

	s#(xxx/.*?pm:)\d+#$1XXXX#gm;

	$_;
}



my $cmds;
my $script;
my $files =  get_data_section();


($script =  <<'PERL') =~ s#^\t##gm;
	sub t1 {
		1;
	}
	t1();
	2;
PERL

# FIX: we should not require last 's' to see '-e:0002    1;'
$cmds =  ' $DB::options{ dd } =  1;debug;s 9;s;s;s;s;s;r 2;s;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'debug cmd sbs' }
	,"Debug command step-by-step";

$cmds =  ' $DB::options{ dd } =  1;debug;s 9;s;n;r 2;s;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'debug cmd step over' }
	,"Debug command with step over";

$cmds =  ' $DB::options{ dd } =  1;debug;s 9;s 2;r;r 2;s;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'debug cmd return' }
	,"Debug command with return";

$cmds =  ' $DB::options{ dd } =  1;debug;s 9;s 2;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'debug cmd quit' }
	,"Quit from debug debugger command process";



$cmds =  ' $DB::options{ dd } =  1;debug;s 9;right();q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'call debugger sub' }
	,"Subroutine call from debugger scope when debug debugger command";



$cmds =  ' $DB::options{ dd } =  1;s;r;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'outer step into' }
	,"Step into at client's scipt after debugger debugging";

$cmds =  ' $DB::options{ dd } =  1;n;r;q';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'outer step over' }
	,"Step over at client's scipt after debugger debugging";

$cmds =  ' $DB::options{ dd } =  1;global;global;r;q;';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'wrong global vars usage' }
	,"Debugger commands should not use any global variables";

$cmds =  ' $DB::options{ dd } =  1;right_global;right_global;r;q;';
is
	nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'global vars usage' }
	,"Debugger globals per instance";


TODO: {
	local $TODO =  'Implemented debugging for push/pop frame';

	$cmds =  ' $DB::options{ dd } =  1;n;s;s 2;q';
	is
		nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
		,$files->{ 'step into debugger' }
		,"Step into debugger";

	$cmds =  ' $DB::options{ dd } =  1;n;n;q';
	is
		nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
		,$files->{ 'step over' }
		,"Step over at debugger";

	$cmds =  ' $DB::options{ dd } =  1;s;s;r;r;q';
	is
		nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
		,$files->{ 'return s' }
		,"Return from debugger. 's' command";

	$cmds =  ' $DB::options{ dd } =  1;n;s;r;r;q';
	is
		nl( `$^X $lib -d:DbInteract='$cmds' -e '$script'` )
		,$files->{ 'return n' }
		,"Return from debugger. 'n' command";
}


__DATA__
@@ debug cmd sbs
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
xxx/DbInteract.pm:XXXX    1;
xxx/DbInteract.pm:XXXX    nested();
xxx/DbInteract.pm:XXXX    2;
xxx/DbInteract.pm:XXXX    printf $DB::OUT "%s at %s:%s\n"
1 at -e:4
xxx/DbInteract.pm:XXXX    3;
xxx/DbInteract.pm:XXXX    4;
-e:0002    1;
@@ debug cmd step over
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
xxx/DbInteract.pm:XXXX    1;
xxx/DbInteract.pm:XXXX    nested();
1 at -e:4
xxx/DbInteract.pm:XXXX    4;
-e:0002    1;
@@ debug cmd return
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
xxx/DbInteract.pm:XXXX    1;
xxx/DbInteract.pm:XXXX    2;
1 at -e:4
xxx/DbInteract.pm:XXXX    4;
-e:0002    1;
@@ debug cmd quit
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
xxx/DbInteract.pm:XXXX    1;
xxx/DbInteract.pm:XXXX    2;
@@ call debugger sub
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
xxx/DbInteract.pm:XXXX    1;
scope
@@ outer step into
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
-e:0002    1;
@@ outer step over
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
-e:0005  2;
@@ wrong global vars usage
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
1
2
@@ global vars usage
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    &{ $DB::options{ cmd_processor } .'::process' }( @_ );
1
1
@@ step into debugger
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    test();
xxx/DebugHooks.pm:XXXX    1;
xxx/DebugHooks.pm:XXXX    3;
@@ step over
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    test();
xxx/DebugHooks.pm:XXXX    3;
@@ return s
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    test();
xxx/DebugHooks.pm:XXXX    1;
xxx/DebugHooks.pm:XXXX    3;
-e:0002    1;
@@ return n
-e:0004  t1();
1
xxx/DebugHooks.pm:XXXX    test();
xxx/DebugHooks.pm:XXXX    1;
xxx/DebugHooks.pm:XXXX    3;
-e:0005  2;
