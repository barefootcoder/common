use myperl::Classlet;
#use Moops;

use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;


# Verify syntactical elements first
my $count = 0;
foreach (keys %CLASSLET_SNIPPETS)
{
	eval "class TestClass" . $count++ . "\n{ $_ }";
	test_snippet($_);
}


# Test common cases for attributes:
class AttrTest
{
	has a => Int;									# ro, required
	has b => Int, with 3;							# ro, optional (literal default)
	has c => Int, via { 3 };						# ro, optional (coderef default)

	builds d => Int, via { 5 };						# ro, lazy (coderef default)
	builds e => Int, with 5;						# ro, lazy (literal default)
	builds f => Int, via { $_->c + 5 };				# ro, lazy (builder default)

	builds g => Array, per add_g => 'push';			# ro, Array trait, with delegation
	builds h => Hash,  per add_h => 'set';			# ro,  Hash trait, with delegation

	has i => Int, set   by 'si';					# writer
	has j => Int, check by 'pj', clear by 'cj';		# predicate, clearer (and tests multiples)
}
my $t;
throws_ok	{ $t = AttrTest->new           }	qr/missing required/i,	'required attrs okay';
lives_ok	{ $t = AttrTest->new( a => 1, i => 2, j => 3, ) }			'optional attrs okay';

is $t->a, 1, 'required attr value okay';
is $t->b, 3, 'literal def attr value okay';
is $t->c, 3, 'coderef def attr value okay';

is $t->d, 5, 'lazy literal attr value okay';
is $t->e, 5, 'lazy coderef def attr value okay';
is $t->f, 8, 'lazy builder def attr value okay';

eq_or_diff [ $t->g ], [], 'Array attr starts out empty';
lives_ok { $t->add_g( 1..3 ) } 'Array attr basic delegation works';
eq_or_diff [ $t->g ], [ 1, 2, 3, ], 'Array attr add/retrieve works';

eq_or_diff { $t->h }, {}, 'Hash attr starts out empty';
lives_ok { $t->add_h( a => 1, b => 2, c => 3, ) } 'Hash attr basic delegation works';
eq_or_diff { $t->h }, { a => 1, b => 2, c => 3, }, 'Hash attr add/retrieve works';

lives_ok { $t->si(7) } 'writer was created';
is $t->i, 7, 'writer functions normally';
lives_ok { $t->cj } 'clearer was created';
lives_ok { $t->pj } 'predicate was created';
is $t->pj, '', 'clearer and predicate function normally';


# make sure `with` is context sensitive
role RoleTest { method foo {} }
class WithTest1 { with 'RoleTest'; }
class WithTest2 with RoleTest {}
ok (WithTest1->new->can("foo"), "role composition still works (internal)");
ok (WithTest2->new->can("foo"), "role composition still works (external)");


# make sure `required` isn't over-eager
class VeryLazy { has foo => (Maybe[Int], lazy => 1); builds bar => (Maybe[Int]); }
lives_ok { VeryLazy->new } "lazy attributes not being marked `required`";


# don't recommend these, but they should still work
class MooseyAttrs
{
	use Test::Most;

	warning_is { has foo => (is => 'rw', isa => Int) } undef, 'can still use "is" and "isa"';
}
lives_ok { MooseyAttrs->new(foo=>0)->foo(5) } '"is => rw" still respected';


done_testing;
