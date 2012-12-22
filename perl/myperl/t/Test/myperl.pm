package Test::myperl;

use Test::More;

use parent 'Exporter';
our @EXPORT = qw< %SNIPPETS test_snippet >;


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


1;
