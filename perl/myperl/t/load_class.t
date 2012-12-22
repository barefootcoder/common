use myperl;

use Test::Most 0.25;

use File::Basename;
use lib dirname($0);


lives_ok { class Foo { load_class('Test::myperl'); } } 'load_class exported';
throws_ok { class Foo { try_load_class('Test::myperl'); } } qr/undefined subroutine/i, 'only load_class exported';


done_testing;
