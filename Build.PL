use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Alien::Charles',
    license             => 'perl',
    dist_author         => 'Daniel Austin <hisso@cpan.org>',
    dist_version_from   => 'lib/Alien/Charles.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Alien-Charles-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
