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
	use Net::Google::Calendar;
	use Net::Google::PicasaWeb;
	use Net::Google::Spreadsheets;
	use Net::Google::DocumentsList;


	has _config		=>	( ro, isa => 'HashRef', lazy, builder => '_read_config' );
	has _ssheets	=>	( ro, isa => 'Net::Google::Spreadsheets', lazy, builder => '_connect_to_spreadsheets',
								handles => [ qw< spreadsheet > ] );
	has _doclist	=>	( ro, isa => 'Net::Google::DocumentsList', lazy, builder => '_connect_to_documents',
								handles => { document => 'item' } );
	has _calendar	=>	( ro, isa => 'Net::Google::Calendar', lazy, builder => '_connect_to_calendar' );
	has _picasa		=>	( ro, isa => 'Net::Google::PicasaWeb', lazy, builder => '_connect_to_picasa',
								handles => { photo_albums => 'list_albums' } );

	method _read_config
	{
		use Config::General qw< ParseConfig >;

		return { ParseConfig("$ENV{HOME}/.googlerc") };
	}

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
		my $user = $self->_config->{'username'} || $self->_config->{'user'};
		my $passwd = $self->_config->{'password'};

		return ($user, $passwd) if $type eq 'list';
		return (username => $user, password => $passwd) if $type eq 'hash';
		die("unknown type to _login_params: $type");
	}


	method upload_doc ($file, $folder?)
	{
		use File::Basename;

		my $name = basename($file);
		my $source;
		if ($folder)
		{
			$source = $self->_doclist->folder({ title => $folder });;
		}
		else
		{
			$source = $self->_doclist;
		}

		return $source->add_item({ title => $name, file => $file });
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
		my $event = Net::Google::Calendar::Entry->new;

		# fixup the when and howlong bits
		if ($params{'when'})
		{
			my $from = Calendar::Event->_parse_datetime(delete $params{'when'});
			my $duration = delete $params{'howlong'};
			my $allday = !$duration;
			my $until = $from + DateTime::Duration->new( hours => $duration );
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

		# what we have left should just map directly to mutators
		foreach (keys %params)
		{
			my $method = $event->can($_);
			$event->$method($params{$_});
		}

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



package myperl::Google;

use parent 'Exporter';
our @EXPORT = qw< $GOOGLE >;


our $GOOGLE = Google::Service->new;


1;
