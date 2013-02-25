use 5.012;
use warnings;

# This expects to be called from myperl.pm.  If it's not, it won't be able to find
# import_list_into().  OTOH, if it tries to 'use myperl', it will create a circular dependency,
# which is also bad.  I'm not bothering to fix this for now.  One possible fix is to put this back
# into myperl.pm; we'll have to see if that changes any behavior after we're all done.
#
# Nonetheless, you really shouldn't include myperl::Declare directly.  This is just to stop errors
# on things like perlfind and whatnot.  Including myperl::Declare directly is a) unnecessary, and b)
# won't do what you expect.  Unless you expect to be scratching your head a lot.

use myperl ();
use MooseX::Declare;


class myperl::Declare extends MooseX::Declare
{
	use Method::Signatures::Modifiers;


	sub import
	{
		my $calling_package = caller;
		myperl->import_list_into($calling_package,

			Debuggit						=>
			CLASS							=>	1.00		=>
			TryCatch						=>
			'Const::Fast'					=>
			'Path::Class'					=>
			'Perl6::Form'					=>
			'Perl6::Slurp'					=>
			'Perl6::Gather'					=>	0.42		=>
			'MooseX::Has::Sugar'			=>
			'MooseX::ClassAttribute'		=>	0.26		=>
			'List::Util'					=>					[ qw< first max min reduce shuffle sum > ],
			'List::MoreUtils'				=>					[ qw< apply zip uniq > ],
			'Class::Load'					=>					[ 'load_class' ],
			'MooseX::Types::Moose'			=>					[ ':all' ],

		);

		goto &MooseX::Declare::import;
	}

}
