package myperl::Pxb;

use myperl;											# for the proper `glob` (plus `first` and `file`)
use myperl::Script ();

use PerlX::bash ':all';

use parent 'Exporter';
our @EXPORT =
(
	@PerlX::bash::EXPORT_OK,
	qw< sh @ps $timerfile >,
);


sub import
{
	my $package = shift;
	my $caller = caller;

	# pass through myperl::Script
	myperl::Script->import::into(main => @_);

	$package->export_to_level(1, __PACKAGE__, @EXPORT);
}


sub sh
{
	unshift @_, wantarray ? \'lines' : \'string' if defined wantarray;
	PerlX::bash::bash @_;
}


###################
# PERSONAL STUFF  #
# (no unit tests) #
###################

# define `ps` however it's defined in my .tcshrc alias
our @ps = split(' ', first { $_ } map { /alias ps '(.*?)'/ ? $1 : () } file(glob("~/.tcshrc"))->slurp);

# some things will want to know where our timerfile is
our ($timerfile) = glob('~/timer/timer-new');
