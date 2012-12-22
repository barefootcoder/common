use myperl;

use Test::Most 0.25;


# simple non-changes
is round(1), 1, 'base rounding to itself works';
is round(3.25, .25), 3.25, 'nearest rounding to itself works';

# simple changes; OFF as default
is round(1.1), 1, 'base rounding low works';
is round(1.5), 2, 'base rounding mid works';
is round(1.9), 2, 'base rounding high works';
is round(3.27, .25), 3.25, 'nearest rounding low works';
is round(3.375, .25), 3.5, 'nearest rounding mid works';
is round(3.48, .25), 3.5, 'nearest rounding high works';

# simple changes; OFF explicit
is round(OFF => 1.1), 1, 'base rounding OFF low works';
is round(OFF => 1.5), 2, 'base rounding OFF mid works';
is round(OFF => 1.9), 2, 'base rounding OFF high works';
is round(OFF => 3.27, .25), 3.25, 'nearest rounding OFF low works';
is round(OFF => 3.375, .25), 3.5, 'nearest rounding OFF mid works';
is round(OFF => 3.48, .25), 3.5, 'nearest rounding OFF high works';

# rounding UP
is round(UP => 1), 1, 'base rounding UP even works';
is round(UP => 1.1), 2, 'base rounding UP low works';
is round(UP => 1.5), 2, 'base rounding UP mid works';
is round(UP => 1.9), 2, 'base rounding UP high works';
is round(UP => 3.25, .25), 3.25, 'nearest rounding UP even works';
is round(UP => 3.27, .25), 3.5, 'nearest rounding UP low works';
is round(UP => 3.375, .25), 3.5, 'nearest rounding UP mid works';
is round(UP => 3.48, .25), 3.5, 'nearest rounding UP high works';

# rounding DOWN
is round(DOWN => 1), 1, 'base rounding DOWN even works';
is round(DOWN => 1.1), 1, 'base rounding DOWN low works';
is round(DOWN => 1.5), 1, 'base rounding DOWN mid works';
is round(DOWN => 1.9), 1, 'base rounding DOWN high works';
is round(DOWN => 3.25, .25), 3.25, 'nearest rounding DOWN even works';
is round(DOWN => 3.27, .25), 3.25, 'nearest rounding DOWN low works';
is round(DOWN => 3.375, .25), 3.25, 'nearest rounding DOWN mid works';
is round(DOWN => 3.48, .25), 3.25, 'nearest rounding DOWN high works';


done_testing;
