use myperl::Classlet;
#use Moops;

use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;


my $count = 0;
foreach (keys %CLASSLET_SNIPPETS)
{
	eval "class TestClass" . $count++ . "\n{ $_ }";
	test_snippet($_);
}


done_testing;
