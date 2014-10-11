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
		# You wouldn't think it would be necessary to include Moose in the list below, as
		# MooseX::Declare would do the equivalent of 'use Moose' for us.  However, the question is:
		# _when_ will MXD call Moose's import()?  Apparently the answer is "too damn late."  Modules
		# such as MooseX::StrictConstructor and MooseX::ClassAttribute apply roles to the metaclass
		# of the class which includes them.  But, if MXD hasn't called Moose::import() yet, then the
		# class _isn't_ technically a Moose class (yet), and therefore doesn't have a metaclass at
		# all.  Note the following two things:
		#
		# 1)	Tracking this down was horrifying.  The guts of Moose::Exporter is not a happy fun
		#		place.
		# 2)	MooseX::ClassAttribute at least was working without having to include Moose in the
		#		list below at some point.  I suspect Moose 2.08 as the culprit.  (You'd think it
		#		would have to be something in MXD, but that hadn't changed for nearly two years at
		#		the time this problem was discovered.)  So I'm pretty sure it's a change to Moose,
		#		and, given the timeframe, 2.08 (or 2.0801) seems the most likely.  I could probably
		#		prove this definitively by doing lots of testing on different Moose versions, but I
		#		don't know that's it's worth that much effort just to know the answer.

		my $calling_package = caller;
		myperl->import_list_into($calling_package,

			Debuggit						=>
			Moose							=>	2.00		=>
			CLASS							=>	1.00		=>
			TryCatch						=>
			'Const::Fast'					=>
			'Path::Class'					=>
			'Perl6::Form'					=>
			'Perl6::Slurp'					=>
			'Perl6::Gather'					=>	0.42		=>
			'MooseX::Has::Sugar'			=>
			'MooseX::ClassAttribute'		=>	0.26		=>
			'MooseX::StrictConstructor'		=>
			# don't have to actually do this one; Moose gives it to us for free
			#'Scalar::Util'					=>					[ qw< blessed > ],
			'List::Util'					=>					[ qw< first max min reduce shuffle sum > ],
			'List::MoreUtils'				=>					[ qw< apply zip uniq > ],
			'Class::Load'					=>					[ 'load_class' ],
			'MooseX::Types::Moose'			=>					[ ':all' ],

		);

		goto &MooseX::Declare::import;
	}

}


1;


=pod

=head1 SYNOPSIS

	use myperl::Declare;

is pretty much the same thing as:

	use myperl;

	use MooseX::Declare;
	use MooseX::Has::Sugar;
	use MooseX::ClassAttribute;
	use Method::Signatures::Modifiers;
	use MooseX::Types::Moose qw< all >;

except that you'd never actually C<use myperl::Declare> directly.  Instead, C<use myperl> and then
just declare your classes or roles with the appropriate keyword (a la L<MooseX::Declare>).

=cut
