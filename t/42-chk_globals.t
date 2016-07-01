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
	print sort{
		$a <=> $b
	} qw/ 3 1 2 /;
PERL

is
	n( `$^X $lib -d:DbInteract='off;s 2;\$a;\$b;go' -e '$script'` ) ."\n"
	,$files->{ 'anb' }
	,"\$a \$b should not be changed by debugger";



SKIP: {
    eval { require List::Util };
    skip "List::Util is not installed"   if $@;

    List::Util->import( qw/ pairmap / );


	($script =  <<'	PERL') =~ s#^\t+##gm;
		use List::Util qw/ pairmap /;
		print pairmap{
			"$a - $b"
		} qw/ 1 2 3 4 /;
	PERL

	# RT#115608 Guard's ENTER/LEAVE force List::Util to use $DB::a variable under debugger
	TODO: {
		local $TODO =  "FIX: List::Util should not notice debugger";
		is
			n( `$^X $lib -d:DbInteract='off;s 2;\$a;\$b;go' -e '$script'` ) ."\n"
			,$files->{ 'ab context' }
			,"Debugger should not change context";
	}
}



__DATA__
@@ anb
-e:0002    $a <=> $b
1
2
123
@@ ab context
-e:0004  } qw/ 1 2 3 4 /;
3
4
1 - 23 - 4