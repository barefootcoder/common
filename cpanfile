feature bootstrap => sub
{
	# basic infrastructure
	on build => sub
	{
		requires 'local::lib';
		requires 'experimental';
		requires 'IPC::System::Simple';
	};

	# need this much just to run the `cpm` wrapper
	requires 'CLASS';
	requires 'thanks';
	requires 'Debuggit';
	requires 'Const::Fast';
	requires 'Type::Utils';
	requires 'Import::Into';
	requires 'Sub::Install';
	requires 'version', '0.99';
	requires 'List::MoreUtils';
	requires 'Path::Class::Tiny';
	requires 'List::Util', '1.33';
	requires 'PerlX::bash', '0.04';
};

# required to build stuff
feature build => sub
{
	requires 'Test::Pod';
	requires 'Test::Most';
	requires 'File::Which';
	requires 'Devel::Confess';
	requires 'Test::Pod::Coverage';
	requires 'App::Cmd', '== 0.331';
	requires 'Pod::Weaver', '== 4.015';
	requires 'Dist::Zilla', '== 6.017';
	requires 'Pod::Coverage::TrustPod';
	requires 'Module::Install::JSONMETA';
	requires 'Log::Dispatchouli', '== 2.023';
	requires 'Dist::Zilla::PluginBundle::BAREFOOT';
	requires 'Dist::Zilla::Plugin::PodWeaver', '== 4.008';
	requires 'Dist::Zilla::Plugin::CheckPrereqsIndexed', '== 0.020';
};

# required for myperl et al
feature myperl => sub
{
	requires 'CLASS';
	requires 'parent';
	requires 'version';
	requires 'Debuggit';
	requires 'Template';
	requires 'Date::Easy';
	requires 'Test::Trap';
	requires 'Const::Fast';
	requires 'Perl6::Form';
	requires 'Math::Round';
	requires 'Import::Into';
	requires 'Sub::Install';
	requires 'Perl6::Slurp';
	requires 'IO::Prompter';
	requires 'Perl6::Gather';
	requires 'Test::Command';
	requires 'MooseX::Declare';
	requires 'Text::Capitalize';
	requires 'Path::Class::Tiny';
	requires 'MooseX::Has::Sugar';
	requires 'Method::Signatures';
	requires 'Syntax::Keyword::Try';
	requires 'Any::Moose', '== 0.26';				# newer version breaks Method::Signatures
	requires 'Time::Local', '>= 1.26';				# Date::Easy requires this
	requires 'MooseX::ClassAttribute';
	requires 'Data::Printer', '>= 1.0';
	requires 'MooseX::StrictConstructor';
	requires 'Devel::Declare', '== 0.006019';		# newer version breaks Method::Signatures
};
feature 'myperl-google' => sub
{
	requires 'Number::Latin';
	requires 'Config::General';
	requires 'Time::ParseDate';						# rewrite to use Date::Easy?
	requires 'MooseX::NonMoose';
	requires 'Class::PseudoHash';
	requires 'Net::Google::Calendar';
	requires 'Net::Google::PicasaWeb';
	requires 'Net::Google::Spreadsheets';
	requires 'Net::Google::DocumentsList';
};

# required for `xrestore` et al
feature xrestore => sub
{
	requires 'MCE::Map';
	requires 'XML::MyXML';
	requires 'X11::Protocol';						# required by win-display-only
	requires 'X11::Protocol::WM';					# required by win-display-only
	requires 'Syntax::Keyword::Try';
};

# required for banking/budget scripts
feature bank => sub
{
	requires 'Text::CSV';
	requires 'Finance::OFX::Parse::Simple';
};

# required for misc support scripts
feature support => sub
{
	requires 'Term::Size';
	requires 'File::Next';
	requires 'Date::Parse';								# `perlsecs` uses this, but should be rewritten to use Date::Easy
	requires 'MCE::Shared';								# `git-grep-all` uses this
	requires 'Sys::RunAlone';							# `music-player-ctl` uses this
	requires 'Regexp::Common';							# `clgrep` uses this
	requires 'List::AllUtils';
	requires 'Time::ParseDate';							# `perlsecs` uses this, but should be rewritten to use Date::Easy
	requires 'Number::Bytes::Human';
	requires 'Date::Gregorian::Business';				# `fake_timerdavg` uses this
};

# required for music scripts
feature music => sub
{
	requires 'Roman';
	requires 'MP3::Tag';							# constantly reinstalls itself :-(
	requires 'MP3::Info';
	requires 'File::Stat';
	requires 'File::Next';
	requires 'WWW::Mechanize';
	requires 'List::AllUtils';
	requires 'Time::ParseDate';						# used in lib/Music.pm; rewrite to use Date::Easy?
	requires 'Text::Unidecode';
	requires 'Text::Capitalize';
	requires 'Array::Columnize';
	requires 'Path::Class::Tiny';
	requires 'MooseX::Singleton';
	requires 'Lingua::EN::Numbers';
	requires 'Lingua::EN::Numbers::Years';
};

# required for Heroscape scripts
feature heroscape => sub
{
	requires 'Method::Signatures';					# used in transform
	requires 'Lingua::EN::Inflexion';				# used in analyze
};

# required for CE/Archer-adjacent scripts that have to run on the host
feature CE => sub
{
	requires 'IO::All';								# used by push song data collater
	requires 'Text::CSV';							# used by push song data collater
};

# possibly unused: move to proper section if definite dependency discovered
suggests 'Carp::Always';
suggests 'Email::Stuff';
suggests 'Archive::Zip';
suggests 'Hash::Ordered';
suggests 'Moose::Autobox';
suggests 'Module::Install';
suggests 'Getopt::Declare';
suggests 'Term::ANSIScreen';
suggests 'Archive::Tar::Wrapper';
suggests 'MooseX::App::Cmd', '== 0.31';

# required for VCtools
feature vctools => sub
{
	requires 'File::Set';
	requires 'Test::Trap';
	requires 'Tie::IxHash';
	requires 'Date::Parse';
	requires 'Perl6::Form';
	requires 'File::lchown';
	requires 'Test::Command';
	requires 'Package::Stash';
	requires 'Mail::Sendmail';
	requires 'Config::General';
	requires 'MooseX::Has::Sugar';
	requires 'Method::Signatures';
	requires 'MooseX::Attribute::ENV';
};

# required for various CARP scripts
feature carp => sub
{
	requires 'YAML::XS';
	requires 'PDF::FDF::Simple';
};

# required for Leadpipe work
feature pb => sub
{
	requires 'Safe::Isa';
	requires 'Data::Rmap';
	requires 'Test::Trap';
	requires 'CLI::Osprey';
	requires 'Import::Into';
	requires 'Sub::Install';
	requires 'PerlX::Maybe';
	requires 'Proc::Pidfile';
	requires 'Test::Mock::Time';
};

# required for Onyx work
feature onyx => sub
{
	requires 'Moops';
};

# required for blog articles
feature blog => sub
{
	requires 'Moops';
	requires 'Template';
	requires 'Tie::CPHash';
};

# required for Codex articles
feature html2bbcode => sub
{
	requires 'CSS::Simple';
	requires 'Archive::Zip';
	requires 'Marpa::R2::HTML';
};

# required for `todo`
feature todo => sub
{
	requires 'JSON::XS';
	requires 'Tie::IxHash';
};

# really old Barefoot libraries (including T3Tools)
feature 'old-barefoot' => sub
{
	requires 'Text::CSV';
	requires 'Tie::IxHash';
	requires 'Date::Parse';
	requires 'Date::Format';
	requires 'Config::General';
};
