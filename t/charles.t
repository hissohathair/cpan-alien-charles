#!perl -w
# $Id$
#

use Test::More tests => 20;
use constant TEST_PORT => 12345;

BEGIN {
    use_ok( 'Alien::Charles' );
}

# Constructor tests
my $chls = Alien::Charles->new();
isa_ok( $chls, 'Alien::Charles' );


# Method tests

# port()
ok( $chls->port() == $Alien::Charles::DEFAULT_PORT, 'Default port should be 8888' );
ok( $chls->port( TEST_PORT ) == TEST_PORT,          'port() should return new value'  );
ok( $chls->port() == TEST_PORT,                     'port() should return old value' );

# proxy_url
my $url = $chls->proxy_url();
ok( $url eq 'http://localhost:' . TEST_PORT . '/', 'proxy() should be valid URL' );
SKIP: {
    eval { require Test::URI };
    skip 'Test::URI not installed', 3 if $@;

    Test::URI::uri_scheme_ok( $url, 'http' );
    Test::URI::uri_host_ok(   $url, 'localhost' );
    Test::URI::uri_port_ok(   $url, TEST_PORT );
}

# firefox_profile_path()
my $orig_path = $chls->firefox_profile_path();
ok( -d $chls->firefox_profile_path(), 'firefox_profile_path() should be a directory' )
    or diag("Firefox profile path: $orig_path");
is( $chls->firefox_profile_path( '.' ), '.',      'firefox_profile_path() should get set' );
ok( -d $chls->firefox_profile_path(),             'firefox_profile_path() should work on cwd' );
is( $chls->firefox_profile_path('-'), $orig_path, 'firefox_profile_path() should re-init' );

# start()
ok( $chls->start(),           'start() should work' );
ok( -f $chls->charles_port(), 'charles_port() should exist after start()' );

SKIP: {
    eval { require Test::File::Contents };
    skip 'Test::File::Contents not installed', 1 if $@;

    Test::File::Contents::file_contents_is( $chls->charles_port(), 
					    join(' ', TEST_PORT, -1) . "\n\n",
					    'file should be correct format', );

}


# stop()
ok( $chls->stop(),              'stop() should work' );
ok( ! -f $chls->charles_port(), 'charles_port() should NOT exist after stop()' );


# destroy()
ok( $chls->start() && -f $chls->charles_port(), 'start() should be able to start after a stop()' );
my $file = $chls->charles_port();
undef $chls;
ok( ! -f $file, 'charles_port() should NOT exist after object goes out of scope' );
