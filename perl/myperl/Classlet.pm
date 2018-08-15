use 5.012;
use warnings;
use autodie ':all';


package myperl::Classlet
{
	use parent 'Moops';

	sub import
	{
		my ($class, %opts) = @_;

		push @{ $opts{imports} //= [] },
		(
			warnings	=>	[ FATAL => 'all' ],
		);

		$class->SUPER::import(%opts);
	}
}


1;
