use myperl;


class Calendar::Event extends Net::Google::Calendar::Entry
{
	use DateTime;
	use MooseX::NonMoose;
	use Class::MOP::Class;
	use Net::Google::Calendar;


	method _format_datetime ($dt)
	{
		use Date::Format;

		return time2str('%L/%d/%Y %l:%M%P', $dt->epoch);
	}

	method _parse_datetime ($datetime)
	{
		use Time::ParseDate;

		my $secs = parsedate($datetime, PREFER_FUTURE => 1) || die("$datetime doesn't appear to be a valid datetime");
		return DateTime->from_epoch( epoch => $secs );
	}


	method from ()
	{
		my ($from, undef, undef) = $self->when;
		return $from->epoch;
	}

	method to ()
	{
		my (undef, $to, undef) = $self->when;
		return $to->epoch;
	}

	around when ()
	{
		my ($from, $to, $allday) = $self->$orig;
		return $from->mdy('/') if $allday;
		return $self->_format_datetime($from) . ' - ' . $self->_format_datetime($to);
	}

}


class Google::Service
{
	use MooseX::ClassAttribute;

	use Net::Google::Calendar;
	use Net::Google::PicasaWeb;
	use Net::Google::Spreadsheets;
	use Net::Google::DocumentsList;


	class_has _config		=>	( ro, isa => 'HashRef', lazy, builder => '_read_config' );

	has _acct_config		=>	( ro, isa => 'HashRef', lazy, builder => '_choose_config' );

	method _read_config
	{
		use Config::General qw< ParseConfig >;

		return { ParseConfig("$ENV{HOME}/.googlerc") };
	}

	method _choose_config
	{
		return $self->account eq 'default' ? $self->_config : $self->_config->{$self->account};
	}


	has _ssheets	=>	( ro, isa => 'Net::Google::Spreadsheets', lazy, builder => '_connect_to_spreadsheets',
								handles => [ qw< spreadsheet > ] );
	has _doclist	=>	( ro, isa => 'Net::Google::DocumentsList', lazy, builder => '_connect_to_documents',
								handles => { document => 'item' } );
	has _calendar	=>	( ro, isa => 'Net::Google::Calendar', lazy, builder => '_connect_to_calendar' );
	has _picasa		=>	( ro, isa => 'Net::Google::PicasaWeb', lazy, builder => '_connect_to_picasa',
								handles => { photo_albums => 'list_albums' } );

	has account		=>	( ro, isa => Str, default => 'default' );

	method _connect_to_spreadsheets
	{
		return Net::Google::Spreadsheets->new( $self->_login_params('hash') );
	}

	method _connect_to_documents
	{
		return Net::Google::DocumentsList->new( $self->_login_params('hash') );
	}

	method _connect_to_calendar
	{
		my $cal = Net::Google::Calendar->new;
		# this is totally and utterly cheating here ...
		if ($self->_acct_config->{'url'})
		{
			$cal->{_auth}->{url} = $self->_acct_config->{'url'};
		}

		$cal->login( $self->_login_params('list') );
		return $cal;
	}

	method _connect_to_picasa
	{
		my $picasa = Net::Google::PicasaWeb->new;
		$picasa->login( $self->_login_params('list') );
		return $picasa;
	}


	method _login_params ($type)
	{
		my $user = $self->_acct_config->{'username'} || $self->_acct_config->{'user'};
		my $passwd = $self->_acct_config->{'password'};
		debuggit(4 => "login params:", $user, $self->_obscurify($passwd));

		return ($user, $passwd) if $type eq 'list';
		return (username => $user, password => $passwd) if $type eq 'hash';
		die("unknown type to _login_params: $type");
	}

	method _obscurify ($passwd)
	{
		# this is not really that obscure, but it's close enough for now
		return substr($passwd, 0, 1) . '*' x (length($passwd) - 2) . substr($passwd, -1);
	}


	method upload_doc ($file, $folder?)
	{
		use File::Basename;

		my $name = basename($file);
		my $dest = $folder ? $self->_doclist->folder({ title => $folder }) : $self->_doclist;

		return $dest->add_item({ title => $name, file => $file });
	}


	method cal_events ($day)
	{
		use Time::ParseDate;

		my $secs = parsedate("$day midnight") || die("$day doesn't appear to be a valid date");
		my $from = DateTime->from_epoch( epoch => $secs );
		return
			map { Calendar::Event->meta->rebless_instance($_) }
			$self->_calendar->get_events( 'start-min' => $from, 'start-max' => $from->add( days => 1 ) );
	}

	method add_cal_event (%params)
	{
		state $REMINDER_TYPES =
		{
			alert		=>	1,
			email		=>	1,
			sms			=>	1,
		};
		state $REMINDER_UNITS =
		{
			d	=>	'days',
			h	=>	'hours',
			m	=>	'minutes',
		};

		debuggit(4 => "event params:", DUMP => \%params);
		my $event = Net::Google::Calendar::Entry->new;

		# fixup the when and howlong bits
		if ($params{'when'})
		{
			my $from = Calendar::Event->_parse_datetime(delete $params{'when'});
			my $duration = delete $params{'howlong'};
			my $allday = !$duration;
			my $until = $from + DateTime::Duration->new( hours => $duration );
			debuggit(3 => "going to set when:", $from, $until, $allday);
			$event->when($from, $until, $allday);
		}
		else
		{
			die("must specify when the event takes place");
		}

		# fixup guests
		if ($params{'guests'})
		{
			my $guests = delete $params{'guests'};
			my @guests = gather
			{
				while (my ($name, $email) = each %$guests)
				{
					my $p = Net::Google::Calendar::Person->new;
					$p->name($name);
					$p->email($email);
					take $p;
				}
			};

			$event->who(@guests);
		}

		# fixup reminder
		if ($params{'reminder'})
		{
			my $reminder = delete $params{'reminder'};
			my ($type, $qty, $unit) = $reminder =~ /^(\w+)\s+(\d+)([a-z])$/ or die("bad format for reminder: $reminder");
			die("unknown reminder type: $type") unless exists $REMINDER_TYPES->{$type};
			die("unknown reminder unit: $unit") unless exists $REMINDER_UNITS->{$unit};

			$event->reminder($type, $REMINDER_UNITS->{$unit}, $qty);
		}

		# what we have left should just map directly to mutators
		foreach (keys %params)
		{
			my $method = $event->can($_);
			$event->$method($params{$_});
		}

		debuggit(3 => "event:", DUMP => $event);
		# and throw it on the calendar
		$self->_calendar->add_entry($event);
	}


	method photo_album ($album_title)
	{
		my @albums = grep { $_->title eq $album_title } $self->photo_albums;
		return @albums ? $albums[0] : die("no such photo album: $album_title");
	}

	method photo_url ($photo_title, :$album)
	{
		my $list_from = $album ? $self->photo_album($album) : $self->_picasa;
		my @photos = grep { $_->title =~ /^\Q$photo_title\E\./ } $list_from->list_photos;
		die("cannot find photo: $photo_title") unless @photos;

		my $photo = $photos[0];
		my $width = $photo->width;
		my $url = $photo->photo->thumbnails->[0]->url;
		$url =~ s{/s\d+/}{/s$width/};
		return $url;
	}

}


class Google::Worksheet
{

	has	_sheet		=>	( ro, isa => 'Net::Google::Spreadsheets::Worksheet', lazy, builder => '_read_sheet' );
	has _columns	=>	( ro, isa => 'ArrayRef', lazy, builder => '_read_headers' );
	has _headers	=>	( ro, isa => 'HashRef[Int]', lazy,
							default => method
							{
								my $a = $self->_columns;
								return +{ map { defined $a->[$_] ? ($a->[$_] => $_) : () } 0..$#$a };
							},
						);
	has _data		=>	( rw, isa => 'ArrayRef[Maybe[ArrayRef]]', lazy, builder => '_get_data',
							traits => [qw< Array >], handles =>
							{
								has_data		=>	'count',
								rows			=>	'elements',
							},
						);
	has _keymap		=>	( rw, isa => 'HashRef[Int]', lazy, builder => '_build_keymap' );

	method _read_sheet ()
	{
		my $ssheet = $myperl::Google::GOOGLE->spreadsheet({ title => $self->doc });
		die("can't find spreadsheet: " . $self->doc) unless $ssheet;
		my $wsheet = $ssheet->worksheet({ title => $self->name });
		die("can't find worksheet " . $self->name . " in requested doc") unless $wsheet;
		return $wsheet;
	}

	method _read_headers ()
	{
		my @header_cells = $self->_sheet->cells({ row => $self->header_row });
		my $cols = [];
		$cols->[$_->col] = $_->content foreach @header_cells;
		return $cols;
	}

	method _get_data ()
	{
		my %rows;
		foreach ( $self->_sheet->cells({ 'min-row' => $self->header_row + 1 }) )
		{
			my ($row, $col) = ($_->row, $_->col);
			debuggit(4 => "reading row", $row, "col", $col);
			$rows{$_->row}->[$_->col] = $_;
		}

		my $data = [];
		foreach my $row (keys %rows)
		{
			my $cellrow = $rows{$row};
			my $key_cell = $cellrow->[$self->key_col];
			next unless $key_cell;
			my $key = $key_cell->content;
			next unless $key;

			$data->[$row] = [ map { defined() ? $_->content : undef } @$cellrow ];
			#$data->[$row]->[0] = $row;
		}

		return $data;
	}

	method _build_keymap ()
	{
		return +{ map { my $r = $self->_data->[$_]; defined $r ? ($r->[$self->key_col] => $_) : () } 0..$#{ $self->_data } };
	}


	has doc			=>	( ro, isa => Str, required );
	has name		=>	( ro, isa => Str, required );
	has key			=>	( ro, isa => Str, required );
	has header_row	=>	( ro, isa => Int, default => 1 );
	has key_col		=>	( ro, isa => Int, lazy, default => method { return $self->_headers->{ $self->key }; } );


	method _row ($rowname)
	{
		debuggit(3 => "trying to access row", $rowname);
		die("no such row as $rowname") unless exists $self->_keymap->{$rowname};
		return $self->_keymap->{$rowname};
	}

	method _col ($colname)
	{
		die("no such col as $colname") unless exists $self->_headers->{$colname};
		return $self->_headers->{$colname};
	}

	method _row_col ($rowname, $colname)
	{
		my $row = $self->_row($rowname);
		my $col = $self->_col($colname);
		return ($row, $col);
	}

	method _build_datarow (Maybe[ArrayRef] $row)
	{
		use Class::PseudoHash;

		return undef unless defined $row;
		return Class::PseudoHash->new( [ @{$self->_columns}[1..$#{$self->_columns}] ], [ @$row[1..$#$row] ] );
	}


	method last_data_row
	{
		return $#{ $self->_data };
	}

	method num_data_rows
	{
		return $self->last_data_row - $self->header_row;
	}


	method get ($rowname, $colname)
	{
		my ($row, $col) = $self->_row_col($rowname, $colname);
		debuggit(2 => "accessing row/col", $row, '/', $col);
		return $self->_data->[$row]->[$col];
	}

	method put ($rowname, $colname, $value)
	{
		my ($row, $col) = $self->_row_col($rowname, $colname);
		$self->_sheet->batchupdate_cell({ row => $row, col => $col, input_value => $value });
		return $self->_data->[$row]->[$col] = $value;
	}


	method get_row ($row_or_rowname)
	{
		my $row = $row_or_rowname =~ /^\d+$/ ? $row_or_rowname : $self->_row($row_or_rowname);
		return $self->_build_datarow($self->_data->[$row]);
	}

	method read_row (Int|Str $rowname)
	{
		my $row = $rowname =~ /^\d+$/ ? $rowname : $self->_row($rowname);
		debuggit(2 => "reading row", $row);
		foreach ( $self->_sheet->cells({ 'row' => $row }) )
		{
			my $col = $_->col;
			$self->_data->[$row]->[$col] = $_->content;
		}
	}

	method update_row (HashRef $hash)
	{
		my $key = $hash->{ $self->key };
		my $row;
		if ($self->has_data)
		{
			try
			{
				$row = $self->_row($key);
			}
			catch ($e where { /no such row as/ })
			{
				$row = $self->last_data_row + 1;
			}
		}
		else
		{
			$row = $self->header_row + 1;
		}
		debuggit(2 => "updating row", $row, "with header_row", $self->header_row, "and num_data_rows", $self->num_data_rows);

		my @cells = map { +{ row => $row, col => $self->_col($_), input_value => $hash->{$_} } } keys %$hash;
		$self->_sheet->batchupdate_cell(@cells);
		$self->read_row($row);
	}


	method foreach_row (CodeRef $doit)
	{
		debuggit(4 => "columns has is", DUMP => $self->_columns);
		foreach my $row ($self->rows)
		{
			next unless $row;
			local $_ = $self->_build_datarow($row);
			$doit->($_);
		}
	}

}



package myperl::Google
{
	use parent 'Exporter';
	our @EXPORT = qw< $GOOGLE >;


	our $GOOGLE = Google::Service->new;
};


1;

=pod

=head1 SYNOPSIS

	use myperl::Google;

	my $doc = $GOOGLE->document({ title => 'My Google Doc' });
	my $sheet = $GOOGLE->spreadsheet({ title => 'My Google Spreadsheet' });

	$GOOGLE->upload_doc($filename, 'My Google Drive Folder');

	my $attendees = { 'My Friend1' => 'friend1@gmail.com', 'My Friend2' => 'friend2@gmail.com', };
	$GOOGLE->add_cal_event(
		title		=>	"My Meeting",
		location	=>	"My Conference Room",
		content		=>	"My description of what my meeting is for.",
		when		=>	"tomorrow 3pm",
		howlong		=>	1,							# in hours
		guests		=>	$attendees,
		reminder	=>	"sms 3h",					# can be alert, email, or sms
	);

	say "Meeting ", $_->title, " at ", $_->when foreach $GOOGLE->cal_events("tomorrow");

	my $url = $GOOGLE->photo_url('My Picasa Photo', album => 'My Picasa Album');

=cut

