use myperl;

# can't use Test::Most here, because it does `use strict' and `use warnings' for us
# but we want to verify that `use myperl' is doing it for us
use Test::More 0.88;

use File::Basename;
use lib dirname($0);
use Test::myperl;


my $count = 0;
foreach (keys %ALL_SNIPPETS)
{
	eval "class TestClass" . $count++ . "\n{ $_ }";
	test_snippet($_);
}


done_testing;
