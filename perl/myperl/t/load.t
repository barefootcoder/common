use Test::Most;


use_ok("myperl");
use_ok("myperl::Declare");
use_ok("myperl::Script");
use_ok("myperl::Google")		if use_ok("Net::Google::Calendar");
use_ok("myperl::Template");


done_testing;
