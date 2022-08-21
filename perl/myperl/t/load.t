use Test::Most;


use_ok("myperl");
use_ok("myperl::Declare");
use_ok("myperl::Script");
use_ok("myperl::Template");

SKIP: { skip "myperl::Google currently broken", 1;
	use_ok("myperl::Google")		if eval { require Net::Google::Calendar };
};


done_testing;
