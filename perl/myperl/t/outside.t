use myperl;

# can't use Test::Most here, because it does `use strict' and `use warnings' for us
# but we want to verify that `use myperl' is doing it for us
use Test::More 0.88;

use File::Basename;
use lib dirname($0);
use Test::myperl;


foreach (keys %ALL_SNIPPETS)
{
	eval;
	test_snippet($_);
}


# Subprocess test: given/when must not produce warnings
# (catches missing `experimental 'smartmatch'` on Perl 5.18+)
perl_no_error("no 'given is experimental' warning from myperl", <<'END');
	use myperl;
	given (1) { when (1) {} }
END


done_testing;
