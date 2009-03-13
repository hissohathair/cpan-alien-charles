#!perl -T
# $Id$
#

use Test::More tests => 3;

BEGIN {
    use_ok( 'Alien::Charles' );
}

ok( Alien::Charles::function1() );
ok( Alien::Charles::function2() );

