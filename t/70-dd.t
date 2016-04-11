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
	s#(?:.*?)?([^/]+\.p(?:m|l))#xxx/$1#gm;

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


$script =  <<'PERL' =~ s#^\t##rgm;
	sub t1 {
		1;
	}
	t1();
	2;
PERL

$cmds =  ' $DB::options{ dd } =  1;n;s;s 2;q';
is
	nl( `perl $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'step into debugger' }
	,"Step into debugger";

$cmds =  ' $DB::options{ dd } =  1;n;n;q';
is
	nl( `perl $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'step over' }
	,"Step over at debugger";

$cmds =  ' $DB::options{ dd } =  1;s;s;r;r;q';
is
	nl( `perl $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'return s' }
	,"Return from debugger. 's' command";

$cmds =  ' $DB::options{ dd } =  1;n;s;r;r;q';
is
	nl( `perl $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'return n' }
	,"Return from debugger. 'n' command";


__DATA__
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
