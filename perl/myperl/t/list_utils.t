use myperl;

use Test::Most 0.25;


my %snippets =
(
	first	=>	'first { /0$/ } @list',
	max		=>	'max @list',
	min		=>	'(min @list) . "0"',
	reduce	=>	'reduce { $b } @list',
	shuffle	=>	'max shuffle @list',
	sum		=>	'(sum @list) / 5.5',
	apply	=>	'sum apply { s/^.$/0/ } @list',
	zip		=>	'(sum zip @list, @list2) / 5.5',
	uniq	=>	'max uniq @list',
);

my $count = 0;
foreach (keys %snippets)
{
	test_snippet();
	test_snippet('TestClass' . $count++);
}


done_testing;


our $result;
sub calc_result { $result = $_[0] * @_ }			# IOW, the first element of @results, and verify that there _is_ only 1
sub test_snippet
{
	my $class = shift;

	my $decl = q{
		my @list = 1..10;
		my @list2 = ('0') x 10;
		my @result;
	};

	my $code = "$decl; \@result = $snippets{$_}; main::calc_result(\@result)";
	$code = "class $class { $code }" if $class;

	eval $code;
	is $@, '', "list util $_ runs without exception";
	is $result, 10, "list util $_ returns correct answer";
}
