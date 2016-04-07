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
	sub t1 {
		1;
		2;
	}
	sub t2 {
		t1();
		3;
	}
	t2();
	4;
PERL

is
	n( `perl $lib -d:DbInteract='s;s;r;r' -e '$script'` )
	,$files->{ return }
	,"Returning from subroutine";

is
	n( `perl $lib -d:DbInteract='go 2;r;r' -e '$script'` )
	,$files->{ 'return and stop' }
	,'Returning from subroutine. Stop at upper frame';

is
	n( `perl $lib -d:DbInteract='r;s;q' -e '$script'` )
	,$files->{ 'return from main' }
	,'Return from main:: should do nothing';


$script =  <<'PERL' =~ s#^\t##rgm;
	sub t0 {
		1;
	}
	sub t1 {
		t0();
		2;
	}
	sub t2 {
		t1();
		3;
	}
	t2();
	4;
PERL

is
	n( `perl $lib -d:DbInteract='s;s;s;r 1;q' -e '$script'` )
	,$files->{ 'return 1' }
	,'Returning from 1 subroutine';

is
	n( `perl $lib -d:DbInteract='s;s;s;r 2;q' -e '$script'` )
	,$files->{ 'return 2' }
	,'Returning from 2 subroutines';

is
	n( `perl $lib -d:DbInteract='s;s;s;r 3;q' -e '$script'` )
	,$files->{ 'return 3' }
	,'Returning from 3 subroutines';
# IT: @DB::stack -> 0 2 1 0
# my $cmds =  '@DB::stack;go 2;@DB::stack;r;@DB::stack;r;@DB::stack';


__DATA__
@@ return
-e:0009  t2();
-e:0006    t1();
-e:0002    1;
-e:0007    3;
-e:0010  4;
@@ return and stop
-e:0009  t2();
-e:0002    1;
-e:0007    3;
-e:0010  4;
@@ return from main
-e:0009  t2();
-e:0006    t1();
@@ return 1
-e:0012  t2();
-e:0009    t1();
-e:0005    t0();
-e:0002    1;
-e:0006    2;
@@ return 2
-e:0012  t2();
-e:0009    t1();
-e:0005    t0();
-e:0002    1;
-e:0010    3;
@@ return 3
-e:0012  t2();
-e:0009    t1();
-e:0005    t0();
-e:0002    1;
-e:0013  4;
