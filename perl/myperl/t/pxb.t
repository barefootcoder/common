
use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;


perl_no_error( "pxb exports same as script", <<'END', '-a' );
	use myperl::Pxb;
	opts <<"-";
		[-a] [<file> ...]
		-a : opt 1
		do things
-
	debuggit("foo");
	say $OPT{a};
END


perl_error_is( "maintains pass-thru for myperl args", <<OUT, <<'END');
DEBUG is 2
OUT
	use myperl::Pxb DEBUG => 2;
	debuggit(2 => "DEBUG is", DEBUG);
END


perl_output_is( "bash functions are exported", <<OUT, <<'END');
one
two
OUT
	use myperl::Pxb;
	say foreach head 2 => bash \lines => qq(echo -e "one\ntwo\nthree");
END


perl_output_is( "sh in void context just gets run", <<OUT, <<'END');
one
two
three
OUT
	use myperl::Pxb;
	sh(echo => -e => q|"one\ntwo\nthree"|);
END


use myperl::Pxb;

my $list = [ sh(echo => -e => q|"one\ntwo\nthree"|) ];
eq_or_diff $list, [qw< one two three >], "sh in list context returns as lines";

my $string = sh(echo => -e => q|"one\ntwo\nthree"|);
is $string, "one\ntwo\nthree\n", "sh in scalar context returns as a string";


done_testing;
