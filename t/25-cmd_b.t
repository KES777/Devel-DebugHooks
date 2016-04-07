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



my $script;
my $files =  get_data_section();


$script =  <<'PERL' =~ s#^\t##rgm;
	1;
	2;
	3;
PERL

is
	n( `perl $lib -d:DbInteract='b;q' -e '$script'` )
	,$files->{ 'list empty traps' }
	,"Empty traps list";

is
	n( `perl $lib -d:DbInteract='b 1;b;q' -e '$script'` )
	,$files->{ 'list one trap' }
	,"Put one trap. List traps";

is
	n( `perl $lib -d:DbInteract='b 1;b 3;b;q' -e '$script'` )
	,$files->{ 'list two traps' }
	,"Put two traps. List traps";

is
	n( `perl $lib -d:DbInteract='b t1;b;q' -e '$script'` )
	,$files->{ 'list trap on sub name' }
	,"Put trap by sub name";

is
	n( `perl $lib -d:DbInteract='b 3;go;q' -e '$script'` )
	,$files->{ 'stop by line' }
	,"Stop on trap by line";

is
	n( `perl $lib -d:DbInteract='b 3 2<7;go' -e '$script'` )
	,$files->{ 'stop by true expr' }
	,"Stop on trap with expression evaluated to true";

is
	n( `perl $lib -d:DbInteract='b 3 2>7;go' -e '$script'` )
	,$files->{ 'dont stop by false expr' }
	,"Do not stop on trap with expression evaluated to false";

is
	n( `perl $lib -d:DbInteract='b 3 2>7;b;b -3 1<3;b;q' -e '$script'` )
	,$files->{ 'trap state changed' }
	,"Trap state should be changed by new values";



$script =  <<'PERL' =~ s#^\t##rgm;
	sub t1 {
		1;
	}
	sub t2 {
		t1();
		2;
	}
	t2();
	3;
PERL

is
	n( `perl $lib -d:DbInteract='b 2;b 9;go;go;\@DB::stack' -e '$script'` )
	,$files->{ 'stop by line in sub' }
	,"Stop on trap by line in sub then outside of it";

is
	n( `perl $lib -d:DbInteract='b t1;go;s;\@DB::stack;s' -e '$script'` )
	,$files->{ 'stop by sub name' }
	,"Stop on trap by subroutine name";



$script =~  s/t1\(\)/goto &t1/;
is
	n( `perl $lib -d:DbInteract='b t1;go;s;\@DB::stack' -e '$script'` )
	,$files->{ 'stop by sub name. goto' }
	,"Stop on trap by subroutine name reached from goto";

is
	n( `perl $lib -d:DbInteract='b 2;b -2;go' -e '$script'` )
	,$files->{ '!stop on disabled' }
	,"Do not stop on disabled traps";

is
	n( `perl $lib -d:DbInteract='b 2;b -2;b +2;go;s' -e '$script'` )
	,$files->{ 'stop on enabled' }
	,"Stop on enabled traps";

is
	n( `perl $lib -d:DbInteract='b 2;b -2;b;q' -e '$script'` )
	,$files->{ 'list disabled' }
	,"List disabled traps";

is
	n( `perl $lib -d:DbInteract='b 2;b -2;b +2;b;q' -e '$script'` )
	,$files->{ 'list enabled' }
	,"List enabled traps";

is
	n( `perl $lib -d:DbInteract='b 2 2>7;b -2;b +2;b;q' -e '$script'` )
	,$files->{ 'list conditional reenabled' }
	,"List conditional reenabled trap";

is
	n( `perl $lib -d:DbInteract='b 2 2<7!;b;q' -e '$script'` )
	,$files->{ 'list onetime trap' }
	,"List onetime trap";

is
	n( `perl $lib -d:DbInteract='b 2!;go;b;q' -e '$script'` )
	,$files->{ 'onetime trap removed' }
	,"Onetime traps should be removed after triggering";

is
	n( `perl $lib -d:DbInteract='b -2 2>7;b;b 2!;b;go;b;q' -e '$script'` )
	,$files->{ 'onetime trap not affect' }
	,"Onetime trap does not affect common trap";

is
	n( `perl $lib -d:DbInteract='b 2 2>7;b;b 2!;b;go;b;q' -e '$script'` )
	,$files->{ 'onetime trap not affected' }
	,"Onetime trap should not affected by common trap";



__DATA__
@@ list empty traps
-e:0001  1;
Breakpoints:
Stop on subs:
@@ list one trap
-e:0001  1;
Breakpoints:
0 -e
  1  : 1
Stop on subs:
@@ list two traps
-e:0001  1;
Breakpoints:
0 -e
  1  : 1
  3  : 1
Stop on subs:
@@ list trap on sub name
-e:0001  1;
Breakpoints:
Stop on subs:
  t1
@@ stop by line
-e:0001  1;
-e:0003  3;
@@ stop by true expr
-e:0001  1;
-e:0003  3;
@@ dont stop by false expr
-e:0001  1;
@@ trap state changed
-e:0001  1;
Breakpoints:
0 -e
  3  : 2>7
Stop on subs:
Breakpoints:
0 -e
  3  - 1<3
Stop on subs:
@@ stop by line in sub
-e:0008  t2();
-e:0002    1;
-e:0009  3;
0
@@ stop by sub name
-e:0008  t2();
-e:0002    1;
-e:0006    2;
1
-e:0009  3;
@@ stop by sub name. goto
-e:0008  t2();
-e:0002    1;
-e:0009  3;
0
@@ !stop on disabled
-e:0008  t2();
@@ stop on enabled
-e:0008  t2();
-e:0002    1;
-e:0009  3;
@@ list disabled
-e:0008  t2();
Breakpoints:
0 -e
  2  - 1
Stop on subs:
@@ list enabled
-e:0008  t2();
Breakpoints:
0 -e
  2  : 1
Stop on subs:
@@ list conditional reenabled
-e:0008  t2();
Breakpoints:
0 -e
  2  : 2>7
Stop on subs:
@@ list onetime trap
-e:0008  t2();
Breakpoints:
0 -e
  2  ! 
Stop on subs:
@@ onetime trap removed
-e:0008  t2();
-e:0002    1;
Breakpoints:
Stop on subs:
@@ onetime trap not affect
-e:0008  t2();
Breakpoints:
0 -e
  2  - 2>7
Stop on subs:
Breakpoints:
0 -e
  2  ! 2>7
Stop on subs:
-e:0002    1;
Breakpoints:
0 -e
  2  - 2>7
Stop on subs:
@@ onetime trap not affected
-e:0008  t2();
Breakpoints:
0 -e
  2  : 2>7
Stop on subs:
Breakpoints:
0 -e
  2  ! 2>7
Stop on subs:
-e:0002    1;
Breakpoints:
0 -e
  2  : 2>7
Stop on subs:
