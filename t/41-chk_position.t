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

sub nn {
        $_ =  n( @_ );

        s#( at ).*#$1...#;

        $_;
}



my $cmds;
my $script;
my $files =  get_data_section();



$script =  <<'PERL' =~ s#^\t##rgm;
	1;
	2;
	3;
PERL

$cmds =  'e [ $DB::package => $DB::file => $DB::line ];s;' x3;
is
	n( `perl $lib -d:DbInteract='$cmds' -e '$script'` )
	,$files->{ 'position' }
	,'Position should be updated for each step';



__DATA__
@@ position
-e:0001  1;
["main", "-e", 1]
-e:0002  2;
["main", "-e", 2]
-e:0003  3;
["main", "-e", 3]
