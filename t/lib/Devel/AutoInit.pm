package Devel::AutoInit;

use Devel::DebugHooks();

push @ISA, 'Devel::DebugHooks';

print $DB::dbg;

1;
