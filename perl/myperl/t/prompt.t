use myperl;
use autodie qw< :all >;

use Test::Most 0.25;
use Test::Trap 0.2.2;

# set up fake input
local *ARGV;
open *ARGV, '<', \<<END_INPUT;
test
test


y
n
END_INPUT

# basic test: does it load, and does it get input?
is exists $INC{'IO/Prompter.pm'}, '', "haven't loaded IO::Prompter yet";
my $input = prompt();
is $input, "test", "can input data";
is ref($input), '', "get real string back from prompt()";
is exists $INC{'IO/Prompter.pm'}, 1, "loaded IO::Prompter now";

# IO::Prompter normall won't print prompts when the output isn't a term
# but we can totally override that
{
	no warnings 'redefine';
	*IO::Prompter::_null_printer = sub { return sub { shift; print @_ } }
}

# check the prompt output
my $prompt = 'enter stuff: ';
trap { $input = prompt $prompt };
is $input, "test", "input with prompt";
is $trap->stdout, $prompt, "simple prompt is okay" or $trap->diag_all;

# default prompt and output (original syntax)
trap { $input = prompt $prompt, -default => "fred" };
is $input, "fred", "input with default (orig)";
is $trap->stdout, $prompt, "default prompt (orig) is okay" or $trap->diag_all;

# default prompt and output (enhanced syntax)
trap { $input = prompt $prompt, default => "fred" };
is $input, "fred", "input with default (enh)";
is $trap->stdout, "$prompt [fred] ", "default (enh) prompt is okay" or $trap->diag_all;

# make sure -y still works
$prompt = 'yes or no?';
trap { $input = prompt $prompt, -yes };
ok $input, "yesno with yes" or diag("prompt -y spat back: $input");
is $trap->stdout, "$prompt ", "yesno prompt (yes) is okay" or $trap->diag_all;

trap { $input = prompt $prompt, -yes };
ok !$input, "yesno with no" or diag("prompt -y spat back: $input");
is $trap->stdout, "$prompt ", "yesno prompt (no) is okay" or $trap->diag_all;


done_testing;
