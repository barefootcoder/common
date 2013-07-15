use myperl;

use Test::Most 0.25;


# dates in
is exists $INC{'Date/Parse.pm'}, '', "haven't loaded Date::Parse yet";
is str2time("1/1/2010 3pm UTC"), 1262358000, "can convert strings to dates";
is exists $INC{'Date/Parse.pm'}, 1, "loaded Date::Parse now";

# dates in
is exists $INC{'Date/Format.pm'}, '', "haven't loaded Date::Format yet";
is time2str("%L/%e/%Y %l%P %Z", 1262358000, 'UTC'), "1/ 1/2010  3pm UTC", "can convert strings to dates";
is exists $INC{'Date/Format.pm'}, 1, "loaded Date::Format now";


done_testing;
