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
	requires 'Debuggit';
	requires 'Const::Fast';
	requires 'PerlX::bash';
	requires 'Import::Into';
	requires 'Sub::Install';
	requires 'version', '0.99';
	requires 'List::MoreUtils';
	requires 'Path::Class::Tiny';
	requires 'List::Util', '1.33';
};

# required to build stuff
feature build => sub
{
	requires 'Test::Most';
	requires 'Dist::Zilla';
	requires 'Devel::Confess';
	requires 'Test::Pod::Coverage';
	requires 'Module::Install::JSONMETA';
};

# required for myperl et al
feature myperl => sub
{
	requires 'CLASS';
	requires 'parent';
	requires 'version';
	requires 'Debuggit';
	requires 'TryCatch';
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
	requires 'Data::Printer';
	requires 'Test::Command';
	requires 'MooseX::Declare';
	requires 'Text::Capitalize';
	requires 'Path::Class::Tiny';
	requires 'MooseX::Has::Sugar';
	requires 'Method::Signatures';
	requires 'Any::Moose', '== 0.26';
	requires 'MooseX::ClassAttribute';
	requires 'MooseX::StrictConstructor';
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
	requires 'Syntax::Keyword::Try';
};

# required for Dropbox scripts
feature dropbox => sub
{
	requires 'Git::Helpers';
};

# required for banking/budget scripts
feature bank => sub
{
	requires 'Text::CSV';
};

# required for misc support scripts
feature support => sub
{
	requires 'Term::Size';
	requires 'File::Next';
	requires 'Date::Parse';								# `perlsecs` uses this, but should be rewritten to use Date::Easy
	requires 'Regexp::Common';							# `clgrep` uses this
	requires 'List::AllUtils';
	requires 'Time::ParseDate';							# `perlsecs` uses this, but should be rewritten to use Date::Easy
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

# possibly unused: move to proper section if definite dependency discovered
suggests 'Config::Any';
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
suggests 'Lingua::EN::Inflexion';

# required for VCtools
feature vctools => sub
{
	requires 'Test::Trap';
	requires 'Tie::IxHash';
	requires 'Date::Parse';
	requires 'Perl6::Form';
	requires 'Test::Command';
	requires 'Package::Stash';
	requires 'Mail::Sendmail';
	requires 'Config::General';
	requires 'MooseX::Has::Sugar';
	requires 'Method::Signatures';
	requires 'MooseX::Attribute::ENV';
};

# required for Leadpipe work
feature pb => sub
{
	requires 'Data::Rmap';
	requires 'Test::Trap';
	requires 'PerlX::Maybe';
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