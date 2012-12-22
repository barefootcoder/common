use myperl;

# can't use Test::Most here, because it does `use strict' and `use warnings' for us
# but we want to verify that `use myperl' is doing it for us
use Test::More 0.88;

use File::Basename;
use lib dirname($0);
use Test::myperl;


foreach (keys %SNIPPETS)
{
	eval;
	test_snippet($_);
}


done_testing;
