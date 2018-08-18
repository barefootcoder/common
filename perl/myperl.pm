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

my $DISPLAY_IMPORTS;
sub import
{
	my $class = shift;
	my %args = @_;
	my $ONLY = delete $args{'ONLY'};
	my $NO_SYNTAX = exists $args{'NO_SYNTAX'} ? delete $args{'NO_SYNTAX'} : !!$ONLY;
	$DISPLAY_IMPORTS = delete $args{'DISPLAY_IMPORTS'};

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

	# to avoid vicious circular dependency issues, add a pointless "marker" sub
	# unless we've already added it, in which case just bail out
	my $marker_sub = '__myperl_loaded';
	return if $calling_package->can($marker_sub);
	Sub::Install::install_sub({ code => sub {}, into => $calling_package, as => $marker_sub });

	# our own routines, which we have to transfer by hand
	foreach (qw< title_case round expand prompt confirm >)
	{
		next if $ONLY and not $_ ~~ $ONLY;
		Sub::Install::install_sub({ code => $_, into => $calling_package });
	}

	# This is like a poor man's AUTOLOAD.  For each module/function pair, we're going to create a
	# function which loads the module, then passes off to the function.  Thus, if the function is
	# never called, the module will never be loaded.  If it is called, it will be just like the
	# function had been exported.
	my %autoload_funcs =
	(
		'Perl6::Slurp'		=>	'slurp',
		'Perl6::Form'		=>	'form',
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
		next if $ONLY and not $function ~~ $ONLY;						# don't export things if we're told not to

		my $loader = sub { use_module($module); goto \&{ join('::', $module, $function) }; };
		Sub::Install::install_sub({ code => $loader, into => $calling_package, as => $function })
				unless $calling_package->can($function);
	}
	# glob() is a CORE function, so must be handled separately
	unless ( $ONLY and not 'glob' ~~ $ONLY )
	{
		state $CORE_glob_already_redefined;
		unless ($CORE_glob_already_redefined)
		{
			*CORE::GLOBAL::glob = sub
			{
				require File::Glob;
				require Path::Class::Tiny;
				# use all the default flags *except* NOMAGIC
				state $flags = $File::Glob::DEFAULT_FLAGS & ~File::Glob::GLOB_NOMAGIC();

				my $pattern = shift;
				$pattern =~ s/^\s+//; $pattern =~ s/\s+$//;
				return map { Path::Class::Tiny::path($_) } File::Glob::bsd_glob($pattern, $flags);
			};
			$CORE_glob_already_redefined = 1;
		}
	}

	# always export these
	myperl->import_list_into($calling_package,

		strict							=>
		warnings						=>					@{$mod_args{warnings}},,
		feature							=>					[	':5.14'			],
		experimental					=>					[	'smartmatch'	],
		#autodie						=>					[	':all'			],
		Debuggit						=>	2.03_01		=>	@{$mod_args{Debuggit}},
		'Const::Fast'					=>
		'Scalar::Util'					=>					[ qw< blessed > ],
		'List::Util'					=>					[ qw< first max min reduce shuffle sum > ],
		'List::MoreUtils'				=>					[ qw< apply zip uniq > ],

	);

	# don't export these if our caller wants only certain functions
	myperl->import_list_into($calling_package,

		CLASS							=>	1.00		=>
		TryCatch						=>	1.003001	=>
		'Date::Easy'					=>	0.03		=>
		'Path::Class::Tiny'				=>
		'Perl6::Gather'					=>	0.42		=>
		'myperl::Declare'				=>
		'Method::Signatures'			=>	20111125	=>

	) unless $NO_SYNTAX;
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
	say STDERR ":: importing $from_pkg into $to_pkg ::" if $DISPLAY_IMPORTS;

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

	use 5.14.0;							# implies `use strict`
	use warnings FATAL => 'all';
	use experimental 'smartmatch';

	use CLASS;
	use TryCatch;
	use Date::Easy;
	use Perl6::Gather;
	use Path::Class::Tiny;
	use Method::Signatures;

	use Const::Fast;
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

Don't pass C<< DataPrinter => 1 >> to L<Debuggit> (i.e. have Debuggit use L<Data::Dumper> instead of
L<Data::Printer>).

=head2 NO_SYNTAX

	use myperl NO_SYNTAX => 1;

More of a lightweight version of C<myperl>.  Means not to load some of the heavier modules which add new syntax.  So therefore equivalent to:

	use 5.14.0;							# implies `use strict`
	use warnings FATAL => 'all';
	use experimental 'smartmatch';

	use Const::Fast;
	use Scalar::Util qw< blessed >;
	use List::Util qw< first max min reduce shuffle sum >;
	use List::MoreUtils qw< apply zip uniq >;

	use Debuggit DataPrinter => 1;

B<plus> still exporting all the functions listed below under L</FUNCTIONS>.  Besides not screwing
with your syntax as much, this is also much faster to load.

Note that this does not remove I<all> syntax that C<myperl> typically adds.  For instance, C<use
5.14.0> does the equivalent of C<use feature ':5.14'>, which adds C<say>, C<state>, C<given>, etc.
You could also argue that many of the list utility functions count as syntax.

=head2 ONLY

	use myperl ONLY => [qw< slurp time2str title_case >];

An even more lightweight version.  Implies the C<NO_SYNTAX> argument, plus restricts the function
exports to only those you specify.  Thus, the example above works out to the equivalent of:

	use 5.14.0;							# implies `use strict`
	use warnings FATAL => 'all';
	use experimental 'smartmatch';

	use Const::Fast;
	use Scalar::Util qw< blessed >;
	use List::Util qw< first max min reduce shuffle sum >;
	use List::MoreUtils qw< apply zip uniq >;

	use Debuggit DataPrinter => 1;

	*slurp      = \&myperl::slurp;
	*time2str   = \&myperl::time2str;
	*title_case = \&myperl::title_case;

meaning that L<Perl6::Slurp> and L<Date::Format> will still only be loaded if you call C<slurp> or
C<time2str>.

If you want no functions at all, you can do this:

	use myperl ONLY => [];

If you really want to get the syntax and only some of the functions, you can do something clever
like:

	use myperl NO_SYNTAX => 0, ONLY => [qw< slurp time2str title_case >];

The order of the arguments in this case is irrelevant.  Note that, unlike with C<< NO_SYNTAX =>
1 >>, this is not faster to load; it just reduces namespace pollution.

=head2 DISPLAY_IMPORTS

	use myperl DISPLAY_IMPORTS => 1;

All C<myperl> really does is import things ... lots of things.  If you're confused about what's
getting imported into where, use this to force a message every time it (attempts to) load a module
into a package's namespace.  Results in lots of messages to C<STDERR> that look like this:

	:: importing strict into main ::
	:: importing warnings into main ::
	:: importing feature into main ::
	:: importing experimental into main ::
	:: importing Debuggit into main ::
	:: importing List::Util into main ::
	:: importing List::MoreUtils into main ::
	:: importing TryCatch into main ::
	:: importing Const::Fast into main ::
	:: importing Path::Class::Tiny into main ::
	:: importing Perl6::Gather into main ::
	:: importing myperl::Declare into main ::
	:: importing Method::Signatures into main ::


=head1 FUNCTIONS

=head2 "Autoloaded" Functions

These functions are exported, but the modules they derive from are only loaded if the functions
themselves are called.  See their respective modules for more info on them:

=over

=item B<slurp> (from L<Perl6::Slurp>)

=item B<form> (from L<Perl6::Form>)

=item B<str2time> (from L<Date::Parse>)

=item B<time2str> (from L<Date::Format>)

=item B<basename> (from L<File::Basename>)

=item B<menu> (from L<myperl::Menu>)

=back

=head2 glob

The C<CORE::glob> function will be overridden to point at a thin wrapper around C<bsd_glob> from
L<File::Glob>.  This makes C<glob> actually useful again for file patterns that include spaces.
Note that this is different from:

	use File::Glob ':bsd_glob';

in the following ways:

=over

=item *

In a list context, it returns L<Path::Class::Tiny> objects (the File::Glob version just returns
strings).

=item *

In a scalar context, it returns a count of the files (the File::Glob version returns an iterator).

=item *

It can be used prior to Perl version 5.16 (which the File::Glob version cannot).

=item *

It doesn't send the C<GLOB_NOMAGIC> flag (which the File::Glob version does, by default).  This is
because NOMAGIC is stupid: if a pattern doesn't match, it doesn't match, and should never return any
results, regardless of whether there are any special characters in the pattern or not.

=back

If you specify L</ONLY>, C<CORE::glob> will B<not> be overridden (unless, of course, C<glob> is one
of the functions in the C<ONLY> list).

=head2 prompt

Like the date functions, C<prompt> from L<IO::Prompter> is made available, but the module is only
loaded if the function itself is called.  Actually this is a thin wrapper around the actual
IO::Prompter function.  There are currently only two differences:

=over

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

I<After> that, if you want to make sure you have all the necessary Perl prereqs, try this:

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
MP3::Tag											# constantly reinstalls itself :-(
MP3::Info
Text::CSV
local::lib
Test::Most
Term::Size
File::Stat
Data::Rmap
File::Next
XML::MyXML
Date::Easy											# finally got to the point where enough stuff depends on this
Test::Trap
Const::Fast
Tie::IxHash
Tie::CPHash
Date::Parse
Perl6::Form
Dist::Zilla
Math::Round
Date::Parse
Config::Any
CSS::Simple
experimental
Import::Into
Sub::Install
Perl6::Slurp
Date::Format
Carp::Always
Email::Stuff
Date::Format
IO::Prompter
Git::Helpers
Archive::Zip
PerlX::Maybe
Perl6::Gather
Data::Printer
Test::Command
Number::Latin
Hash::Ordered
Package::Stash
Mail::Sendmail
WWW::Mechanize
Regexp::Common
List::AllUtils
Module::Install
Config::General
MooseX::Declare
Time::ParseDate
Getopt::Declare
Text::Unidecode
Any::Moose@0.26
Marpa::R2::HTML
Text::Capitalize
MooseX::NonMoose
Term::ANSIScreen
Array::Columnize
Path::Class::Tiny
MooseX::Singleton
Class::PseudoHash
MooseX::Has::Sugar
Method::Signatures
IPC::System::Simple
Test::Pod::Coverage
Lingua::EN::Numbers
Syntax::Keyword::Try
MooseX::App::Cmd@0.31
Net::Google::Calendar
Archive::Tar::Wrapper
Net::Google::PicasaWeb
MooseX::ClassAttribute
MooseX::Attribute::ENV
Net::Google::Spreadsheets
Module::Install::JSONMETA
MooseX::StrictConstructor
Date::Gregorian::Business
Net::Google::DocumentsList
Lingua::EN::Numbers::Years

=cut
