use myperl DEBUG => 1;													# need debugging on to test this one

use Test::Most 0.25;


test_snippet(<<'END');
	class %
	{
		has foo => (ro, isa => 'Int', lazy, default => 1);
	}
END

test_snippet(<<'END');
	class %
	{
		method foo (...)					# guarantees that we're using MSM instead of MXMS
		{
		}
	}
END

test_snippet(<<'END');
	class %
	{
		has foo => (ro, isa => Int);
	}
END

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
	my ($snippet) = @_;
	state $count = 0;

	my $to_eval = $snippet;
	my $classname = 'TestClass' . $count++;
	$to_eval =~ s/%/$classname/g;

	eval $to_eval;
	is $@, '', "snippet succeeds as expected: $snippet";

}
