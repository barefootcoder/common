package myperl::Menu;

use myperl;

use base 'Exporter';
our @EXPORT_OK = qw< mini_menu >;


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
				return $_ when ref eq '';								# not a ref, but a scalar: just return that value
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



my %KEYNAMES = ( ' ' => 'SPACE', "\n" => 'ENTER' );
func mini_menu ($choices, $prompt, HashRef :$help, HashRef :$dispatch, CodeRef :$premenu, :$delim = ',')
{
	my @choices = split(//, $choices);
	if ($help)
	{
		push @choices, '?';
		$help->{'?'} = 'print help';
	}
	my $opts = join($delim, map { $KEYNAMES{$_} // $_ } @choices);

	my $choice;
	PROMPT:
	{
		$premenu->() if $premenu and not defined $choice;
		print "$prompt [$opts] ";
		$choice = prompt -single;
		$choice = "\n" if length($choice) == 0;							# empty string means the user just hit ENTER

		if ($help and $choice eq '?')
		{
			say $KEYNAMES{$_} // $_, " - $help->{$_}" foreach @choices;
			redo PROMPT;
		}

		redo PROMPT unless $choices =~ /\Q$choice/;

		if ($dispatch and $dispatch->{$choice})
		{
			if ( $dispatch->{$choice}->($choice) != 0 )
			{
				undef $choice;
				redo PROMPT;
			}
		}
	};

	return $choice;
}


1;
