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



sub n {
	$_ =  join '', map{ defined $_ ? $_ : '&undef' } @_;

	s/(\(0x[\da-f]{6,}\))/(0x000000)/g;
	s#(?:/.*?)?([^/]+\.pm)#$1#gm;
	s#^(\w{4}: .*?\.pm -)(\d+)#$1xxx#gm;
	s#(\.pm:)(\d+)-(\d+)$#$1xx-xx#gm;

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

my $script =  <<'PERL';
sub t1{ return 7; };
sub t2{ goto &t1 };
$x =  t2( 5, 'str' );
$x++;
PERL
is
	n( `perl -I$lib -d:DebugHooks -e '$script'` )
	, $files->{ VerboseBehaviour }
	, "Check verbose behaviour for demo purpose";


# Debug zero value
is `perl -I$lib -d:DZV -e0`, "\n". $files->{ dzv }, "Debug zero value";
is
	`perl -I$lib -d:DZVii -e0`
	, "\n". $files->{ dzv }
	, "Debug zero value. Default initialization";


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

$script =  'sub t1{} sub t2{} sub t3{ @_ ? goto &t1 : goto &t2; } t3(); t3(1);';
is
	n( `perl -I$lib -d:TraceRT=trace_returns -e '$script'` )
	,"\n". $files->{ TraceReturns_goto }
	,"Check right subnames while returning from goto subs";


# goto frames
$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
t2();
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_one }
	,"Check goto frames. One level";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto -e '$script'` )
	,"\n". $files->{ TraceGoto_one }
	,"Check goto frames. One level. +trace_goto";

is
	n( `perl -I$lib -d:TraceRT=trace_subs -e '$script'` )
	,"\n". $files->{ TraceGoto_one }
	,"trace_goto is enabled by default";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
sub t3{ t2() };
sub t4{ goto &t3; }
sub t5{ goto &t4; }
t5();
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_deep }
	,"Check goto frames. Deep level";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto -e '$script'` )
	,"\n". $files->{ TraceGoto_deep }
	,"Check goto frames. Deep level. +trace_goto";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
t2( 3 );
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_one_with_args }
	,"Check goto frames. One level with args";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto -e '$script'` )
	,"\n". $files->{ TraceGoto_one_with_args }
	,"Check goto frames. One level with args +trace_goto";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
sub t3{ t2( 5 ) };
sub t4{ goto &t3; }
sub t5{ goto &t4; }
t5( 7 );
PERL

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_deep_with_args }
	,"Check goto frames. Deep level with args";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto -e '$script'` )
	,"\n". $files->{ TraceGoto_deep_with_args }
	,"Check goto frames. Deep level with args +trace_goto";


# different frames test
is
	n( `perl -I$lib -d:TraceRT=dbg_frames,orig_frames -e '$script'` )
	,''
	,"'dbg_frames', 'orig_frames' has no effect without trace_subs";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,dbg_frames,orig_frames -e '$script'` )
	,"\n". $files->{ TraceSubs_with_dbg_orig_frames }
	,"Set 'dbg_frames' and 'orig_frames' flags";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,frames=1,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames1 }
	,"Limit callstack tracing to 1 frame";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_goto,frames=1 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames1_with_goto }
	,"Limit callstack tracing to 1 frame +trace_goto";


$script =  << 'PERL';
sub t1 {}
sub t2{ goto &t1; }
sub t3{ t2( 5 ) };
sub t4{ goto &t3; }
sub t5{ t4( @_ ); } # <-- goto replaced by common call
t5( 7 );
PERL


is
	n( `perl -I$lib -d:TraceRT=trace_subs,frames=1,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames1_2 }
	,"Limit callstack tracing to 1 frame. Test 2";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,frames=1 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames1_2_goto }
	,"Limit callstack tracing to 1 frame. Test 2. +trace_goto";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,frames=2,trace_goto=0 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames2 }
	,"Limit callstack tracing to 2 frames";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,frames=2 -e '$script'` )
	,"\n". $files->{ TraceSubs_limit_frames2_goto }
	,"Limit callstack tracing to 2 frames. +trace_goto";

is
	n( `perl -I$lib -d:TraceRT=trace_goto -e '$script'` )
	,''
	,"Tracing goto frames without trace_subs is useless";

is
	n( `perl -I$lib -d:TraceGotoCT=trace_subs -e0` )
	,"\n". $files->{ TraceGotoCT }
	,"Trace gotos at compile time";

is
	n( `perl -I$lib -d:TraceRT=trace_subs,trace_load -e0` )
	,$files->{ TraceRT_internals }
	,"Do not trace internal calls";

# TODO: implement testcase
# is
# 	n( `perl -I$lib -d:Interact='cmds=b 2/go' -e '$script' )
# EXPECTED: GOTO: main -- -4 -main::t3
# but the DB::goto frame is broken so information is wrong
# The broken info also located at
# @@ TraceGotoCT
# GOTO:  - - -Devel::TraceGotoCT::test
# ------^^^^ It is undefined because of WARKAROUND (see DB::trace_subs)


###
is
	n( `perl -I$lib -d:AutoInit -e0` )
	,'Devel::AutoInit'
	,"Check auto initialization of \$DB::dbg";


# print "ZZZZZZZZZZZZZZZ\n";
# print n `perl -I$lib -d:TraceRT=trace_subs -e '$script'`;

__DATA__
@@ VerboseBehaviour
Loaded '*main::_<strict.pm'
Loaded '*main::_<register.pm'
Loaded '*main::_<warnings.pm'
Loaded '*main::_<vars.pm'
Loaded '*main::_<Scope.pm'
Loaded '*main::_<Config.pm'
Loaded '*main::_<DynaLoader.pm'
Loaded '*main::_<Commands.pm'
Loaded '*main::_<DebugHooks.pm'
Loaded '*main::_<CmdProcessor.pm'

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: Devel::DebugHooks::import( Devel::DebugHooks )
TEXT: DebugHooks.pm:xx-xx

FROM: main --e -0 -Devel::DebugHooks::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =
Devel::DebugHooks::import RETURNS:
>>NOTHING<<
 = = = = = = = = = = = = = = =
Loaded '*main::_<-e'

 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:3    $x =  t2( 5, str );

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: scalar
CSUB: main::t2( 5, str )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:2    sub t2{ goto &t1 };

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: scalar
GSUB: main::t1( 5, str )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:1    sub t1{ return 7; };
main::t2->main::t1 RETURNS:
  7
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:4    $x++;
@@ dzv
 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =1
-e:1    0
@@ TraceLoadCT
Loaded '*main::_<strict.pm'
Loaded '*main::_<register.pm'
Loaded '*main::_<warnings.pm'
Loaded '*main::_<vars.pm'
Loaded '*main::_<Scope.pm'
Loaded '*main::_<Config.pm'
Loaded '*main::_<DynaLoader.pm'
Loaded '*main::_<Commands.pm'
Loaded '*main::_<DebugHooks.pm'
Loaded '*main::_<CmdProcessor.pm'
Loaded '*main::_<TraceLoadCT.pm'
Loaded '*main::_<-e'
@@ TraceLoadCT_Empty
Loaded '*main::_<strict.pm'
Loaded '*main::_<register.pm'
Loaded '*main::_<warnings.pm'
Loaded '*main::_<vars.pm'
Loaded '*main::_<Scope.pm'
Loaded '*main::_<Config.pm'
Loaded '*main::_<DynaLoader.pm'
Loaded '*main::_<Commands.pm'
Loaded '*main::_<DebugHooks.pm'
Loaded '*main::_<CmdProcessor.pm'
Loaded '*main::_<TraceLoadCT.pm'
Loaded '*main::_<Empty.pm'
Loaded '*main::_<-e'
@@ TraceLoadRT
Loaded '*main::_<-e'
@@ TraceLoadRT_Empty
Loaded '*main::_<Empty.pm'
Loaded '*main::_<-e'
@@ TraceRT_internals
Loaded '*main::_<-e'
@@ TraceSubsCT
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: Devel::TraceSubsCT::import( Devel::TraceSubsCT )
TEXT: TraceSubsCT.pm:5-7

FROM: main --e -0 -Devel::TraceSubsCT::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: Devel::DebugHooks::import( Devel::TraceSubsCT )
TEXT: /lib/Devel/DebugHooks.pm:19-30

FROM: Devel::TraceSubsCT -TraceSubsCT.pm -6 -Devel::DebugHooks::import
FROM: main --e -0 -Devel::TraceSubsCT::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubsRT
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_args
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::test( str, 7, ARRAY(0x000000), HASH(0x000000), &undef )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_void
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_scalar
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: scalar
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceSubs_call_list
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: list
CSUB: main::test(  )
TEXT: -e:1-1

FROM: main --e -1 -main::test
 = = = = = = = = = = = = = = =
@@ TraceReturns_void
 = = = = = = = = = = = = = = =
main::test RETURNS:
>>NOTHING<<
 = = = = = = = = = = = = = = =
@@ TraceReturns_scalar
 = = = = = = = = = = = = = = =
main::test RETURNS:
  &undef
 = = = = = = = = = = = = = = =
@@ TraceReturns_list
 = = = = = = = = = = = = = = =
main::test RETURNS:
  ARRAY(0x000000)
  HASH(0x000000)
  &undef
 = = = = = = = = = = = = = = =
@@ TraceReturns_goto
 = = = = = = = = = = = = = = =
main::t3->main::t2 RETURNS:
>>NOTHING<<
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
main::t3->main::t1 RETURNS:
>>NOTHING<<
 = = = = = = = = = = = = = = =
@@ TraceSubs_one
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t2(  )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceGoto_one
 = = = = = = = = = = = = = = =
DEEP: 1
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
@@ TraceSubs_deep
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5(  )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t2(  )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
FROM: main --e -6 -main::t3
 = = = = = = = = = = = = = = =
@@ TraceGoto_deep
 = = = = = = = = = = = = = = =
DEEP: 1
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
DEEP: 2
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
@@ TraceSubs_one_with_args
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t2( 3 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceGoto_one_with_args
 = = = = = = = = = = = = = = =
DEEP: 1
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
@@ TraceSubs_deep_with_args
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
FROM: main --e -6 -main::t3
 = = = = = = = = = = = = = = =
@@ TraceGoto_deep_with_args
 = = = = = = = = = = = = = = =
DEEP: 1
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
DEEP: 2
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
@@ TraceSubs_with_dbg_orig_frames
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

DBGF: Devel::DebugHooks -DebugHooks.pm -73 -DB::frames
DBGF: Devel::TraceRT -TraceRT.pm -19 -Devel::DebugHooks::trace_subs
DBGF: DB -DebugHooks.pm -385 -Devel::TraceRT::trace_subs
DBGF: DB -DebugHooks.pm -xxx -DB::mcall
DBGF: main --e -6 -DB::trace_subs
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t4( 7 )
TEXT: -e:4-4

DBGF: Devel::DebugHooks -DebugHooks.pm -73 -DB::frames
DBGF: Devel::TraceRT -TraceRT.pm -19 -Devel::DebugHooks::trace_subs
DBGF: DB -DebugHooks.pm -385 -Devel::TraceRT::trace_subs
DBGF: DB -DebugHooks.pm -xxx -DB::mcall
DBGF: DB -DebugHooks.pm -412 -DB::trace_subs
DBGF: DB -DebugHooks.pm -432 -DB::goto
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: main::t3( 7 )
TEXT: -e:3-3

DBGF: Devel::DebugHooks -DebugHooks.pm -73 -DB::frames
DBGF: Devel::TraceRT -TraceRT.pm -19 -Devel::DebugHooks::trace_subs
DBGF: DB -DebugHooks.pm -385 -Devel::TraceRT::trace_subs
DBGF: DB -DebugHooks.pm -xxx -DB::mcall
DBGF: DB -DebugHooks.pm -412 -DB::trace_subs
DBGF: DB -DebugHooks.pm -432 -DB::goto
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

DBGF: Devel::DebugHooks -DebugHooks.pm -73 -DB::frames
DBGF: Devel::TraceRT -TraceRT.pm -19 -Devel::DebugHooks::trace_subs
DBGF: DB -DebugHooks.pm -385 -Devel::TraceRT::trace_subs
DBGF: DB -DebugHooks.pm -xxx -DB::mcall
DBGF: main --e -3 -DB::trace_subs
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

DBGF: Devel::DebugHooks -DebugHooks.pm -73 -DB::frames
DBGF: Devel::TraceRT -TraceRT.pm -19 -Devel::DebugHooks::trace_subs
DBGF: DB -DebugHooks.pm -385 -Devel::TraceRT::trace_subs
DBGF: DB -DebugHooks.pm -xxx -DB::mcall
DBGF: DB -DebugHooks.pm -412 -DB::trace_subs
DBGF: DB -DebugHooks.pm -432 -DB::goto
GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
GOTO: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames1
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames1_with_goto
 = = = = = = = = = = = = = = =
DEEP: 1
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
DEEP: 2
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
GSUB: main::t1( 5 )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames1_2
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t4( 7 )
TEXT: -e:4-4

FROM: main --e -5 -main::t4
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames1_2_goto
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t4( 7 )
TEXT: -e:4-4

FROM: main --e -5 -main::t4
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
GSUB: main::t3( 7 )
TEXT: -e:3-3

GOTO: main --e -4 -main::t3
FROM: main --e -5 -main::t4
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
GSUB: main::t1( 5 )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames2
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t4( 7 )
TEXT: -e:4-4

FROM: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
FROM: main --e -5 -main::t3
 = = = = = = = = = = = = = = =
@@ TraceSubs_limit_frames2_goto
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: main::t5( 7 )
TEXT: -e:5-5

FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: main::t4( 7 )
TEXT: -e:4-4

FROM: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
GSUB: main::t3( 7 )
TEXT: -e:3-3

GOTO: main --e -4 -main::t3
FROM: main --e -5 -main::t4
FROM: main --e -6 -main::t5
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
CSUB: main::t2( 5 )
TEXT: -e:2-2

FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
FROM: main --e -5 -main::t4
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 3
CNTX: void
GSUB: main::t1( 5 )
TEXT: -e:1-1

GOTO: main --e -2 -main::t1
FROM: main --e -3 -main::t2
GOTO: main --e -4 -main::t3
FROM: main --e -5 -main::t4
 = = = = = = = = = = = = = = =
@@ TraceGotoCT
 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
CSUB: Devel::TraceGotoCT::import( Devel::TraceGotoCT, trace_subs )
TEXT: TraceGotoCT.pm:xx-xx

FROM: main --e -0 -Devel::TraceGotoCT::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 2
CNTX: void
CSUB: Devel::DebugHooks::import( Devel::TraceGotoCT, trace_subs )
TEXT: DebugHooks.pm:xx-xx

FROM: Devel::TraceGotoCT -TraceGotoCT.pm -6 -Devel::DebugHooks::import
FROM: main --e -0 -Devel::TraceGotoCT::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =

 = = = = = = = = = = = = = = =
DEEP: 1
CNTX: void
GSUB: Devel::TraceGotoCT::test( Devel::TraceGotoCT, trace_subs )
TEXT: TraceGotoCT.pm:xx-xx

GOTO: Devel::TraceGotoCT -TraceGotoCT.pm -xxx -Devel::TraceGotoCT::test
FROM: main --e -0 -Devel::TraceGotoCT::import
FROM: main --e -0 -main::BEGIN
FROM: main --e -0 -(eval)
 = = = = = = = = = = = = = = =
