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

perl_error_is( "provides proper usage_error function", <<OUT, <<'END');
<one-liner>: aww crap ... (<one-liner> -h for help)
OUT
	use myperl::Script;
	opts <<"-";
		[-a] file [...]
		-a : turn a on
-
	usage_error("aww crap ...");
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


done_testing;