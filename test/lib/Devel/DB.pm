package DB;

sub DB {}

use Guard;

sub gua { }

sub sub {
    warn "SUB :   " .__PACKAGE__ . "  -- D:" .\$DB::a ."  M:" . \$main::a ."  ?" .\$a ." -- $DB::sub\n";

    scope_guard \&gua;

    return &$DB::sub;
}

1;
