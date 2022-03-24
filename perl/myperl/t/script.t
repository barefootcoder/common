use myperl::Script;

use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;


lives_ok { is $ME, 'script.t', 'value of $ME set properly' } '$ME is exported';

local @ARGV;					# don't try to process args to this unit test
opts '';
lives_ok { %OPT } '%OPT is exported';

perl_no_error( "script exports basic syntax", <<'END' );
	use myperl::Script;
	say "foo";
	debuggit("foo");
END

perl_error_is( "getting proper dumping", qr/\Ah: \e.*1\e.*\n\Z/, <<'END' );
	use myperl::Script DEBUG => 1;
	debuggit("h:", DUMP => \1);
END

perl_error_is( "script doesn't export advanced syntax",
		q{Can't locate object method "class" via package "Foo" (perhaps you forgot to load "Foo"?)},
		<<'END' );
	use myperl::Script;
	class Foo { }
END


perl_output_is( "collects options properly", <<OUT, <<'END', qw< -a -c foo > );
{ a => 1, c => "foo" }
OUT
	use myperl::Script;
	opts <<"-";
		[-ab] [-c <thingy>] file [...]
		-a : turn a on
		-b : turn b on
		-c : specify a <thingy>
		at least one file
-
	use Data::Printer output => 'stdout', sort_keys => 1, hash_separator => ' => ', multiline => 0;
	p %OPT;
END

perl_output_is( "proper help message", <<OUT, <<'END', qw< -h > );
usage: <one-liner> -h | [-ab] [-c <thingy>] file [...]
           -a : turn a on
           -b : turn b on
           -c : specify a <thingy>
           -h : this help message
       at least one file
       files are bmoogled
       -b is a cool option
OUT
	use myperl::Script;
	opts <<"-";
		[-ab] [-c <thingy>] file [...]
		-a : turn a on
		-b : turn b on
		-c : specify a <thingy>
		at least one file
		files are bmoogled
		-b is a cool option
-
	say "bmoogle!";
END

perl_output_is( "proper help message even w/o post-option block", <<OUT, <<'END', qw< -h > );
usage: <one-liner> -h | [-a]
           -a : turn a on
           -h : this help message
OUT
	use myperl::Script;
	opts <<"-";
		[-a]
		-a : turn a on
-
END

perl_output_is( "proper help message even w/o options", <<OUT, <<'END', qw< -h > );
usage: <one-liner> -h | <thingy>
           -h : this help message
       <thingy> : a thing
OUT
	use myperl::Script;
	opts <<"-";
		<thingy>
		<thingy> : a thing
-
END

perl_output_is( "proper help message w/ long set of alternatives", <<OUT, <<'END', qw< -h > );
usage: <one-liner> <thingy>
       <one-liner> -C <thingy>
       <one-liner> -M <thingy> [...]
       <one-liner> <some-other-crazy-option>
       <one-liner> <an-even-longer-option>
       <one-liner> -h
           -C : create a <thingy>
           -M : whole lotta <thingy>s
           -h : this help message
       <thingy> : a thing
OUT
	use myperl::Script;
	opts <<"-";
		{ <thingy> | -C <thingy> | -M <thingy> [...] | <some-other-crazy-option> | <an-even-longer-option> }
		-C : create a <thingy>
		-M : whole lotta <thingy>s
		<thingy> : a thing
-
END

perl_error_is( "proper exit message w/ bad option", <<OUT, <<'END', qw< -b > );
<one-liner>: Unknown option: b (<one-liner> -h for help)
OUT
	use myperl::Script;
	opts <<"-";
		[-a]
		-a : turn a on
-
	say STDERR "bmoogle!";
END

perl_error_is( "proper exit message w/ multiple bad options", <<OUT, <<'END', qw< -bc > );
<one-liner>: Unknown option: b, Unknown option: c (<one-liner> -h for help)
OUT
	use myperl::Script;
	opts <<"-";
		[-a]
		-a : turn a on
-
	say STDERR "bmoogle!";
END

perl_error_is( "provides proper usage_error function", <<OUT, <<'END');
<one-liner>: aww crap ... (<one-liner> -h for help)
OUT
	use myperl::Script;
	opts <<"-";
		[-a] file [...]
		-a : turn a on
-
	usage_error("aww crap ...");
	say STDERR "bmoogle!";
END

perl_exit_is( "provides proper exit on usage_error", 2, <<'END');
	use myperl::Script;
	usage_error("should have exited with 2");
END


perl_error_is( "provides proper fatal error function", <<OUT, <<'END');
<one-liner>: bmoogle!
OUT
	use myperl::Script;
	fatal("bmoogle!");
	say STDERR "boo!";
END

perl_exit_is( "provides proper exit on fatal", 1, <<'END');
	use myperl::Script;
	fatal("should have exited with 1");
END

perl_exit_is( "can tweak exit on fatal", 5, <<'END');
	use myperl::Script;
	fatal(5 => "should have exited with 5");
END


perl_error_is( "maintains pass-thru for myperl args", <<OUT, <<'END');
DEBUG is 2
OUT
	use myperl::Script DEBUG => 2;
	debuggit(2 => "DEBUG is", DEBUG);
END


perl_error_is( "script module won't be loaded from package other than main",
		q{Must load myperl::Script from package main},
		<<'END' );
	package Foo;
	use myperl::Script;
END


perl_combined_is( "autoflushes STDOUT", "ab\n", <<'END');
	use myperl::Script;
	print "a";
	die("b\n");
END

use charnames ':full';

perl_no_error( "STDIN is UTF safe", <<'END' );
# NOTE: this also tests UTF8 for opened file handles
	use myperl::Script;
	use charnames ':full';
	if (open(CHILD, "|-"))
	{
		say CHILD "\N{GREEK SMALL LETTER SIGMA}";
	}
	else
	{
		<STDIN>;
	}
END

perl_no_error( "STDOUT is UTF safe", <<'END' );
	use myperl::Script;
	use charnames ':full';
	say "\N{GREEK SMALL LETTER SIGMA}";
END

perl_error_is( "STDERR is UTF safe", qr/^(?!Wide character)/, <<'END' );
	use myperl::Script;
	use charnames ':full';
	say STDERR "\N{GREEK SMALL LETTER SIGMA}";
END


done_testing;
