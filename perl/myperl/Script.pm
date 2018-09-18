package myperl::Script;

use 5.14.0;

use CLASS;
use Import::Into;
use File::Basename;
use List::MoreUtils qw< apply >;

use myperl ();
use Debuggit DataPrinter => 1;


use parent 'Exporter';
our @EXPORT = qw< $ME %OPT opts fatal usage_error >;

our $ME = $0 eq '-e' ? '<one-liner>' : basename($0);

our %OPT;


sub import
{
	my $package = shift;
	my $caller = caller;
	die("Must load $CLASS from package main") unless $caller eq 'main';

	# set up file handles appropriately
	$| = 1;
	'open'->import::into(main => ':utf8' => ':std');

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

	my $add_help_opt = sub
	{
		$optstring .= 'h';
		push @help, ' ' x $option_len . "-h : this help message";
	};

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
			++$block_pos unless $block_pos;			# can't be 0 (an option line)
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
			&$add_help_opt if $block_pos == 1;		# first post-option block line; add help option
			$_ = ' ' x $prefix_len . $_;
		}

		push @help, $_;
	}
	&$add_help_opt if $block_pos == 0;				# there _were_ no post-option block lines; add help option

	# turn warnings from `getopts` into something more palatable
	# and make sure they bomb out the script
	my @warnings;
	{
		local $SIG{__WARN__} = sub { push @warnings, @_ };
		Getopt::Std::getopts($optstring, \%OPT);
	}
	usage_error(join(', ', apply { chomp } @warnings)) if @warnings;

	debuggit(4 => "OPT:", $optstring, "=>", DUMP => \%OPT);
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


=pod

=head1 SYNOPSIS

	use myperl::Script;

is pretty much the same thing as:

	use myperl NO_SYNTAX => 1;

	our $ME = basename($0);
	our %OPT;

	$| = 1;
	use open ':std', ':utf8';

except that it does a bit more as well:

=over

=item *

It can only be called from the C<main> package.  Doing C<use myperl::Script> from another package
throws an exception.

=item *

All the functions listed below (see L</FUNCTIONS>) are imported.

=back

Arguments passed to C<myperl::Script>, such as:

	use myperl::Script DEBUG => 2;

or:

	use myperl::Script ONLY => [qw< glob slurp expand >];

just get passed directly through to L<myperl>.  The C<NO_SYNTAX> arg is still passed, but  you could
conceivably get around that by doing:

	use myperl::Script NO_SYNTAX => 0;

But don't do that.  All the syntax-loading stuff adds too much overhead for quick scripts, and you
hardly ever need it all anyway.


=head1 FUNCTIONS

=head2 opts

This is a moderately declarative way to specify switches and arguments to your script.  Example
usage:

	opts <<'-';
		[-ab] [-c <thingy>] <file> [...]
		-a : turn a on
		-b : turn b on
		-c : specify a <thingy>
		does things to files
		<thingy> : a frobnozzled glatterspack
		<file>   : at least one file to operate on
	-

You don't have to use a here doc, but that is highly recommended.  In particular, this style:

	opts '
		...
	';

is going to cause you heartache, because it technically starts with a blank line, which is going to
throw everything off.  The choice of delimiter is course completely arbitrary, but C<'-'> (or
sometimes C<'.'>) is common.  You can use double quotes instead of single quotes if you need to
interpolate anything into the spec, but that should be rare.

Any whitespace at the beginning of spec lines is completely ignored.  Indent things however (and
however much) you like.

The first line is the usage line (unless it starts with C<->, so don't do that).  The usage line is
used to build the help message and nothing else.

After any usage lines, all lines that start with C<-> describe options, I<< until the first line
that B<doesn't> start with C<-> >>.  Any lines starting with a dash after the first non-dash line
are considered part of the next section.  Option lines should contain a dash, a single character,
then some description of what the switch does.  Option lines serve double duty: they are put into
the help message (verbatim), but they are also used to build the argument to L<Getopt::Std>'s
C<getopts> as well.  If the description contains any word in wedges (such as the C<-c> option in the
example above), then the option takes an argument; otherwise it doesn't.  There is (currently) no
way to specify long options.

Once C<opts> sees a line that doesn't start with a dash, all remaining lines are considered
post-option lines.  Post-option lines are put into the help message verbatim.

A C<-h> option is automatically added for you, both in the argument to C<getopts> and in the help
message.  Because C<getopts> honors them, C<opts> will also respond as expected to C<-->, C<--help>,
and C<--version>.

Options specified on the comamnd line to your script are available in L</%OPT>.

=head2 fatal

	fatal("bmoogle is missing!") unless -r "bmoogle";

Prints the supplied message to C<STDERR>, prepending the script's basename (i.e. L</$ME>), then
exits with a value of 1.

=head2 usage_error

	my $bmoogle = shift or usage_error("must supply bmoogle");

Prints the supplied message to C<STDERR>, prepending the script's basename (i.e. L</$ME>) and
appending a suggestion to try the C<-h> switch, then exits with a value of 2.


=head1 VARIABLES

=head2 $ME

This is a string containing the basename of the script.  If you are doing a one-liner, like so:

	perl -Mmyperl::Script -E 'say "$ME is not very useful"'

then C<$ME> is the string "<one-liner>" instead.

=head2 %OPT

A hash containing the values of your script's command-line switches.  For instance, given the
example code shown in L</opts>, and given a command-line invocation like so:

	your-script -a -c foo file1 file2

then the following are true:

	$OPT{a} == 1;
	not defined($OPT{b});
	$OPT{c} eq 'foo';

And of course C<@ARGV> contains C<< qw< file1 file2 > >>.


=head1 FILE HANDLE ADJUSTMENTS

Your C<STDOUT> is set to autoflush, which is most often what you want in a script.

All your standard file handles (i.e. C<STDIN>, C<STDOUT>, and C<STDERR>), as well as any files you
open in your script, are set to handle UTF8 characters.  This avoids "Wide character in" errors
which will crash your script (unless you passed C<NoFatalWarn> to the C<use> line, in which case
it's "merely" an unsightly warning).

=cut
