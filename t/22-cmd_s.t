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
	n( `perl $lib -d:DbInteract='s;q' -e '$script'` )
	,$files->{ 'sbs' }
	,"Step-by-step debugging. Step into";



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
	n( `perl $lib -d:DbInteract='s;s;q' -e '$script'` )
	,$files->{ 'step into sub' }
	,"Step into sub";

is
	n( `perl $lib -d:DbInteract='go 2;s;q' -e '$script'` )
	,$files->{ 'step from sub' }
	,"Step from sub";



$script =  <<'PERL' =~ s#^\t##rgm;
	sub t1 {
		1;
	}
	sub t2 {
		t1();
	}
	t2();
	3;
PERL

is
	n( `perl $lib -d:DbInteract='go 2;s;q' -e '$script'` )
	,$files->{ 'double step from sub' }
	,"Double step from sub";


__DATA__
@@ sbs
-e:0001  1;
-e:0002  2;
@@ step into sub
-e:0008  t2();
-e:0005    t1();
-e:0002    1;
@@ step from sub
-e:0008  t2();
-e:0002    1;
-e:0006    2;
@@ double step from sub
-e:0007  t2();
-e:0002    1;
-e:0008  3;
