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
	n( `perl $lib -d:DbInteract='b 3;go;q' -e '$script'` )
	,$files->{ 'stop by line' }
	,"Stop on trap by line";



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
	n( `perl $lib -d:DbInteract='b 2;b 9;go;go;s' -e '$script'` )
	,$files->{ 'stop by line in sub' }
	,"Stop on trap by line in sub then outside of it";


__DATA__
@@ list empty traps
-e:0001  1;
Breakpoints:
Stop on subs:
@@ list one trap
-e:0001  1;
Breakpoints:
0 -e
1: 1
Stop on subs:
@@ list two traps
-e:0001  1;
Breakpoints:
0 -e
1: 1
3: 1
Stop on subs:
@@ stop by line
-e:0001  1;
-e:0003  3;
@@ stop by line in sub
-e:0008  t2();
-e:0002    1;
-e:0009  3;
