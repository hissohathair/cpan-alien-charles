# Alien::Charles
# Interact with the Charles Web Debugging Proxy

package Alien::Charles;

use warnings;
use strict;

use Carp;
use Readonly;
use File::Spec;
use Params::Validate;
use Mozilla::ProfilesIni;

=head1 NAME

Alien::Charles - Interact with the Charles Web Debugging Proxy

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Controlling Firefox's proxy settings so that it goes via a proxy of
your choice:

    use Alien::Charles;

    my $chls = Alien::Charles->new();
    $chls->port( 8888 );
    $chls->start();
    ...
    $chls->stop();

Controlling an LWP::UserAgent so that it goes via your Charles proxy
instance:

    use Alien::Charles;
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    my $chls = Alien::Charles->new();
    if ( $chls->is_charles_running ) {
        $chls->init_from_charles_port;
        $ua->proxy( 'http', $chls->proxy_url );
    }

=head1 DESCRIPTION

From L<http://www.charlesproxy.com/>

    Charles is an HTTP proxy / HTTP monitor / Reverse Proxy that
    enables a developer to view all of the HTTP traffic between their
    machine and the Internet. This includes requests, responses and
    the HTTP headers (which contain the cookies and caching
    information).

Charles is a shareware application developed by Karl von Randow at
XK72 Ltd.

Charles also has a Firefox plug-in available. This Firefox plug-in
allows Charles to automatically take over Firefox's proxy settings
whilst it is running, and restores them when Charles exits (or the
user decides to stop proxying through Charles).

This Perl module uses this feature to allow Perl programs to also
automatically proxy through Charles by mimicing the behaviour of the
Firefox plug-in.


=head1 CONSTRUCTOR

=head2 new

Returns an object. 

TODO: Why? Why not just a procedural interface?

=cut

our $DEFAULT_PORT = '8888';
our $DEFAULT_HOST = 'localhost';

sub new {
    my @args  = @_;
    my $class = shift @args;
    my $self  = {};
    bless $self, $class;

    # Take a hash of init values
    %{$self} = validate(
        @args,
        {
            port            => { default => $DEFAULT_PORT },
            host            => { default => $DEFAULT_HOST },
            firefox_profile => { default => q{-} },
        }
    );

    # Value of '-' means "you tell me" -- so process it twice
    $self->firefox_profile_path( $self->firefox_profile_path() );

    return $self;
}

=head1 SUBROUTINES/METHODS

=head2 port

Get/set the TCP port number that Charles is listening on.

=head2 host

Get/set the hostname.

=cut

# These two routines are very similar and I used to use AUTOLOAD for this but...
# ...it causes traps and problems for the unwary.

sub _set_field {
    my ( $self, $key, $val ) = @_;
    if ( defined $val ) {
        $self->{$key} = $val;
    }
    return $self->{$key};
}

sub port {
    my $self = shift @_;
    return $self->_set_field( 'port', @_ );
}

sub host {
    my $self = shift @_;
    return $self->_set_field( 'host', @_ );
}

=head2 proxy_url

Return URL string that represents Charles' proxy URL.

=cut

sub proxy_url {
    my ($self) = @_;
    return 'http://' . $self->host() . q{:} . $self->port() . q{/};
}

=head2 is_charles_running

Returns true (1) if we B<think> Charles is running, based on the
presence of a file called C<charles_port> in the currently active
Firefox profile.

=cut

sub is_charles_running {
    my ($self) = @_;
    return ( -f $self->charles_port() ? 1 : 0 );
}

=head2 init_from_charles_port 

If Charles is running, then we can find out what port it's listening
on by checking the C<charles_port> file in the Firefox profile
directory. If such a file exists, we parse it and initialise our
objects values.

=cut

sub init_from_charles_port {
    my ($self) = @_;

    my $init_ok = 0;
    if ( $self->is_charles_running ) {
        if ( open my $cf, '<', $self->charles_port ) {
            my $line = <$cf>;
            close $cf
              or carp "close: Error closing charles_port ($!)";

            if ( $line =~ m{(\d+) \s+ -1}xsm ) {
                $self->port($1);
                $init_ok = 1;
            }
            else {
                carp $self->charles_port . ': unable to parse file';
            }
        }
        else {
            carp 'open: Cannot read ' . $self->charles_port . " ($!)";
        }
    }
    return $init_ok;
}

=head2 start

TODO: Don't like this method name. Is it descriptive enough?

Begin a debugging session by taking over Firefox's proxy settings to
point at the port we define (usually, the port that Charles is
listening on).

=cut

Readonly my $CHARLES_MYSTERY_MEAT => -1;

sub start {
    my ($self) = @_;
    if ( -d $self->{firefox_profile} ) {
        if ( open my $cf, '>', $self->charles_port() ) {
            print {$cf} join q{ }, $self->port(), $CHARLES_MYSTERY_MEAT;
            print {$cf} "\n\n";
            close $cf or carp "close: Error closing charles port ($!)";
        }
        else {
            croak 'open: Unable to open ' . $self->charles_port() . " ($!)";
        }
    }
    else {
        croak 'start(): No such directory ' . $self->{firefox_profile};
    }
    return 1;
}

=head2 stop

End the session (restore's Firefox's proxy settings to original).

=cut

sub stop {
    my ($self) = @_;
    if ( -f $self->charles_port() ) {
        if ( !unlink $self->charles_port() ) {
            carp 'unlink: Unable to remove ' . $self->charles_port() . " ($!)";
        }
    }
    else {
        carp 'stop(): Could not find '
          . $self->charles_port()
          . '. Did you start()?';
    }
    return 1;
}

=head2 firefox_profile_path

Get/set the path to the Firefox profile currently in use.

=cut

sub firefox_profile_path {
    my ( $self, $path ) = @_;

    if ( defined $path && $path eq q{-} ) {
        $self->{firefox_profile} = $self->_get_firefox_profile_path();
    }
    elsif ( defined $path ) {
        $self->{firefox_profile} = $path;
    }
    return $self->{firefox_profile};
}

sub _get_firefox_profile_path {
    my ($self) = @_;

   # This is suggested in the Synopsis for Mozilla::ProfilesIni but Perl::Critic
   # is not impressed.
   #
    my $path = Mozilla::ProfilesIni::_find_profile_path(
        home => $ENV{HOME},
        type => 'firefox',
    );
    my $ini = Mozilla::ProfilesIni->new( path => $path );

    my $cfg = Config::IniFiles->new( -file => $ini->ini_file() );
    my $last_profile = $cfg->val( 'General', 'StartWithLastProfile', 0 );
    my $profile_name = $cfg->val( "Profile$last_profile", 'Name', 'default' );

    my $firefox_profile = $ini->profile_path($profile_name);

    #warn $ini->ini_file();

    return $firefox_profile;
}

=head2 charles_port

Return full path to the Charles "port" file.

=cut

sub charles_port {
    my ($self) = @_;
    return File::Spec->catfile( $self->{firefox_profile}, 'charles_port' );
}

=head2 DESTROY

If the object goes out of scope it should clean-up after itself.

=cut

sub DESTROY {
    my ($self) = @_;
    if ( -f $self->charles_port() ) {
        $self->stop();
    }
    return;
}

=head1 DIAGNOSTICS

None given.

=head1 CONFIGURATION AND ENVIRONMENT

TBA

=head1 DEPENDENCIES

File::Spec

Params::Validate

Mozilla::ProfilesIni

=head1 INCOMPATIBILITIES

None noted.

=head1 BUGS AND LIMITATIONS

None noted. Yet.

I suspect the method of determining which Firefox profile is "active"
is idiosyncratic and not robust.

Charles can also take over MSIE's proxy settings but this is not
emulated in this module.

It would be useful to support Safari, Chrome, Konquerer and other
browsers as well I imagine.

Please report any bugs or feature requests to C<bug-alien-charles at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Alien-Charles>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 AUTHOR

Daniel Austin, C<< <hisso at cpan.org> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Alien::Charles


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Alien-Charles>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Alien-Charles>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Alien-Charles>

=item * Search CPAN

L<http://search.cpan.org/dist/Alien-Charles/>

=back


=head1 ACKNOWLEDGEMENTS

Obviously, props to Karl von Randow at XK72 Ltd for a great
developer's tool.

=head1 LICENSE AND COPYRIGHT

Copyright 2009 Daniel Austin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Alien::Charles
