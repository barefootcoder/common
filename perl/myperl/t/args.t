
use Test::Most		0.25;
use Test::Command	0.08;


perl_error_is( "unknown args caught", "myperl: unknown argument BMOOGLE", <<'END' );
	use myperl BMOOGLE => 1;
END


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


perl_no_output( "defaults for warnings are good", <<'END' );
	use myperl;
	say 2 + "fred";
END

perl_output_is( "can turn warnings non-fatal", "2", <<'END' );
	use myperl NoFatalWarns => 1;
	say 2 + "fred";
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
