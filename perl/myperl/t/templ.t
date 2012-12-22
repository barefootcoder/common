use File::Basename;
use myperl;
my $test_dir; BEGIN { $test_dir = dir(dirname($0), 'Test') }

use myperl::Template $test_dir;

use Test::Most 0.25;


# base template object creation
no warnings 'once';
isa_ok $myperl::Template::TT, 'Template', "global myperl::Template object";
ok grep { defined() && $_ eq '.' } @{ include_path() }, "INCLUDE_PATH contains ."
	or always_explain "INCLUDE PATH is ", include_path();
ok grep { defined() && $_ eq $test_dir } @{ include_path() }, "INCLUDE_PATH contains Test dir"
	or always_explain "INCLUDE PATH is ", include_path();

# some basic template fills (and error checking)
throws_ok { templ::process('bmoogle.tt', {}) } qr/not found/, "bogus template throws error"
	or diag "TT error is ", $myperl::Template::TT->error;
is templ::process('basic.tt', { name => 'Fred', thing => 'test' }), "Dear Fred,\n\nThis is a test.\n\n\t-- Me\n",
		"basic template fill looks good";


done_testing;


sub include_path
{
	my $context = $myperl::Template::TT->context;
	my $providers = $context->{'LOAD_TEMPLATES'};						# gotta be a better way to do this ...
	my $includes = [];
	push @$includes, @$_ foreach map { $_->include_path } @$providers;
	return $includes;
}
