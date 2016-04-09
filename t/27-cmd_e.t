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



my $cmd;
my $script;
my $files =  get_data_section();


$script =  <<'PERL' =~ s#^\t##rgm;
	$x =  1;
	$x =  [ a => 1 ];
	$x =  { a => 1 };
	@x =  ( a => 1 );
	%x =  ( a => 1 );
	2;
PERL

$cmd =  's;$x;e $x;$x++;e $x;s;e $x;s;e $x;s;@x;e \@x;s;%x;e \%x;';
is
	n( `perl $lib -d:DbInteract='$cmd' -e '$script'` )
	,$files->{ 'eval' }
	,'Eval expressions at user context and dump them';



$script =  <<'PERL' =~ s#^\t##rgm;
	sub t {
		1;
	}
	t( 1, [], {} );
PERL

$cmd =  's;@_;e \@_';
is
	n( `perl $lib -d:DbInteract='$cmd' -e '$script'` )
	,$files->{ '@_ not clash' }
	,'Debugger\'s @_ should not clash with client\'s one';



__DATA__
@@ eval
-e:0001  $x =  1;
-e:0002  $x =  [ a => 1 ];
1
1
1
2
-e:0003  $x =  { a => 1 };
["a", 1]
-e:0004  @x =  ( a => 1 );
{ a => 1 }
-e:0005  %x =  ( a => 1 );
2
["a", 1]
-e:0006  2;
1/8
{ a => 1 }
@@ @_ not clash
-e:0004  t( 1, [], {} );
-e:0002    1;
3
[1, [], {}]
