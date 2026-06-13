use myperl;


class myperl::Gmail
{
	has client_id		=>	( ro, isa => Str, required );
	has client_secret	=>	( ro, isa => Str, required );
	has redirect_uri	=>	( ro, isa => Str, predicate => 'has_redirect_uri' );	# only the auth flow needs it
	has scope			=>	( ro, isa => Str, default => 'https://www.googleapis.com/auth/gmail.readonly' );

	# Both optional: auth_url needs neither.  refresh_token is set after the
	# one-time grant; ua is injected (the CLI builds the LWP::UserAgent and
	# passes it in, which also makes this class trivially testable).
	has refresh_token	=>	( ro, isa => Str, predicate => 'has_refresh_token' );
	has ua				=>	( ro, lazy, builder => '_build_ua', predicate => 'has_ua' );

	method _build_ua
	{
		use LWP::UserAgent ();
		return LWP::UserAgent->new( timeout => 30 );
	}


	# Build a runtime-ready client (refresh + reads) from the persisted JSON creds
	# file that gmail-personal-auth writes.
	method from_creds_file ($class: $path)
	{
		use JSON::PP ();

		open my $fh, '<', $path;
		my $json = do { local $/; <$fh> };
		close $fh;

		my $creds = JSON::PP::decode_json($json);
		return $class->new(
			client_id		=>	$creds->{client_id},
			client_secret	=>	$creds->{client_secret},
			refresh_token	=>	$creds->{refresh_token},
		);
	}


	# The one-time consent URL for the authorization-code flow.  access_type=offline
	# plus prompt=consent are what make Google return a refresh token (not just a
	# short-lived access token), which is what the whole one-time grant is for.
	method auth_url
	{
		use URI;

		my $uri = URI->new('https://accounts.google.com/o/oauth2/v2/auth');
		$uri->query_form(
			client_id		=>	$self->client_id,
			redirect_uri	=>	$self->redirect_uri,
			response_type	=>	'code',
			access_type		=>	'offline',
			prompt			=>	'consent',
			scope			=>	$self->scope,
		);
		return $uri->as_string;
	}


	# All token-endpoint calls (refresh and code-exchange) share this POST+decode.
	method _token_request ($form)
	{
		use JSON::PP ();

		my $res = $self->ua->post('https://oauth2.googleapis.com/token', $form);
		return JSON::PP::decode_json( $res->decoded_content );
	}


	# Exchange the stored refresh token for a fresh, short-lived access token.
	# This is the unattended runtime path -- no browser, no user.
	method access_token
	{
		return $self->_token_request({
			grant_type		=>	'refresh_token',
			refresh_token	=>	$self->refresh_token,
			client_id		=>	$self->client_id,
			client_secret	=>	$self->client_secret,
		})->{access_token};
	}


	# The one-time grant's final step: trade the authorization code (caught via the
	# loopback redirect) for the initial token pair.  The refresh_token in the result
	# is the durable credential we persist to the creds file.
	method exchange_code ($code)
	{
		return $self->_token_request({
			grant_type		=>	'authorization_code',
			code			=>	$code,
			redirect_uri	=>	$self->redirect_uri,
			client_id		=>	$self->client_id,
			client_secret	=>	$self->client_secret,
		});
	}


	# An authorized GET against the Gmail REST API.  Transparently refreshes the
	# access token, then attaches it as a bearer.  $path is relative to the v1 user root.
	method _api_get ($path, %params)
	{
		use JSON::PP ();
		use URI ();

		my $uri = URI->new("https://gmail.googleapis.com/gmail/v1/users/me/$path");
		$uri->query_form(%params) if %params;
		my $res = $self->ua->get( $uri->as_string, Authorization => 'Bearer ' . $self->access_token );
		return JSON::PP::decode_json( $res->decoded_content );
	}


	# Search messages by Gmail query syntax (from:, newer_than:, subject:, ...).
	# Returns the lightweight message stubs ({ id, threadId }); fetch bodies with get().
	method search ($query)
	{
		my $data = $self->_api_get('messages', q => $query);
		return @{ $data->{messages} || [] };
	}


	# The account's labels, system and user-defined ({ id, name, type, ... }).
	method labels
	{
		my $data = $self->_api_get('labels');
		return @{ $data->{labels} || [] };
	}


	# Fetch one message and distill it to what an agent actually wants: the key
	# headers plus the decoded text/plain body.
	method get ($id)
	{
		my $msg = $self->_api_get("messages/$id", format => 'full');
		my $payload = $msg->{payload} || {};
		my %hdr = map { lc($_->{name}) => $_->{value} } @{ $payload->{headers} || [] };

		return {
			id			=>	$msg->{id},
			threadId	=>	$msg->{threadId},
			subject		=>	$hdr{subject},
			from		=>	$hdr{from},
			to			=>	$hdr{to},
			date		=>	$hdr{date},
			snippet		=>	$msg->{snippet},
			body		=>	$self->_extract_body($payload),
		};
	}

	# Pull the text/plain body out of a payload: either the direct body (simple
	# messages) or the first text/plain part (multipart).  Gmail base64url-encodes it.
	method _extract_body ($payload)
	{
		use MIME::Base64 ();

		return MIME::Base64::decode_base64url($payload->{body}{data})
				if $payload->{body} && $payload->{body}{data};

		foreach my $part (@{ $payload->{parts} || [] })
		{
			return MIME::Base64::decode_base64url($part->{body}{data})
					if ($part->{mimeType} // '') eq 'text/plain' && $part->{body}{data};
		}
		return undef;
	}
}


1;
