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
