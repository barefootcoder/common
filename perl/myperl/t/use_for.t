use Test::Most 0.25;

use myperl ();

use File::Temp qw< tempfile >;


# lexical
my ($fh, $name) = tempfile( 'testXXXXX', DIR => '.', SUFFIX => '.pm', UNLINK => 1 );
$name =~ m{/(\w+)\.pm};
my $importer = $1;
print $fh qq{
	package $importer;
	sub import
	{
		#warn("importing into " . scalar caller);
		myperl->use_and_import_into(scalar caller, 'warnings', [ FATAL => 'all' ]);
	}

	1;
};
close($fh);

my $code = qq{
	package Testy1;
	use $importer;
	sub foo { 6 + "foo"; }
	foo();
	1;
};

warning_is { eval $code } undef, 'warning free';
like $@, qr/isn't numeric/, 'warnings imported into test package';


# straight transfer
{
	package Testy2;
};

myperl->use_and_import_into( Testy2 => 'Const::Fast' );
can_ok Testy2 => 'const';


# transfer with params
{
	package Testy3;
};

myperl->use_and_import_into( Testy3 => 'List::Util', [ 'sum' ] );
can_ok Testy3 => 'sum';


done_testing;
