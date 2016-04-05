#!/usr/bin/env perl


use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;
use FindBin qw/ $Bin /;  my $lib =  "$Bin/lib";
use Data::Section::Simple qw/ get_data_section /;

use Test::Differences;
unified_diff();
{
	no warnings qw/ redefine prototype /;
	*is =  \&eq_or_diff;
}



my $files =  get_data_section();


my $script =  <<'PERL' =~ s#^\t##rgm;
	1;
	2;
	3;
PERL

is
	`perl -I$lib -d:DbInteract -e '$script'`
	,$files->{ 'step-by-step' }
	,"Step-by-step debugging";



__DATA__
@@ step-by-step
-e:0001  1;
-e:0002  2;
-e:0003  3;
