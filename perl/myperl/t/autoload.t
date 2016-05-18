use myperl;

use Test::Most 0.25;

use Module::Runtime qw< module_notional_filename >;

sub loads_ok(&$$);


# menu()
loads_ok { menu(undef) } menu => 'myperl::Menu';


# expand()
loads_ok { expand('') } expand => 'Text::Tabs';


# slurp()
loads_ok { my $p = slurp '/etc/passwd' } slurp => 'Perl6::Slurp';


# form()
loads_ok { my $s = form("{<<}", "xx")	} form => 'Perl6::Form';


# basename()
# can't really test for it being unloaded/loaded, because something-or-other we depend on is already
# using it; therefore, just make sure we can call the method
lives_ok { basename('') } "can call basename()";


done_testing;


sub loads_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $module_key = module_notional_filename($module);

	is exists $INC{$module_key}, '', "haven't loaded $module yet";
	lives_ok { $sub->() } "can call $function()";
	is exists $INC{$module_key}, 1, "loaded $module now";
}
