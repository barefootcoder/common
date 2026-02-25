use myperl NO_SYNTAX => 1;

use Test::Most 0.25;

use Module::Runtime qw< module_notional_filename >;

sub loads_ok(&$$);


# expand()
loads_ok { expand('') } expand => 'Text::Tabs';


# slurp()
loads_ok { my $p = slurp '/etc/passwd' } slurp => 'Perl6::Slurp';


# form()
loads_ok { my $s = form("{<<}", "xx")	} form => 'Perl6::Form';


# basename()
loads_ok { basename('') } basename => 'File::Basename';


# Date::Easy (sub-modules share internal dependencies, so only test one with loads_ok)
loads_ok { date("1/1/2020") } date => 'Date::Easy::Date';
lives_ok { now() } "can call now()";
lives_ok { days } "can call days()";


# menu()
# do this one last, because it loads some of the above stuff
loads_ok { menu(undef) } menu => 'myperl::Menu';


# Subprocess tests (load Test::myperl here, not at top, because it pulls in
# Perl6::Slurp and File::Basename which would break the loads_ok tests above)
(my $test_dir = $0) =~ s{/[^/]+$}{};
unshift @INC, $test_dir;
require Test::myperl;
Test::myperl->import;

# Verify no prototype mismatch warnings when Date::Easy is explicitly imported
# after myperl has already installed autoload stubs
perl_no_error("no prototype warnings with explicit Date::Easy import", <<'END');
	use myperl::Pxb;
	use Date::Easy;
	say "ok";
END


done_testing;


sub loads_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $module_key = module_notional_filename($module);

	is exists $INC{$module_key}, '', "haven't loaded $module yet";
	lives_ok { $sub->() } "can call $function()";
	is exists $INC{$module_key}, 1, "loaded $module now";
}
