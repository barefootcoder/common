use 5.012;
use warnings;
use Devel::Declare 0.006007 ();

package myperl;

use CLASS;
use Import::Into;
use Sub::Install;
use Module::Runtime qw< use_module >;


our %PASS_THRU =
(
	DEBUG	=>	'Debuggit',
);

our %PASS_UNLESS =
(
	NoFatalWarns	=>	[ warnings => [ FATAL => 'all' ] ],
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
			push @{ $mod_args{$PASS_THRU{$_}} }, [ $_ => $args{$_} ];
		}
		else
		{
			die("myperl: unknown argument $_") unless exists $PASS_UNLESS{$_};
		}
	}
	foreach (keys %PASS_UNLESS)
	{
		my $margs = $PASS_UNLESS{$_};
		push @{ $mod_args{$margs->[0]} }, $margs->[1] unless $args{$_};
	}
	my $calling_package = caller;

	# our own routines, which we have to transfer by hand
	Sub::Install::install_sub({ code => $_, into => $calling_package }) foreach \&title_case, \&round;

	myperl->import_list_into($calling_package,

		strict							=>
		warnings						=>					@{$mod_args{warnings}},,
		feature							=>					[	':5.12'			],
		#autodie						=>					[	':all'			],
		Debuggit						=>					@{$mod_args{Debuggit}},

		TryCatch						=>
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

#print STDERR "calling use_and_import_into with: $to_pkg, $from_pkg, ", $version || 'undef', ", ", $arguments ? scalar @$arguments : 'undef', " args\n";
		$class->use_and_import_into($to_pkg, $from_pkg, $version, $arguments);
    }
}

sub use_and_import_into
{
	my $args = ref $_[-1] eq 'ARRAY' ? pop : undef;
	my ($class, $to_pkg, $from_pkg, $version) = @_;

	use_module($from_pkg);
	$from_pkg->import::into($to_pkg, @{ $args || [] }) unless $args and @$args == 0;
}


sub title_case
{
	require Text::Capitalize;

	# ought to be able to use local here, but I can't seem to make it work
	# perhaps you can't localize variables in other packages?
	my @save = @Text::Capitalize::exceptions;
	push @Text::Capitalize::exceptions, qw< from into as >;
	my $t = Text::Capitalize::capitalize_title(@_, PRESERVE_ALLCAPS => 1);

	# preserving all caps seems to let the word "A" stay "A" when it should go to "a"
	# we'll fix that with an explicit substitution
	# we use literal spaces rather than \b's to avoid changing it at the beginning or end of the string
	$t =~ s/ A / a /g;

	@Text::Capitalize::exceptions = @save;
	return $t;
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


1;


=pod

=head1 INSTALLATION

You will probably need the following packages, which might not be installed already:

	openssl-devel [on Fedora] or libssl-dev    [on Linux Mint]
	libxml2-devel [on Fedora] or libexpat1-dev [on Linux Mint]

I<After> that, if you want to make sure you have all the necessary prereqs, try this:

	podselect -section PREREQS `perlfind -f myperl` | grep '^[a-zA-Z]' | cpanm -n

=head1 PREREQS

CLASS
Roman
parent
version
Debuggit
TryCatch
Template
MP3::Tag
Test::Most
Term::Size
File::Stat
IO::Prompt
Const::Fast
Path::Class
Tie::IxHash
Date::Parse
Perl6::Form
Dist::Zilla
Math::Round
Import::Into
Sub::Install
Perl6::Slurp
Date::Format
Carp::Always
Email::Stuff
Perl6::Gather
Test::Command
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
MooseX::Singleton
MooseX::Has::Sugar
Method::Signatures
IPC::System::Simple
Test::Pod::Coverage
Net::Google::Calendar
Net::Google::PicasaWeb
Net::Google::Spreadsheets
Module::Install::JSONMETA
Net::Google::DocumentsList

=cut
