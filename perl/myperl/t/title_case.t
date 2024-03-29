use myperl;

use Test::Most 0.25;


can_ok(main => 'title_case');

# basic stuff
is title_case("this is a test"), 'This Is a Test', "simple title case works";
is title_case("this is a POP test"), 'This Is a POP Test', "title case preserves all caps";
is title_case("This Is A Test"), 'This Is a Test', "capitalized word 'a' goes to lower";

# apostrophe s
my $contractions = "that's not what I can't does but I don't";
my $answer = "That's Not What I Can't Does but I Don't";
is title_case($contractions), $answer, 'apostrophe s starting from lc';
$contractions =~ s/\b(.)/uc $1/eg;
is title_case($contractions), $answer, 'apostrophe s starting from ucfirst';
$contractions =~ s/(.)\b/uc $1/eg;
is title_case($contractions), $answer, 'apostrophe s starting from ucfirst & uclast';

# a French title
is title_case("l'anniversaire d'irvin"), "L'Anniversaire d'Irvin", "French titles appear to work from lowercase";
is title_case("L'anniversaire d'Irvin"), "L'Anniversaire d'Irvin", "French titles appear to work from mixed case";
is title_case("Mrs. Bagwell's Rhumba"), "Mrs. Bagwell's Rhumba", "handles l' for non-French titles";
is title_case("Mr. Fred's Bmoogle"), "Mr. Fred's Bmoogle", "handles d' for non-French titles";

# make sure our additional words are added
foreach (qw< for by from into as >)
{
	is title_case("test $_ a mouse"), "Test $_ a Mouse", "title case for $_ works";
}

# make sure some words are _not_ included (that is, they _are_ capitalized)
foreach (qw< has so >)
{
	is title_case("test $_ a mouse"), "Test " . ucfirst $_ . " a Mouse", "title case for $_ works";
}

# back to default wordlist now?
require Text::Capitalize;
is Text::Capitalize::capitalize_title("test from a mouse"), 'Test From a Mouse', "title case is properly localizing";


done_testing;
