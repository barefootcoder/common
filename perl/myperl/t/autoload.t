use myperl;

use Test::Most 0.25;


# dates in
is exists $INC{'myperl/Menu.pm'}, '', "haven't loaded myperl::Menu yet";
lives_ok { menu(undef) } "can call menu()";
is exists $INC{'myperl/Menu.pm'}, 1, "loaded myperl::Menu now";


done_testing;
