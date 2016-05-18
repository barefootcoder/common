use 5.012;
use warnings;
use Devel::Declare 0.006007 ();

# This is typically called from myperl.pm.  You could `use` it directly if you wanted to, but it
# wouldn't gain you anything, and it's more characters to type.  So why would you?

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

			# We want our classes to have all the functions that myperl exports.
			# And we have guards against circular dependencies, so we can do this.
			myperl							=>

			# These are modules we _only_ want inside classes.
			Moose							=>	2.00		=>
			'Class::Load'					=>					[ 'load_class' ],
			'MooseX::Has::Sugar'			=>
			'MooseX::ClassAttribute'		=>	0.26		=>
			'MooseX::StrictConstructor'		=>
			'MooseX::Types::Moose'			=>					[ ':all' ],

		);

		goto &MooseX::Declare::import;
	}

}


1;


=pod

=head1 SYNOPSIS

	use myperl::Declare;
	class Foo
	{
	}

is pretty much the same thing as:

	use myperl;
	use MooseX::Declare;

	class Foo
	{
		use Class::Load 'load_class';
		use MooseX::Has::Sugar;
		use MooseX::ClassAttribute;
		use MooseX::StrictConstructor;
		use Method::Signatures::Modifiers;
		use MooseX::Types::Moose qw< all >;
	}

except that you never need to C<use myperl::Declare> directly.  Instead, C<use myperl> and then just
declare your classes or roles with the appropriate keyword (a la L<MooseX::Declare>).

See L<myperl> for full details.

=cut
