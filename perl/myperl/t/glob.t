use myperl NO_SYNTAX => 1;

use Test::Most 0.25;

use File::Basename;
use lib dirname($0);
use Test::myperl;

use Path::Tiny qw< tempdir >;
use Module::Runtime qw< module_notional_filename >;

sub requires_ok(&$$);


# glob() is such a strange animal that we test all its bits separately here.


# STUFF LIKE autoload.t

# Despite the fact this is a CORE function, it basically works the same way as other autoloads.
# However, File::Glob is being loaded by something in Test::More, so we have to do an import check
# rather than a load check (which is what we do for all other autoloads).

requires_ok { glob("~") } glob => 'File::Glob';


# STUFF LIKE dates.t, expand.t, etc

# Also make sure that the CORE `glob` is now acting differently.

my $tdir = tempdir;
$tdir->child("File Test1")->touch;
$tdir->child("File Test2")->touch;
my @test_files = map { "$tdir/File Test$_" } 1..2;

# make sure both class and values are correct
my @ret = glob("$tdir/File Test*");
isa_ok $_, 'Path::Class::Tiny', "returned from glob: $_" foreach @ret;
eq_or_diff [ map { "$_" } @ret ], [ @test_files ], "glob() now handles spaces";
# and check scalar context returns something sane and useful
my $ret = glob("$tdir/File Test*");
is $ret, 2, 'glob in scalar context returns count';

# But not *too* differently ... make sure globbing with ~/ works.
# (If it doesn't, we'll get zero files back under ~/, which is otherwise impossible.)

my @home_files = glob("~/*");
isnt scalar @home_files, 0, "can glob tilde (homedir)";


# STUFF LIKE args.t

# Contrariwise, make sure CORE `glob` is *not* overridden when we have it do only certain functions
# and `glob` is not among those requested.

# Remember: the tempdir and files we put in it above are still there.
perl_output_is( "Got CORE::glob with ONLY< title_case expand >", join("\n", @test_files), <<END );
	use myperl ONLY => [qw< title_case str2time >];
	say foreach glob("$tdir/*1 $tdir/*2");
END

# Of course, if `glob` *is* one of the `ONLY` functions requested, then we should get the override.
perl_output_is( "Got overridden glob with ONLY< title_case glob >", join("\n", @test_files), <<END );
	use myperl ONLY => [qw< title_case glob >];
	say foreach glob("$tdir/File T*");
END


done_testing;


sub requires_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $called_yet = 0;
	no warnings 'once';
	local *CORE::GLOBAL::require = sub { $called_yet = 1; CORE::require(@_) };

	lives_ok { $sub->() } "can call $function()";
	is $called_yet, 1, "(re)required $module just now";
}
