use myperl;

use Test::Most 0.25;

# myperl::Gmail's deps now live in the optional myperl-gmail feature; skip cleanly
# if they aren't installed (mirrors how load.t guarded myperl::Google).
BEGIN
{
	eval { require URI; require LWP::UserAgent; require LWP::Protocol::https; 1 }
		or plan skip_all => 'myperl-gmail feature not installed (needs URI + LWP::UserAgent + LWP::Protocol::https)';
}

use myperl::Gmail;
use URI;


# auth_url builds the one-time Google consent URL for the authorization-code flow.
# It must request offline access with forced consent, or Google won't return a
# refresh token (which is the whole point of the one-time grant).

my $gmail = myperl::Gmail->new(
	client_id		=>	'CID.apps.googleusercontent.com',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
);

my $uri = URI->new( $gmail->auth_url );
is $uri->scheme . '://' . $uri->host . $uri->path, 'https://accounts.google.com/o/oauth2/v2/auth',
		'auth_url targets the Google consent endpoint';

my %q = $uri->query_form;
is $q{client_id},		'CID.apps.googleusercontent.com',	'auth_url carries the client id';
is $q{redirect_uri},	'http://localhost:8080/callback',	'auth_url carries the redirect uri';
is $q{response_type},	'code',								'auth_url requests an authorization code';
is $q{access_type},		'offline',							'auth_url requests offline access (for a refresh token)';
is $q{prompt},			'consent',							'auth_url forces consent (guarantees a refresh token)';
is $q{scope},			'https://www.googleapis.com/auth/gmail.readonly',
		'auth_url requests the read-only Gmail scope';


# access_token: the unattended runtime path.  A stored refresh token is exchanged
# at Google's token endpoint for a fresh, short-lived access token -- no browser.
# We inject a fake user-agent so the test never touches the network.

{
	package Test::FakeUA;
	# Queue of canned responses, handed out in call order; records each call for inspection.
	sub new   { my ($class, @res) = @_; bless { res => [ @res ], calls => [] }, $class }
	sub post  { my ($self, $url, $form) = @_; push @{$self->{calls}}, [ $url, $form ];    return shift @{$self->{res}} }
	sub get   { my ($self, $url, @hdr)  = @_; push @{$self->{calls}}, [ $url, { @hdr } ]; return shift @{$self->{res}} }
	sub calls { @{$_[0]->{calls}} }
}

use HTTP::Response;
use JSON::PP qw< encode_json >;

my $fake = Test::FakeUA->new( HTTP::Response->new(200, 'OK', undef,
		encode_json({ access_token => 'ACCESS123', expires_in => 3599, token_type => 'Bearer' })) );

my $authed = myperl::Gmail->new(
	client_id		=>	'CID',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
	refresh_token	=>	'RT',
	ua				=>	$fake,
);

is $authed->access_token, 'ACCESS123', 'access_token returns the freshly minted token';

my ($call) = $fake->calls;
is $call->[0], 'https://oauth2.googleapis.com/token', 'refresh posts to the Google token endpoint';
is $call->[1]{grant_type},		'refresh_token',	'refresh uses the refresh_token grant';
is $call->[1]{refresh_token},	'RT',				'refresh sends the stored refresh token';
is $call->[1]{client_id},		'CID',				'refresh sends the client id';
is $call->[1]{client_secret},	'SECRET',			'refresh sends the client secret';


# exchange_code: the one-time grant's final step.  Trade the authorization code
# Google handed back (via the loopback redirect) for the initial token pair --
# the refresh_token here is the durable credential we persist.

my $exch_ua = Test::FakeUA->new( HTTP::Response->new(200, 'OK', undef,
		encode_json({ access_token => 'AT', refresh_token => 'NEWRT', expires_in => 3599 })) );

my $granting = myperl::Gmail->new(
	client_id		=>	'CID',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
	ua				=>	$exch_ua,
);

my $tokens = $granting->exchange_code('AUTHCODE');
is $tokens->{refresh_token},	'NEWRT',	'exchange_code returns the durable refresh token';
is $tokens->{access_token},		'AT',		'exchange_code returns the initial access token';

my ($echo) = $exch_ua->calls;
is $echo->[0], 'https://oauth2.googleapis.com/token',	'code exchange posts to the token endpoint';
is $echo->[1]{grant_type},		'authorization_code',	'code exchange uses the authorization_code grant';
is $echo->[1]{code},			'AUTHCODE',				'code exchange sends the authorization code';
is $echo->[1]{redirect_uri},	'http://localhost:8080/callback',	'code exchange sends the redirect uri';


# search: users.messages.list with a Gmail query.  Transparently refreshes the
# access token first, then makes an authorized GET, returning the message stubs.

my $search_ua = Test::FakeUA->new(
	HTTP::Response->new(200, 'OK', undef, encode_json({ access_token => 'AT', expires_in => 3599 })),
	HTTP::Response->new(200, 'OK', undef, encode_json({ messages => [ { id => 'm1', threadId => 't1' },
																	   { id => 'm2', threadId => 't2' } ] })),
);

my $reader = myperl::Gmail->new(
	client_id		=>	'CID',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
	refresh_token	=>	'RT',
	ua				=>	$search_ua,
);

my @msgs = $reader->search('from:foo newer_than:7d');
is scalar(@msgs),	2,		'search returns the matching message stubs';
is $msgs[0]{id},	'm1',	'search yields message ids';

my @rcalls = $search_ua->calls;
is $rcalls[0][0], 'https://oauth2.googleapis.com/token', 'search refreshes the access token first';
like $rcalls[1][0], qr{^https://gmail\.googleapis\.com/gmail/v1/users/me/messages\b},
		'search calls users.messages.list';
my %lq = URI->new( $rcalls[1][0] )->query_form;
is $lq{q}, 'from:foo newer_than:7d',	'search passes the Gmail query through';
is $rcalls[1][1]{Authorization}, 'Bearer AT', 'search authorizes with the bearer token';


# labels: users.labels.list -> the account's labels (system + user).

my $labels_ua = Test::FakeUA->new(
	HTTP::Response->new(200, 'OK', undef, encode_json({ access_token => 'AT', expires_in => 3599 })),
	HTTP::Response->new(200, 'OK', undef, encode_json({ labels => [ { id => 'INBOX',   name => 'INBOX',    type => 'system' },
																	 { id => 'Label_1', name => 'Receipts', type => 'user'   } ] })),
);

my $labeller = myperl::Gmail->new(
	client_id		=>	'CID',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
	refresh_token	=>	'RT',
	ua				=>	$labels_ua,
);

my @labels = $labeller->labels;
is scalar(@labels),		2,			'labels returns every label';
is $labels[1]{name},	'Receipts',	'labels yields label names';

my @labelcalls = $labels_ua->calls;
like $labelcalls[1][0], qr{^https://gmail\.googleapis\.com/gmail/v1/users/me/labels\b},
		'labels calls users.labels.list';


# get: users.messages.get?format=full -> a tidy message (key headers + decoded body).
# Real Gmail payloads are multipart with base64url-encoded parts; we want the
# text/plain body, decoded, plus the headers an agent actually cares about.

use MIME::Base64 qw< encode_base64url >;

my $body_text = "Hello there,\n\nYour receipt is attached.\n";
my $msg_json = encode_json({
	id => 'm1', threadId => 't1', snippet => 'Hello there, Your receipt...',
	payload => {
		mimeType	=>	'multipart/alternative',
		headers		=>	[
			{ name => 'Subject', value => 'Your receipt' },
			{ name => 'From',    value => 'Store <store@example.com>' },
			{ name => 'To',      value => 'barefootcoder@gmail.com' },
			{ name => 'Date',    value => 'Mon, 02 Jun 2026 10:00:00 -0700' },
		],
		parts		=>	[
			{ mimeType => 'text/plain', body => { data => encode_base64url($body_text) } },
			{ mimeType => 'text/html',  body => { data => encode_base64url('<p>Hello</p>') } },
		],
	},
});

my $get_ua = Test::FakeUA->new(
	HTTP::Response->new(200, 'OK', undef, encode_json({ access_token => 'AT', expires_in => 3599 })),
	HTTP::Response->new(200, 'OK', undef, $msg_json),
);

my $fetcher = myperl::Gmail->new(
	client_id		=>	'CID',
	client_secret	=>	'SECRET',
	redirect_uri	=>	'http://localhost:8080/callback',
	refresh_token	=>	'RT',
	ua				=>	$get_ua,
);

my $msg = $fetcher->get('m1');
is $msg->{subject},	'Your receipt',					'get extracts the subject';
is $msg->{from},	'Store <store@example.com>',	'get extracts the sender';
is $msg->{to},		'barefootcoder@gmail.com',		'get extracts the recipient';
is $msg->{date},	'Mon, 02 Jun 2026 10:00:00 -0700',	'get extracts the date';
is $msg->{snippet},	'Hello there, Your receipt...',	'get includes the snippet';
is $msg->{body},	$body_text,						'get decodes the text/plain body';

my @getcalls = $get_ua->calls;
like $getcalls[1][0], qr{^https://gmail\.googleapis\.com/gmail/v1/users/me/messages/m1\b},
		'get fetches the specific message';
my %gq = URI->new( $getcalls[1][0] )->query_form;
is $gq{format}, 'full', 'get requests the full message payload';


# When no ua is injected (real runtime), the client builds its own LWP::UserAgent,
# so the CLI needs no HTTP wiring of its own.

my $default_ua = myperl::Gmail->new(
		client_id => 'CID', client_secret => 'SECRET', redirect_uri => 'http://localhost:8080/callback',
	)->ua;
isa_ok $default_ua, 'LWP::UserAgent', 'default user-agent';


# from_creds_file: build a runtime-ready client from the persisted JSON creds
# (exactly what gmail-personal-auth writes).  No redirect_uri needed at runtime.

use File::Temp ();

my $credfile = File::Temp->new;
print {$credfile} encode_json({ client_id => 'CID2', client_secret => 'SECRET2', refresh_token => 'RT2' });
$credfile->close;

my $loaded = myperl::Gmail->from_creds_file("$credfile");
is $loaded->client_id,		'CID2',		'from_creds_file loads the client id';
is $loaded->client_secret,	'SECRET2',	'from_creds_file loads the client secret';
is $loaded->refresh_token,	'RT2',		'from_creds_file loads the refresh token';

done_testing;
