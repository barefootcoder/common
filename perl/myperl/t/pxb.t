
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


perl_output_is( "timerfile set properly", <<OUT, <<'END');
timer-new
OUT
	use myperl::Pxb;
	say $timerfile->basename;
END

perl_output_is( "timerfile set properly in DEBUG mode", <<OUT, <<'END');
timer-test
OUT
	use myperl::Pxb DEBUG => 1;
	say $timerfile->basename;
END


use myperl::Pxb;

my $list = [ sh(echo => -e => q|"one\ntwo\nthree"|) ];
eq_or_diff $list, [qw< one two three >], "sh in list context returns as lines";

my $string = sh(echo => -e => q|"one\ntwo\nthree"|);
is $string, "one\ntwo\nthree", "sh in scalar context returns as a string";


# verify debugging works
my @lines = ('+ echo bmoogle', '+ pwd', '+ test a == b');
perl_error_is( "-D sets bash -x", join('', map { "$_\n" } @lines), <<'END', '-D' );
	use myperl::Pxb;
	opts <<"-";
		[-D]
		-D : debug
-
	sh(echo => 'bmoogle');
	sh(pwd => );
	sh(test => qw< a == b >);
END


# verify types
perl_no_error( "pxb exports Path type stuff", <<'END', '-a' );
	package Foo;
	use myperl::Pxb;
	my $foo = path("/some/path");
	die("fail sanity check") unless $foo->isa('Path::Class::Tiny');
	die("fail") unless Path->check($foo);
END


done_testing;
