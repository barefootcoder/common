use 5.012;
use warnings;

package myperl2;

use CLASS;

$INC{'perl5/barefoot.pm'} = $INC{"$CLASS.pm"};


sub import
{
	my $class = shift;

	@_ = qw< perl5 -barefoot >;
	goto &perl5::import;
}


package perl5::barefoot;
use parent 'perl5';

use CLASS;


sub imports
{
warn("# in ${CLASS}::imports");
	return
	(
		strict				=>
		warnings			=>	[	FATAL => 'all'	],
		feature				=>	[	':5.12'			],

		'Const::Fast'					=>
	);
}


1;


