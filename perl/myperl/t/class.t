use myperl DEBUG => 1;													# need debugging on to test this one

use Test::Most 0.25;


# tests MooseX::Has::Sugar
test_snippet(<<'END');
	class %
	{
		has foo => (ro, isa => 'Int', lazy, default => 1);
	}
END

# guarantees we're using MSM instead of MXMS
test_snippet(<<'END');
	class %
	{
		method foo (...)
		{
		}
	}
END

# tests MooseX::Types::Moose
test_snippet(<<'END');
	class %
	{
		has foo => (ro, isa => Int);
	}
END

# tests MooseX::StrictConstructor
test_snippet(<<'END', 'unknown attribute');
	class %
	{
		has foo => (ro);
	}
	%->new( foo => 1, bar => 2 );
END

# tests MooseX::ClassAttribute
test_snippet(<<'END');
	class %
	{
		class_has foo => (ro, isa => Int);
	}
END


# make sure namespace::autoclean doesn't get rid of our DEBUG constant
# note that this only fails when DEBUG >= 1 (otherwise, debuggit is an empty function)
test_snippet(<<'END');
	class %
	{
		method foo { debuggit(3 => 'test'); }
	}

	%->new->foo;
END


done_testing;


sub test_snippet
{
	my ($snippet, $error) = @_;
	state $count = 0;

	my $to_eval = $snippet;
	my $classname = 'TestClass' . $count++;
	$to_eval =~ s/%/$classname/g;

	eval $to_eval;
	if ($error)
	{
		like $@, qr/$error/, "snippet fails as expected: $to_eval";
	}
	else
	{
		is $@, '', "snippet succeeds as expected: $snippet";
	}

}
