use Data::Printer	0.36;

use Test::Most		0.25;
use Test::Command	0.08;


# Bad Args

perl_error_is( "unknown args caught", "myperl: unknown argument BMOOGLE", <<'END' );
	use myperl BMOOGLE => 1;
END


# DEBUG

perl_no_error( "defaults for Debuggit are good", <<'END' );
	use myperl;
	my $var = 4;
	debuggit(2 => "var is", $var);
END

perl_error_is( "Debuggit args are passed through", "var is 4", <<'END' );
	use myperl DEBUG => 2;
	my $var = 4;
	debuggit(2 => "var is", $var);
	debuggit(3 => "but not", $var);
END

my $struct = '{ deeply => "nested", config => { stuff => "that", goes => "on", and => "on" } }';
my $dp_out = &Data::Printer::np(eval $struct, colored => 1, hash_separator => ' => ');
perl_error_is( "Debuggit default uses Data::Printer", $dp_out, <<END );
	use myperl DEBUG => 2;
	sub st { return $struct }
	debuggit(2 => DUMP => st());
END


# NoFatalWarns

perl_no_output( "defaults for warnings are good", <<'END' );
	use myperl;
	say 2 + "fred";
END

perl_output_is( "can turn warnings non-fatal", "2", <<'END' );
	use myperl NoFatalWarns => 1;
	say 2 + "fred";
END


# NO_SYNTAX

perl_no_error( "still exporting basic syntax", <<'END' );
	use myperl NO_SYNTAX => 1;
	say "foo";
	const my $foo => 1;
	debuggit("foo");
END

perl_error_is( "not exporting advanced syntax",
		q{Can't locate object method "class" via package "Foo" (perhaps you forgot to load "Foo"?)},
		<<'END' );
	use myperl NO_SYNTAX => 1;
	class Foo { }
END


# ONLY

perl_no_error( "requested funcs exported", <<'END' );
	use myperl ONLY => [qw< title_case str2time >];
	title_case("FOO");
	str2time("12/31/2010");
END

perl_error_is( "not exporting internals not requested", "Undefined subroutine &main::round called", <<'END' );
	use myperl ONLY => [qw< title_case str2time >];
	round(UP => 123.456);
END

perl_error_is( "not exporting autoloads not requested", "Undefined subroutine &main::time2str called", <<'END' );
	use myperl ONLY => [qw< title_case str2time >];
	time2str(0);
END

perl_no_error( "still exporting basic syntax", <<'END' );
	use myperl ONLY => [qw< title_case str2time >];
	debuggit("foo");
END

perl_error_is( "not exporting advanced syntax",
		q{Can't locate object method "class" via package "Foo" (perhaps you forgot to load "Foo"?)},
		<<'END' );
	use myperl ONLY => [qw< title_case str2time >];
	class Foo { }
END

perl_no_error( "can override NO_SYNTAX with ONLY", <<'END' );
	use myperl ONLY => [qw< title_case str2time >], NO_SYNTAX => 0;
	class Foo { }
END

perl_no_error( "can override NO_SYNTAX with ONLY regardless of order", <<'END' );
	use myperl NO_SYNTAX => 0, ONLY => [qw< title_case str2time >];
	class Foo { }
END


done_testing;


sub perl_output_is
{
	my ($tname, $expected, $cmd) = @_;

	stdout_is_eq([ $^X, '-e', $cmd ], "$expected\n", $tname);
}

sub perl_no_output
{
	my ($tname, $cmd) = @_;

	stdout_is_eq([ $^X, '-e', $cmd ], '', $tname);
}

sub perl_error_is
{
	my ($tname, $expected, $cmd) = @_;

	my $regex = qr/^\Q$expected\E( at \S+ line \d+\.)?\n/;
	stderr_like([ $^X, '-e', $cmd ], $regex, $tname);
}

sub perl_no_error
{
	my ($tname, $cmd) = @_;

	stderr_is_eq([ $^X, '-e', $cmd ], '', $tname);
}
