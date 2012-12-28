use Test::Most 0.25;


require_ok( '{{ $dist->name =~ s/-/::/gr }}' );


done_testing;
