package myperl::Script;

use 5.14.0;

use CLASS;
use File::Basename;

use myperl ();


use parent 'Exporter';
our @EXPORT = qw< $ME %OPT opts fatal usage_error >;

our $ME = $0 eq '-e' ? '<one-liner>' : basename($0);

our %OPT;


sub import
{
	my $package = shift;
	my $caller = caller;
	die("Must load $CLASS from package main") unless $caller eq 'main';

	$package->export_to_level(1, CLASS, @EXPORT);
	@_ = ( $package, NO_SYNTAX => 1, @_ );
	goto \&myperl::import;
}


my @help;
sub opts ($)
{
	require Getopt::Std;

	my ($help) = @_;
	my $optstring = '';

	my $block_pos = -2;			# -1: usage line; 0: option line; 1: first post-option line; 2+: subsequent lines
	my $prefix = 'usage';
	my $prefix_len = length($prefix) + 2;
	my $option_len = $prefix_len + 4;
	foreach (split("\n", $help))
	{
		s/^\s+//;
		if ( /^-(.)/ and $block_pos < 1)			# it's an option
		{
			$block_pos = 0;
		}
		else										# not an option; increment pos
		{
			++$block_pos;
		}

		if ( $block_pos == -1 )						# first line is usage line
		{
			$_ = "$prefix: $ME -h | $_";
		}
		elsif ( $block_pos == 0 )					# option line
		{
			$optstring .= $1;
			$optstring .= ':' if /<.*>/;
			$_ = ' ' x $option_len . $_;
		}
		else										# post-option block
		{
			if ($block_pos == 1)					# first post-option block line; add help option
			{
				$optstring .= 'h';
				push @help, ' ' x $option_len . "-h : this help message";
			}
			$_ = ' ' x $prefix_len . $_;
		}

		push @help, $_;
	}

	Getopt::Std::getopts($optstring, \%OPT);
	HELP_MESSAGE() if $OPT{h};
}

sub HELP_MESSAGE
{
	say foreach @help;
	exit;
}

sub fatal
{
	my $exitval = $_[0] =~ /^\d+/ ? shift : 1;
	my ($msg) = @_;
	say STDERR "$ME: $msg";
	exit $exitval;
}

sub usage_error
{
	my $msg = shift;
	fatal(2 => "$msg ($ME -h for help)");
}


1;
