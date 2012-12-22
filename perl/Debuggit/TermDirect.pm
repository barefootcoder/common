package Debuggit::TermDirect;

use Carp;
use IO::Handle;
use Method::Signatures;

use Debuggit ();


our $count = 0;

open_direct();


$Debuggit::formatter = sub { return '#>>> ' . ++$count . '. ' . Debuggit::default_formatter(@_) };
$Debuggit::output = sub { open_direct(); DIRECT->printflush(@_); };

sub import
{
	my $class = shift;
	Debuggit->import(PolicyModule => 1, DEBUG => 1);

	Debuggit::add_func(CMD => 1, method ($cmd)
	{
		my @lines = `$cmd`;
		chomp @lines;
		return @lines;
	});

	Debuggit::add_func(ENV => 1, method ($varname)
	{
		return ("\$$varname =", $ENV{$varname});
	});
}


sub open_direct
{
	if (tell(DIRECT) == -1)
	{
		open(DIRECT, '>/dev/tty') or croak("couldn't open channel to terminal");
	}
}
