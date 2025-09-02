use myperl;

use Test::Most;


# Test basic ASCII padding
# unipad now uses intuitive alignment: left = text on left, right = text on right
{
    is unipad("test", 10),           "test      ", 'unipad default left-aligns ASCII text';
    is unipad("test", left => 10),   "test      ", 'unipad can explicit left-align ASCII text';
    is unipad("test", right => 10),  "      test", 'unipad can right-align ASCII text';
    is unipad("test", center => 10), "   test   ", 'unipad can center-align ASCII text';
}

# Test with strings longer than target length (should return unchanged)
{
    is unipad("verylongstring", 5), "verylongstring", 'unipad with string longer than target returns unchanged';
}

# Test with exact length match
{
    is unipad("exact", 5), "exact", 'unipad with string exact length returns unchanged';
}

# Test empty string
{
    is unipad("", 5),          "     ", 'unipad with empty string pads to full width';
    is unipad("", right => 5), "     ", 'unipad with empty string right-align pads to full width';
}

# Test Unicode character handling (the key functionality)
{
    # Test with combining diacritics
    my $cafe = "café";								# é is a single character
    is unipad($cafe, 10),          "café      ", 'unipad can default left-align with accented character';
    is unipad($cafe, right => 10), "      café", 'unipad can right-align with accented character';

    # Test with ligature
    my $aether = "Ætherium";						# Æ is a single display character
    is unipad($aether, 12),          "Ætherium    ", 'unipad can default left-align with ligature';
    is unipad($aether, right => 12), "    Ætherium", 'unipad can right-align with ligature';

    # Test with wide characters (CJK)
    my $japanese = "日本語";  						# Each character is 2 columns wide
    is unipad($japanese, 10),          "日本語    ", 'default left-align Japanese text (wide chars)';
    is unipad($japanese, right => 10), "    日本語", 'right-align Japanese text (wide chars)';

    # Test mixing ASCII and Unicode
    my $mixed = "Test™";							# ™ is a single-width character
    is unipad($mixed, 10), "Test™     ", 'default left-align mixed ASCII/Unicode';
}

# Test some specific examples that have caused problems in the past
{
    # These should all align to the same column width
    my @titles =
	(
        "Eldritch Ætherium",
        "Candy Apple Shimmer",
        "Gramophonic Skullduggery",
    );

    my @padded = map { unipad($_, left => 40) } @titles;

    # Check they all have the same display width
    is length($padded[0]), length($padded[1]), 'Ætherium title has same byte length as regular after unipadding';
}

# Test center alignment with odd/even differences
{
    is unipad("hi", center => 5), " hi  ",  'unipad center with odd padding adds extra space to right';
    is unipad("hi", center => 6), "  hi  ", 'unipad center with even padding';
}

# Test that function handles undefined input gracefully
{
    is unipad(undef, 5), "     ", 'unipad treats undefined input as empty string';
}

# Test numeric input
{
    is unipad(42, 5), "42   ", 'numeric input converted to string and unipadded';
}


done_testing;
