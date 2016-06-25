#!/usr/bin/env perl


warn \$DB::a ."  " . \$main::a;
use List::Util qw/ pairmap /;
my @x =  ( a => { x => 7 }, b => { x => 3 }, c => { x => 0 } );

sub abc {};
my @res =  pairmap {
    warn "MAIN: " .__PACKAGE__ . "  -- D:" .\$DB::a ."  M:" . \$main::a ."  ?" .\$a ."\n";
    abc();
    1;
} @x;
