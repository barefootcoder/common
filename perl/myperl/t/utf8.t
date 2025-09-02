use myperl NoFatalWarns => 1;

use Test::Most;
use File::Temp qw< tempfile >;


# Test UTF-8 file I/O
my ($fh, $filename) = tempfile();

# Write UTF-8 content to file with UTF-8 encoding
binmode $fh, ':utf8';
my $test_string = "UTF-8 test: café, こんにちは, π ≈ 3.14159";
print $fh $test_string;
close $fh;

# Verify file exists
ok -e $filename, "sanity test: temp file exists after writing";

# Read it back and verify
my $content = slurp($filename);
is $content, $test_string, 'UTF-8 content preserved with explicit encoding';

# Test UTF-8 variable names and string operations
{
    my $café = "coffee shop";
    is $café, "coffee shop", 'UTF-8 variable names work';

    my $π = 3.14159;
    is $π, 3.14159, 'Greek letter variable names work';

    my $こんにちは = "hello";
    is $こんにちは, "hello", 'Japanese variable names work';

    # Test UTF-8 string operations
    my $greeting = "Hello, café! π ≈ 3.14159, こんにちは";
    like $greeting, qr/café/, 'UTF-8 strings match in regex';
    like $greeting, qr/π/, 'Greek letters match in regex';
    like $greeting, qr/こんにちは/, 'Japanese text matches in regex';
}


# TODO: Moops parser doesn't support UTF-8 class/method names yet
# This is a known limitation of the Moops parser, not myperl::Classlet


done_testing;
