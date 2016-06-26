package DB;

sub DB {}

use Scope::Guard qw/ scope_guard guard /;

sub gua { }

sub sub {
    return &$DB::sub
        if $DB::sub eq 'Scope::Guard::new' || $DB::sub eq 'Scope::Guard::DESTROY' || $DB::sub eq 'DB::gua';
    warn "SUB :   " .__PACKAGE__ . "  -- D:" .\$DB::a ."  M:" . \$main::a ."  ?" .\$a ." -- $DB::sub\n";

    my $a =  scope_guard \&gua;

    return &$DB::sub;
}

1;
