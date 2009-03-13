package Alien::Charles;

use warnings;
use strict;

use Carp;
use File::Spec;
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
    $ua->proxy( 'http', $chls->proxy_url() );

=head1 CONSTRUCTOR

=head2 new

Returns an object. 

TODO: Why? Why not just a procedural interface?

=cut

our $DEFAULT_PORT = 8888;

sub new
{
    my( $class ) = @_;
    my $self = { };
    bless $self, $class;
    $self->{port} = 8888;
    $self->{firefox_profile} = $self->_get_firefox_profile_path();
    return $self;
}

=head1 METHODS

=head2 port

Get/set the TCP port number that Charles is listening on.

=cut

sub port
{
    my( $self, $port ) = @_;
    if ( defined $port ) {
	$self->{port} = $port;
    }
    return $self->{port};
}


=head2 proxy_url

Return URL string that represents Charles' proxy URL.

=cut

sub proxy_url
{
    my( $self ) = @_;
    return 'http://localhost:' . $self->port() . '/';
}


=head2 start

TODO: Don't like this method name. Is it descriptive enough?

Begin a debugging session by taking over Firefox's proxy settings to
point at the port we define (usually, the port that Charles is
listening on).

=cut

sub start
{
    my( $self ) = @_;
    if ( -d $self->{firefox_profile} ) {
	if ( open my $cf, '>', $self->charles_port() ) {
	    print $cf join(' ', $self->port(), -1);
	    print $cf "\n\n";
	    close $cf;
	} 
	else {
	    croak "open: Unable to open " . $self->charles_port() . " ($!)";
	}
    }
    else {
	croak "start(): No such directory " . $self->{firefox_profile};
    }
    return 1;
}


=head2 stop

End the session (restore's Firefox's proxy settings to original).

=cut

sub stop
{
    my( $self ) = @_;
    if ( -f $self->charles_port() ) {
	if ( ! unlink $self->charles_port() ) {
	    carp "unlink: Unable to remove " . $self->charles_port() . " ($!)";
	}
    } 
    else {
	carp "stop(): Could not find " . $self->charles_port() . ". Did you start()?";
    }
    return 1;
}

=head2 firefox_profile_path

Get/set the path to the Firefox profile currently in use.

=cut

sub firefox_profile_path
{
    my( $self, $path ) = @_;

    if ( defined $path && $path eq '-' ) {
	$self->{firefox_profile} = $self->_get_firefox_profile_path();
    }
    elsif ( defined $path ) {
	$self->{firefox_profile} = $path;
    }
    return $self->{firefox_profile};
}

sub _get_firefox_profile_path
{
    my( $self ) = @_;


    # '/Users/dan/Library/Application Support/Firefox/Profiles/v0wnq6rx.MozillaDebug';
    #
    my $path = Mozilla::ProfilesIni::_find_profile_path(
	home => $ENV{HOME},
	type => 'firefox',
	); 
    my $ini = Mozilla::ProfilesIni->new( path => $path );

    my $cfg = Config::IniFiles->new( -file => $ini->ini_file() );
    my $last_profile = $cfg->val('General', 'StartWithLastProfile', 0);
    my $profile_name = $cfg->val("Profile$last_profile", 'Name', 'default');
    
    my $firefox_profile = $ini->profile_path( $profile_name );
    #warn $ini->ini_file();
    
    return $firefox_profile;
}

=head2 charles_port

Return full path to the Charles "port" file.

=cut

sub charles_port
{
    my( $self ) = @_;
    return File::Spec->catfile($self->{firefox_profile}, 'charles_port');
}


=head1 DESTRUCTOR

=head2 DESTROY

If the object goes out of scope it should clean-up after itself.

=cut

sub DESTROY
{
    my( $self ) = @_;
    if ( -f $self->charles_port() ) {
	$self->stop();
    }
}

=head1 AUTHOR

Daniel Austin, C<< <hisso at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-alien-charles at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Alien-Charles>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




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


=head1 COPYRIGHT & LICENSE

Copyright 2009 Daniel Austin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Alien::Charles
