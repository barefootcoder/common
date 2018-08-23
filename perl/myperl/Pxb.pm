package myperl::Pxb;

use myperl::Script ();
use List::Util qw< first >;

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

# define `ps` however it's defined in my .tcshrc alias
our @ps = split(' ', first { $_ } map { /alias ps '(.*?)'/ ? $1 : () } path("~/.tcshrc")->slurp);

# some things will want to know where our timerfile is
our $timerfile = path('~/timer/timer-new');

######################
# END PERSONAL STUFF #
######################


sub import
{
	my $package = shift;
	my $caller = caller;

	# pass through to myperl::Script
	myperl::Script->import::into(main => @_);

	$package->export_to_level(1, CLASS, @EXPORT);

	# in debug mode, don't use the real timerfile
	if (main::DEBUG())
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
	PerlX::bash::bash @_;
}



1;
