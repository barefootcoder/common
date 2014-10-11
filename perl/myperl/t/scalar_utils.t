use myperl;

use Test::Most 0.25;


my %snippets =
(
	blessed	=>	'not defined blessed($scalar)',
);

my $count = 0;
foreach (keys %snippets)
{
	test_snippet();
	test_snippet('TestClass' . $count++);
}


done_testing;


sub test_snippet
{
	my $class = shift;

	my $decl = q{
		my $undef = undef;
		my $scalar = '/foo';
		my $ref = bless {}, 'Foo';
	};

	my $result;
	my $code = "$decl; \$result = $snippets{$_}";
	$code = "class $class { $code }" if $class;

	eval $code;
	is $@, '', "scalar util $_ runs without exception";
	is $result, 1, "scalar util $_ returns correct answer";
}
