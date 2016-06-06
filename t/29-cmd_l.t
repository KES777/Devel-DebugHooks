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
	s#(?:[^\s]*?)?([^/]+\.p(?:m|l))#xxx/$1#gm;

	$_;
}



sub nl {
	$_ =  n( @_ );

	s#(xxx/.*?pm:)\d+#$1XXXX#gm;

	$_;
}



my $cmds;
my $script;
my $files =  get_data_section();


($script =  <<'PERL') =~ s#^\t##gm;
	sub t {
		2;
	}

	1;
	t();
PERL

is
	n( `$^X $lib -d:DbInteract='b 2;a 2 1;s 2;l .;q' -e '$script'` )
	,$files->{ 'list' }
	,"List the source code";



__DATA__
@@ list
-e:0005  1;
-e:0002    2;
-e
    x0: use Devel::DbInteract split(/,/,q{b 2;a 2 1;s 2;l .;q});;
     1: sub t {
ab>>x2:     2;
     3: }
     4:
    x5: 1;
    x6: t();
     7:
