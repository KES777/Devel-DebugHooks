package DB;

sub DB {}

sub sub {
    warn "SUB :   " .__PACKAGE__ . "  -- D:" .\$DB::a ."  M:" . \$main::a ."  ?" .\$a ." -- $DB::sub\n";

    return &$DB::sub;
}

1;
