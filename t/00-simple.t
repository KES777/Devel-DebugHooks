#!/usr/bin/env perl


use strict;
use warnings;

use Test::More 'no_plan';
use Test::Output;
use FindBin qw/ $Bin /;  my $lib =  "$Bin/lib";
use Data::Section::Simple qw/ get_data_section /;



sub n {
	$_ =  join '', map{ defined $_ ? $_ : '&undef' } @_;

	s/(\(0x[\da-f]{6,}\))/(0x000000)/g;
	s#(?:/.*?)?([^/]+\.pm)#$1#gm;

	$_;
}


sub normalize {
	my $files =  shift;

	for my $key ( keys %$files ) {
		$files->{ $key } =  n( $files->{ $key } );
	}

	return $files;
}



my $files =  normalize( get_data_section() );



use_ok( 'Devel::DebugHooks', 'use Devel::DebugHooks' );


# Debug zero value
is `perl -I$lib -d:DZV -e0`, "\n". $files->{ dzv }, "Debug zero value";


# Test flags for tracing messages
is
	n(`perl -I$lib -d:TraceLoadCT -e0`)
	,$files->{ TraceLoadCT }
	,"Set trace_load flag at compile time";

is
	n(`perl -I$lib -d:TraceLoadCT -e 'use Empty'`)
	,$files->{ TraceLoadCT_Empty }
	,"Set trace_load flag at compile time with usage";

is
	n(`perl -I$lib -d:TraceRT=trace_load -e0`)
	,$files->{ TraceLoadRT }
	,"Set trace_load flag at run time";

is
	n(`perl -I$lib -d:TraceRT=trace_load -e 'use Empty'`)
	,$files->{ TraceLoadRT_Empty }
	,"Set trace_load flag at run time with usage";


# sub calls
is
	n(`perl -I$lib -d:TraceSubsCT -e 'sub test{};  test();'`)
	,"\n" .$files->{ TraceSubsCT }
	,"Set trace_subs flag at compile time";

is
	n(`perl -I$lib -d:TraceRT=trace_subs -e 'sub test{};  test();'`)
	,"\n" .$files->{ TraceSubsRT }
	,"Set trace_subs flag at run time";

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e 'sub test{};  test( str => 7, [], {}, undef );'` )
	,"\n". $files->{ TraceSubs_args }
	,"Check passed arguments to sub call";


# Check context
is
	n(`perl -I$lib -d:TraceRT=trace_subs -e 'sub test{};  test();'`)
	,"\n" .$files->{ TraceSubs_call_void }
	,"Check void context for sub call";

is
	n(`perl -I$lib -d:TraceRT=trace_subs -e 'sub test{};  \$s =  test();'`)
	,"\n" .$files->{ TraceSubs_call_scalar }
	,"Check scalar context for sub call";

is
	n(`perl -I$lib -d:TraceRT=trace_subs -e 'sub test{};  \@l =  test();'`)
	,"\n" .$files->{ TraceSubs_call_list }
	,"Check list context for sub call";


# return values
my $script;
$script =  'sub test{ return [], {}, undef };  test();';
is
	n( `perl -I$lib -d:TraceRT=trace_returns -e '$script'` )
	,"\n" .$files->{ TraceReturns_void }
	,"Check return values from sub call at void context";

$script =  'sub test{ return [], {}, undef };  $s = test();';
is
	n( `perl -I$lib -d:TraceRT=trace_returns -e '$script'` )
	,"\n". $files->{ TraceReturns_scalar }
	,"Check return values from sub call at scalar context";

$script =  'sub test{ return [], {}, undef };  @l = test();';
is
	n( `perl -I$lib -d:TraceRT=trace_returns -e '$script'` )
	,"\n". $files->{ TraceReturns_list }
	,"Check return values from sub call at list context";


# goto frames
$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
t2();
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e '$script'` )
	,"\n". $files->{ TraceGoto_one }
	,"Check goto frames. One level";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
sub t3{ t2() };
sub t4{ goto &t3; }
sub t5{ goto &t4; }
t5();
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e '$script'` )
	,"\n". $files->{ TraceGoto_deep }
	,"Check goto frames. Deep level";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
t2( 3 );
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e '$script'` )
	,"\n". $files->{ TraceGoto_one_with_args }
	,"Check goto frames. One level with args";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
sub t3{ t2( 5 ) };
sub t4{ goto &t3; }
sub t5{ goto &t4; }
t5( 7 );
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e '$script'` )
	,"\n". $files->{ TraceGoto_deep_with_args }
	,"Check goto frames. Deep level with args";



# print "ZZZZZZZZZZZZZZZ\n";
# print n `perl -I$lib -d:TraceRT=trace_subs -e '$script'`;

__DATA__
@@ dzv
 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:1    0
@@ TraceLoadCT
Loaded '*main::_</lib/Devel/DebugHooks.pm'
Loaded '*main::_</lib/Devel/TraceLoadCT.pm'
Loaded '*main::_<-e'
@@ TraceLoadCT_Empty
Loaded '*main::_<DebugHooks.pm'
Loaded '*main::_<TraceLoadCT.pm'
Loaded '*main::_<Empty.pm'
Loaded '*main::_<-e'
@@ TraceLoadRT
Loaded '*main::_<-e'
@@ TraceLoadRT_Empty
Loaded '*main::_<Empty.pm'
Loaded '*main::_<-e'
@@ TraceSubsCT
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: Devel::DebugHooks::import( Devel::TraceSubsCT )
TEXT: /lib/Devel/DebugHooks.pm:19-30

FROM: main --e -0 -Devel::DebugHooks::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubsRT
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_args
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::test( str, 7, ARRAY(0x000000), HASH(0x000000), &undef )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_void
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_scalar
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: scalar
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_list
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: list
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceReturns_void
 = = = = = = = = = = = = = = =
RETURNS:
>>NOTHING<<
 = = = = = = = = = = = = = = =
@@ TraceReturns_scalar
 = = = = = = = = = = = = = = =
RETURNS:
  &undef
 = = = = = = = = = = = = = = =
@@ TraceReturns_list
 = = = = = = = = = = = = = = =
RETURNS:
  ARRAY(0x000000)
  HASH(0x000000)
  &undef
 = = = = = = = = = = = = = = =
@@ TraceGoto_one
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::t2(  )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t1(  )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceGoto_deep
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::t5(  )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t4(  )
TEXT: -e:4-4

GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t3(  )
TEXT: -e:3-3

GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t2(  )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
GSUB: main::t1(  )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =
@@ TraceGoto_one_with_args
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::t2( 3 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t1( 3 )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceGoto_deep_with_args
 = = = = = = = = = = = = = = =
DEEP: 0
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t4( 7 )
TEXT: -e:4-4

GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t3( 7 )
TEXT: -e:3-3

GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
GSUB: main::t1( 5 )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =
