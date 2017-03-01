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


# menu()
# do this one last, because it loads some of the above stuff
loads_ok { menu(undef) } menu => 'myperl::Menu';


done_testing;


sub loads_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $module_key = module_notional_filename($module);

	is exists $INC{$module_key}, '', "haven't loaded $module yet";
	lives_ok { $sub->() } "can call $function()";
	is exists $INC{$module_key}, 1, "loaded $module now";
}
