#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Alien::Charles' );
}

diag( "Testing Alien::Charles $Alien::Charles::VERSION, Perl $], $^X" );
