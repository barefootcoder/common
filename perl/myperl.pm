use 5.014;
use warnings;
use experimental 'smartmatch';

package myperl;

use Import::Into;
use Sub::Install;
use Module::Runtime qw< use_module >;


our %PASS_THRU =
(
	DEBUG	=>	'Debuggit',
);

our %PASS_UNLESS =
(
	NoFatalWarns	=>	[ warnings => [ FATAL => 'all'		] ],
	DataDumper		=>	[ Debuggit => [ DataPrinter => 1	] ],
);

sub import
{
	my $class = shift;
	my %args = @_;

	my %mod_args;
	foreach (keys %args)
	{
		if (exists $PASS_THRU{$_})
		{
			push @{ $mod_args{$PASS_THRU{$_}}->[0] }, $_ => $args{$_};
		}
		else
		{
			die("myperl: unknown argument $_") unless exists $PASS_UNLESS{$_};
		}
	}
	foreach (keys %PASS_UNLESS)
	{
		my $margs = $PASS_UNLESS{$_};
		push @{ $mod_args{$margs->[0]}->[0] }, @{ $margs->[1] } unless $args{$_};
	}
	#open(TTY, '>/dev/tty'); use Data::Printer output => *TTY; p %mod_args;

	my $calling_package = caller;

	# our own routines, which we have to transfer by hand
	Sub::Install::install_sub({ code => $_, into => $calling_package })
			foreach \&title_case, \&round, \&expand, \&prompt, \&confirm;

	# This is like a poor man's AUTOLOAD.  For each module/function pair, we're going to create a
	# function which loads the module, then passes off to the function.  Thus, if the function is
	# never called, the module will never be loaded.  If it is called, it will be just like the
	# function had been exported.
	my %autoload_funcs =
	(
		'Date::Parse'		=>	'str2time',
		'Date::Format'		=>	'time2str',
		'File::Basename'	=>	'basename',
		'myperl::Menu'		=>	'menu',
	);
	foreach (keys %autoload_funcs)
	{
		my $module = $_;
		next if $calling_package eq $module;							# don't export things to themselves

		my $function = $autoload_funcs{$module};
		my $loader = sub { use_module($module); goto \&{ join('::', $module, $function) }; };
		Sub::Install::install_sub({ code => $loader, into => $calling_package, as => $function })
				unless $calling_package->can($function);
	}

	myperl->import_list_into($calling_package,

		strict							=>
		warnings						=>					@{$mod_args{warnings}},,
		feature							=>					[	':5.14'			],
		experimental					=>					[	'smartmatch'	],
		#autodie						=>					[	':all'			],
		Debuggit						=>	2.03_01		=>	@{$mod_args{Debuggit}},

		#CLASS							=>	1.00		=>				# handled by myperl::Declare
		TryCatch						=>	1.003001	=>
		'Const::Fast'					=>
		'Path::Class'					=>
		'Perl6::Slurp'					=>
		'Perl6::Gather'					=>	0.42		=>
		'myperl::Declare'				=>
		'Method::Signatures'			=>	20111125	=>

	);
}


sub import_list_into
{
	use version 0.99 ();
	my ($class, $to_pkg, @modules) = @_;

    while (@modules)
	{
        my $from_pkg = shift(@modules);
		my ($version, $arguments);
        $version = version->parse(shift(@modules))->numify if @modules and version::is_lax($modules[0]);
        $arguments = shift @modules if @modules and ref($modules[0]) eq 'ARRAY';

#warn("calling use_and_import_into with: $to_pkg, $from_pkg, ", $version || 'undef', ", args ", $arguments ? "[ @{$arguments||[]} ]" : '[]');
		$class->use_and_import_into($to_pkg, $from_pkg, $version, $arguments);
    }
}

sub use_and_import_into
{
	my $args = ref $_[-1] eq 'ARRAY' ? pop : undef;
	my ($class, $to_pkg, $from_pkg, $version) = @_;

	$version ? use_module($from_pkg, $version) : use_module($from_pkg);
	$from_pkg->import::into($to_pkg, @{ $args || [] }) unless $args and @$args == 0;
}


sub title_case
{
	use utf8;
	require Text::Capitalize;
	require Unicode::Normalize;

	# let's make this work with Unicode
	local $Text::Capitalize::word_rule = $Text::Capitalize::word_rule;
	$Text::Capitalize::word_rule =~ s/\\w/\\p{Word}/g;

	# ought to be able to use local here, but I can't seem to make it work
	# perhaps you can't localize variables in other packages?
	my @save = @Text::Capitalize::exceptions;
	push @Text::Capitalize::exceptions, qw< from into as on le la du un pour des >;
	@Text::Capitalize::exceptions = grep { not $_ ~~ [ qw< has so > ] } @Text::Capitalize::exceptions;
	my $t = Unicode::Normalize::NFD(Text::Capitalize::capitalize_title(@_, PRESERVE_ALLCAPS => 1));

	# preserving all caps seems to let the word "A" stay "A" when it should go to "a"
	# we'll fix that with an explicit substitution
	# we use literal spaces rather than \b's to avoid changing it at the beginning or end of the string
	$t =~ s/ (A\X?) / lc " $1 " /eg;

	# some fixups for French titles
	$t =~ s/ ([DL])'(\p{Word})/ lc(" $1") . "'$2" /eg;
	$t =~ s/\b([DLdl])'(\p{Word})/ "$1'" . uc($2) /eg;

	@Text::Capitalize::exceptions = @save;
	return Unicode::Normalize::NFC($t);
}


sub round
{
	require POSIX;
	require Math::Round;
	state $opts = { map { $_ => 1 } qw< OFF UP DOWN > };

	my $how = $opts->{$_[0]} ? shift : 'OFF';
	my ($num, $to) = @_;
	$to ||= 1;

	given ($how)
	{
		return POSIX::ceil($num / $to) * $to when 'UP';
		return POSIX::floor($num / $to) * $to when 'DOWN';
		return Math::Round::nearest($to, $num) when 'OFF';
	}
}


sub expand
{
	require Text::Tabs;
	$Text::Tabs::tabstop = 4;
	goto &Text::Tabs::expand;
}


sub prompt
{
	require IO::Prompter;
	my $answer;
	if (grep { /^-/ } @_)
	{
		$answer = &IO::Prompter::prompt;
	}
	else
	{
		my ($prompt, %in_opts) = @_;
		my %out_opts;
		if (exists $in_opts{default})
		{
			$prompt = "$prompt [$in_opts{default}] ";
			$out_opts{-default} = $in_opts{default};
		}
		$answer = IO::Prompter::prompt($prompt, %out_opts);
	}
	return $answer ? "$answer" : 0;
}

sub confirm
{
	require IO::Prompter;
	my ($prompt) = @_;

	undef @ARGV;														# if we don't do this, odd things will happen
	return IO::Prompter::prompt(-y1, "$prompt [y/N]") ? 1 : 0;
}


1;


=pod

=head1 SYNOPSIS

	use myperl;

is pretty much the same thing as:

	use 5.12.0;							# implies `use strict`
	use warnings FATAL => 'all';

	use CLASS;
	use TryCatch;
	use Const::Fast;
	use Path::Class;
	use Perl6::Form;
	use Perl6::Slurp;
	use Perl6::Gather;
	use Method::Signatures;

	use Class::Load 'load_class';
	use Scalar::Util qw< blessed >;
	use List::Util qw< first max min reduce shuffle sum >;
	use List::MoreUtils qw< apply zip uniq >;

	use myperl::Declare;
	use Debuggit DataPrinter => 1;

Plus the import of any functions below under L</FUNCTIONS>.


=head1 OPTIONS

The following options can be passed to C<myperl>.  They can be combined in any permutation.

=head2 DEBUG

	use myperl DEBUG => 2;

This is just passed straight through to L<Debuggit>.

=head2 NoFatalWarns

	use myperl NoFatalWarns => 1;

Don't make all warnings fatal (but still turn them on).

=head2 DataDumper

	use myperl DataDumper => 1;

Don't pass C<DataPrinter =E<gt> 1> to L<Debuggit> (i.e. have Debuggit use L<Data::Dumper> instead of
L<Data::Printer>).


=head1 FUNCTIONS

=head2 Date Functions

These functions are exported, but the modules they derive from are only loaded if the functions
themselves are called.  See their respective modules for more info on them:

=over 4

=item B<str2time> (from L<Date::Parse>)

=item B<time2str> (from L<Date::Format>)

=back

=head2 prompt

Like the date functions, C<prompt> from L<IO::Prompter> is made available, but the module is only
loaded if the function itself is called.  Actually this is a thin wrapper around the actual
IO::Prompter function.  There are currently only two differences:

=over 4

=item *

This C<prompt> returns a string, not an object.

=item *

If you use this syntax:

	my $thing = prompt "Enter thing:", default => "nothing";

it will work just like the native IO::Prompter syntax:

	my $thing = prompt "Enter thing:", -default => "nothing";

except that the default value is appended to the prompt.  So it really is equivalent to:

	my $thing = prompt "Enter thing: [nothing]", -default => "nothing";

=back

Ideally, the wrapper should also always throw exceptions in the case of failure (or timeout), but
this hasn't been implemented yet.

See L<IO::Prompter> for full details.

=head2 confirm

This is a convenience function for yes/no prompts.  The code:

	my $result = confirm "Are you sure?";

is equivalent to:

	my $result = prompt -y1, "Are you sure? [y/N]" ? 1 : 0;

Note that this uses C<IO::Prompter::prompt> directly instead of going through L</prompt> as
described above.  See L<IO::Prompter> for how C<prompt> works.

=head2 expand

Autoloads C<expand> from L<Text::Tabs>, but also sets a tabstop to 4 spaces (which it should be) and
makes sure C<$tabstop> isn't exported into your namespace (which it shouldn't be).

=head2 title_case

	$title = title_case($title);

Similar to the C<capitalize_title> method of L<Text::Capitalize>.  It preserves words in all caps,
but still handles the word "a" appropriately.  It also adds a few more exceptions to the list,
including some which make it work more appropriately for French titles.

=head2 round

    $num = round($num);                 # round off to the nearest 1
    $num = round(OFF => $num);          # same thing
    $num = round(DOWN => $num);         # or can round down
    $num = round(UP => $num);           # or up
    $num = round($num, .25);            # round off to the nearest 1/4
    $num = round(DOWN => $num, .25);    # combine all options

A simple way to do rounding.  When you give round() an initial argument of C<UP>, it acts just like C<POSIX::ceil>.
When you give it an initial argument of C<DOWN>, it behaves just like C<POSIX::floor>.  When you use
an initial argument of C<OFF>, or omit that argument altogether, it acts like C<nearest> from
L<Math::Round>.


=head1 INSTALLATION

You will probably need the following packages, which might not be installed already:

	openssl-devel [on Fedora] or libssl-dev    [on Linux Mint]
	libxml2-devel [on Fedora] or libxml2-dev   [on Linux Mint]
	expat-devel   [on Fedora] or libexpat1-dev [on Linux Mint]

I<After> that, if you want to make sure you have all the necessary prereqs, try this:

	podselect -section PREREQS `perlfind myperl` | grep '^[a-zA-Z]' | cpanm -n

=head1 PREREQS

# ignore this section if you're reading the man page

CLASS
Moops
Roman
parent
version
Debuggit
TryCatch
Template
JSON::XS
MCE::Map
#MP3::Tag																# constantly reinstalls itself :-(
MP3::Info
local::lib
Test::Most
Term::Size
File::Stat
Data::Rmap
File::Next
XML::MyXML
Const::Fast
Path::Class
Tie::IxHash
Tie::CPHash
Date::Parse
Perl6::Form
Dist::Zilla
Math::Round
Date::Parse
experimental
Import::Into
Sub::Install
Perl6::Slurp
Date::Format
Carp::Always
Email::Stuff
Date::Format
IO::Prompter
Perl6::Gather
Data::Printer
Test::Command
Number::Latin
Package::Stash
Mail::Sendmail
Module::Install
Config::General
MooseX::Declare
Time::ParseDate
Getopt::Declare
Text::Unidecode
Text::Capitalize
MooseX::NonMoose
Term::ANSIScreen
MooseX::App::Cmd
Array::Columnize
MooseX::Singleton
Class::PseudoHash
MooseX::Has::Sugar
Method::Signatures
IPC::System::Simple
Test::Pod::Coverage
Net::Google::Calendar
Net::Google::PicasaWeb
MooseX::ClassAttribute
MooseX::Attribute::ENV
Net::Google::Spreadsheets
Module::Install::JSONMETA
MooseX::StrictConstructor
Date::Gregorian::Business
Net::Google::DocumentsList

=cut
