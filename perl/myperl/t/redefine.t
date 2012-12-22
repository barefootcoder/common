use myperl;

use Test::Most		0.25;
use Test::Command	0.08;

use File::Basename;
$ENV{PERL5LIB} = join(':', dirname($0), $ENV{PERL5LIB});

use File::Temp qw< tempfile >;


my ($fh, $filename) = tempfile('myperl.test.XXXX', TMPDIR => 1, UNLINK => 1);
print $fh "use myperl;\nuse Test::redefine;\n" and close($fh);
stderr_is_eq([ $^X, $filename ], '', 'no redefinition warnings from including myperl from a myperl script');


done_testing;
