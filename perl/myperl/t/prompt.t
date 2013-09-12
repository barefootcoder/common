use myperl;
use autodie qw< :all >;

use Test::Most 0.25;

# set up fake input
local *ARGV;
open *ARGV, '<', \<<END_INPUT;
test
END_INPUT

# basic test: does it load, and does it get input?
is exists $INC{'IO/Prompter.pm'}, '', "haven't loaded IO::Prompter yet";
my $input = prompt();
is $input, "test", "can input data";
#is ref($input), '', "get real string back from prompt()";
is exists $INC{'IO/Prompter.pm'}, 1, "loaded IO::Prompter now";


done_testing;
