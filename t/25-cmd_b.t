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
