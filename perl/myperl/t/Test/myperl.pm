package Test::myperl;

use Test::More;
use Test::Command	0.08;

use Perl6::Slurp;

use parent 'Exporter';
our @EXPORT =	(
					qw< %SNIPPETS test_snippet >,
					qw< perl_output_is perl_no_output perl_error_is perl_no_error >,
				);


our %SNIPPETS =
(
	q{ $x = 6 						}	=>	qr/requires explicit package/,			# strict
	q{ 6 + 'fred' 					}	=>	qr/isn't numeric/,						# warnings FATAL => 'all'
	q{ say 'fred' 					}	=>	undef,									# feature 'say'
	q{ given (1) { when (1) {} }	}	=>	undef,									# feature 'switch'
	q{ const my $x => 'fred' 		}	=>	undef,									# Const::Fast
	q{ dir('packages', 'rent') 		}	=>	undef,									# Path::Class
	q{ class Foo {} 				}	=>	undef,									# MooseX::Declare
	q{ try {die} catch {};			}	=>	undef,									# TryCatch
	q{ my $p = slurp '/etc/passwd'	}	=>	undef,									# Perl6::Slurp
	q{ debuggit(2 => 'test')		}	=>	undef,									# Debuggit
	q{ my $s = form("{<<}", "xx")	}	=>	undef,									# Perl6::Form
	q{ my @t = gather { take 5 }	}	=>	undef,									# Perl6::Gather
	#q{ open(IN, "bmoogle")			}	=>	qr/No such file or directory/,			# autodie
	#q{ system("bmoogle")			}	=>	qr/No such file or directory/,			# autodie 'system'
	q{ sub foo {} CLASS->foo;		}	=>	undef,									# CLASS
);


sub test_snippet
{
	my ($snippet) = @_;
	my $result = $SNIPPETS{$snippet};

	if ($result)
	{
		like $@, qr/$result/, "snippet fails as expected: $_";
	}
	else
	{
		is $@, '', "snippet succeeds as expected: $_";
	}
}


# Run Perl and check the output or error.

sub _perl_command
{
	my $cmd = shift;
	return [ $^X, '-e', $cmd, '--', @_ ];
}

sub perl_output_is
{
	my ($tname, $expected, $cmd, @extra) = @_;

	$expected .= "\n" unless $expected =~ /\n\Z/;
	my $test_cmd = Test::Command->new( cmd => _perl_command($cmd, @extra) );
	$test_cmd->stdout_is_eq($expected, $tname) or diag "error was:\n", slurp $test_cmd->{'result'}->{'stderr_file'};
}

sub perl_no_output
{
	my ($tname, $cmd, @extra) = @_;

	my $test_cmd = Test::Command->new( cmd => _perl_command($cmd, @extra) );
	$test_cmd->stdout_is_eq('', $tname) or diag "error was:\n", slurp $test_cmd->{'result'}->{'stderr_file'};
}

sub perl_error_is
{
	my ($tname, $expected, $cmd, @extra) = @_;

	if ( $expected =~ /\n\Z/ )
	{
		stderr_is_eq(_perl_command($cmd, @extra), $expected, $tname);
	}
	else
	{
		my $regex = qr/^\Q$expected\E( at \S+ line \d+\.)?\n/;
		stderr_like(_perl_command($cmd, @extra), $regex, $tname);
	}
}

sub perl_no_error
{
	my ($tname, $cmd, @extra) = @_;

	stderr_is_eq(_perl_command($cmd, @extra), '', $tname);
}


1;
