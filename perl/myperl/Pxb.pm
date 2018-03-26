package myperl::Pxb;

use myperl::Script ();

use PerlX::bash ':all';

use parent 'Exporter';
our @EXPORT =
(
	@PerlX::bash::EXPORT_OK,
	qw< sh >,
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
