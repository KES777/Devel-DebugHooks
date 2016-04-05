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
	n( `perl $lib -d:DbInteract='go' -e '$script'` )
	,$files->{ go }
	,"Run script until the end";


__DATA__
@@ go
-e:0001  1;
