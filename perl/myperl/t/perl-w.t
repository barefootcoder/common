use Test::Most 0.25;


$^W = 1;
warning_is { use_ok 'myperl' } undef, "can use myperl under -w with no warnings";


done_testing;
