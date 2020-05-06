package myperl::Pxb;

use myperl::Script ();
use List::Util qw< first >;

use CLASS;
use Path::Class::Tiny;
use PerlX::bash ':all';

use parent 'Exporter';
our @EXPORT =
(
	@PerlX::bash::EXPORT_OK,
	@Path::Class::Tiny::EXPORT, 'dir',
	qw< sh @ps $timerfile >,
);


########################
# PERSONAL STUFF       #
# (limited unit tests) #
########################

# define a command however it's defined in my .tcshrc alias
sub _get_alias { split(' ', first { $_ } map { /alias $_[1] '(.*?)'/ ? $1 : () } path("~/.tcshrc")->slurp) }

our @ps = CLASS->_get_alias("ps");

# some things will want to know where our timerfile is
our $timerfile = path('~/timer/timer-new');

######################
# END PERSONAL STUFF #
######################


##############
# TYPE STUFF #
##############

package myperl::Pxb::Types
{
	use Type::Utils -all;
	use Type::Library -base;


	class_type Path => { class => "Path::Class::Tiny" };
}

##################
# END TYPE STUFF #
##################


sub import
{
	my $package = shift;
	my $caller = caller;

	if ( $caller eq 'main' )
	{
		# pass through to myperl::Script
		myperl::Script->import::into(main => @_);
	}
	else
	{
		myperl::Pxb::Types->import::into($caller => 'Path');
	}
	$package->export_to_level(1, CLASS, @EXPORT);

	# in debug mode, don't use the real timerfile
	# (assuming we have one, which wouldn't be true on, say, sandboxes)
	if (main::DEBUG() and -e $timerfile)
	{
		my $testfile = $timerfile =~ s/new$/test/r;
		if (-e $testfile)
		{
			$timerfile = file($testfile);
		}
		else
		{
			$timerfile = $timerfile->copy_to($testfile);
		}
	}
}


sub sh
{
	unshift @_, wantarray ? \'lines' : \'string' if defined wantarray;
	unshift @_, -x => if $myperl::Script::OPT{D};
	# Yes, the Carp POD says don't do this.  Alternative suggestions welcomed.
	local $Carp::CarpLevel = $Carp::CarpLevel + 1;
	PerlX::bash::bash @_;
}



1;
