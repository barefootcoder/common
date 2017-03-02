use myperl;

use Test::Most 0.25;


# dates in
is exists $INC{'Date/Parse.pm'}, '', "haven't loaded Date::Parse yet";
is str2time("1/1/2010 3pm UTC"), 1262358000, "can convert strings to dates";
is exists $INC{'Date/Parse.pm'}, 1, "loaded Date::Parse now";

# dates out
is exists $INC{'Date/Format.pm'}, '', "haven't loaded Date::Format yet";
is time2str("%L/%e/%Y %l%P %Z", 1262358000, 'UTC'), "1/ 1/2010  3pm UTC", "can convert strings to dates";
is exists $INC{'Date/Format.pm'}, 1, "loaded Date::Format now";


# dates easy
my $d;
lives_ok { $d = date("1/17/2015")->as("/Ymd") } "can call date()";
is $d, "2015/01/17", "date() gives good results";
lives_ok { $d = (datetime("noon") + 30*60 + 23)->as(":HMS") } "can call datetime()";
is $d, "12:30:23", "datetime() gives good results";


done_testing;
