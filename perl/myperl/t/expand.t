use myperl;

use Test::Most 0.25;


my @test_strings =
(
	"abc",
	"\tabc",
	"\tabc\t\tabc",
	"\ta\tb\tc",
);

is expand($_) . "\n", `echo "$_" | expand -t4`, "expand handles 4-space tabs" foreach @test_strings;

# make sure $tabstop isn't exported
# (who thought that was a good idea anyway?)
eval q{ $tabstop = 4 };
like $@, qr/requires explicit package name/, 'does not export $tabstop';


done_testing;
