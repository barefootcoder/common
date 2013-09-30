package myperl::Menu;

use myperl;


my ($status, $status_func);
menu::status('');

func menu::status ($new_status)
{
	if (ref $new_status eq 'CODE')
	{
		$status_func = $new_status;
	}
	else
	{
		$status_func = \&_show_status;
		$status = $new_status;
	}
}

func _show_status
{
	say "\n$status\n\n";
}


func menu ($menu, :$prompt = "Enter letter of choice.\nUse <Esc> to return to previous menu.\n")
{
	return unless defined $menu;

	MENULOOP: while (1)
	{
		system("clear");
		$status_func->();

		while (1)
		{
			local $_ = prompt $prompt, -single, -menu => [ keys %$menu ], '>';
			return 1 unless defined $_ and eval { my $x = "$_"; 1 };	# this is for <Esc>
			given ($menu->{$_})
			{
				_dispatch($_) when ref eq 'CODE';
				menu($_) and next MENULOOP when ref eq 'HASH';
				return 1 when undef;									# this is for explicit "return to prev menu" option
			}
			last if $_;
		}

		print "\n\nPress RETURN to continue ...  ";
		<STDIN>;
	}
}

func _dispatch ($code)
{
	say "\n";
	try
	{
		$code->();
		1;
	}
	catch ($err)
	{
		say STDERR "call died with: $err";
	}
}


1;
