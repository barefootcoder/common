use myperl;

use Test::Most 0.25;

use Module::Runtime qw< module_notional_filename >;

sub loads_ok(&$$);


# menu()
loads_ok { menu(undef) } menu => 'myperl::Menu';


# expand()
loads_ok { expand('') } expand => 'Text::Tabs';


done_testing;


sub loads_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $module_key = module_notional_filename($module);

	is exists $INC{$module_key}, '', "haven't loaded $module yet";
	lives_ok { $sub->() } "can call $function()";
	is exists $INC{$module_key}, 1, "loaded $module now";
}
