use myperl;

use Test::Most 0.25;


can_ok(main => 'title_case');

# basic stuff
is title_case("this is a test"), 'This Is a Test', "simple title case works";
is title_case("this is a POP test"), 'This Is a POP Test', "title case preserves all caps";
is title_case("This Is A Test"), 'This Is a Test', "capitalized word 'a' goes to lower";

# a French title
is title_case("l'anniversaire d'irvin"), "L'Anniversaire d'Irvin", "French titles appear to work from lowercase";
is title_case("L'anniversaire d'Irvin"), "L'Anniversaire d'Irvin", "French titles appear to work from mixed case";
is title_case("Mrs. Bagwell's Rhumba"), "Mrs. Bagwell's Rhumba", "handles l' for non-French titles";

# make sure our additional words are added
foreach (qw< for by from into as >)
{
	is title_case("test $_ a mouse"), "Test $_ a Mouse", "title case for $_ works";
}

# back to default wordlist now?
require Text::Capitalize;
is Text::Capitalize::capitalize_title("test from a mouse"), 'Test From a Mouse', "title case is properly localizing";


done_testing;
