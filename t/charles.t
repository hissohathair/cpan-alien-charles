#!perl -w
# charles.t - Test Alien::Charles
#

use Test::More tests   => 31;
use constant TEST_PORT => 12345;

BEGIN {
    use_ok('Alien::Charles');
}

# Constructor tests
my $chls = Alien::Charles->new();
isa_ok( $chls, 'Alien::Charles' );

# Method tests

# port()
is( $chls->port(), $Alien::Charles::DEFAULT_PORT,
    'Default port should be 8888' );
is( $chls->port(TEST_PORT), TEST_PORT, 'port() should return new value' );
is( $chls->port(),          TEST_PORT, 'port() should return old value' );

# proxy_url
my $url = $chls->proxy_url();
is( $url, 'http://localhost:' . TEST_PORT . '/',
    'proxy() should be valid URL' );
SKIP: {
    eval { require URI };
    skip 'URI not installed', 4 if $@;

    my $uri = URI->new($url);
    is( $uri->scheme, 'http',          'scheme should be http' );
    is( $uri->host,   'localhost',     'host should be localhost' );
    is( $uri->port,   TEST_PORT,       'port should be TEST_PORT' );
    is( $url,         $uri->canonical, 'url should be canonical' );
}

# firefox_profile_path()
my $orig_path = $chls->firefox_profile_path();
ok( -d $chls->firefox_profile_path(),             'firefox_profile_path() should be a directory' )
    or diag("Firefox profile path: $orig_path");
is( $chls->firefox_profile_path('.'),   '.',      'firefox_profile_path() should get set' );
ok( -d $chls->firefox_profile_path(),             'firefox_profile_path() should work on cwd' );
is( $chls->firefox_profile_path('-'), $orig_path, 'firefox_profile_path() should re-init' );

# is_charles_running()
my $charles_running = $chls->is_charles_running();
ok( ( 1 == $charles_running ) || ( 0 == $charles_running ),
    'is_charles_running() is either 1 or 0' );
pass(   'Just so you know, Charles is '
      . ( $charles_running ? '' : 'not ' )
      . 'running' );

# start()
ok( $chls->start(), 'start() should work' );
ok( $chls->is_charles_running(),
    'charles should appear to be running after start()' );
ok( -f $chls->charles_port(), 'charles_port() should exist after start()' );

SKIP: {
    eval { require Test::File::Contents };
    skip 'Test::File::Contents not installed', 1 if $@;

    Test::File::Contents::file_contents_is(
        $chls->charles_port(),
        join( ' ', TEST_PORT, -1 ) . "\n\n",
        'file should be correct format',
    );
}

is( $chls->port(0), 0, 'can change port after start' );
ok( $chls->init_from_charles_port,
    'should be able to re-init from port after start()' );
is( $chls->port, TEST_PORT, 're-init restores port' );

# stop()
ok( $chls->stop(), 'stop() should work' );
ok( !$chls->is_charles_running(),
    'Charles should appear to be NOT running after stop()' );
ok( !-f $chls->charles_port(), 'charles_port() should NOT exist after stop()' );
ok( ! $chls->init_from_charles_port, 'should not be able to re-init after stop()' );

# destroy()
ok( $chls->start(),           'start() should be able to start after a stop()' );
ok( -f $chls->charles_port(), 'start() should re-create the charles_port file' );

my $file = $chls->charles_port();
undef $chls;
ok( !-f $file,
    'charles_port() should NOT exist after object goes out of scope' );

$chls = Alien::Charles->new();
isa_ok( $chls, 'Alien::Charles' );
