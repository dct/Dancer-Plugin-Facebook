package Dancer::Plugin::Facebook;
# ABSTRACT: Manage Facebook interaction within Dancer applications

use Dancer qw{:syntax};
use Dancer::Hook;
use Dancer::Plugin;
use Facebook::Graph;
use Try::Tiny;

=head1 SYNOPSIS

  use Dancer;
  use Dancer::Plugin::Facebook;

  setup_fb;

  get '/' => sub {
    fb->fetch ('16665510298')->{name};
  } # returns 'perl'

=head1 DESCRIPTION

Dancer::Plugin::Facebook is intended to simplify using Facebook::Graph
from within a Dancer application.

It will:

=over

=item manage the lifecycle of the Facebook::Graph object

The Plugin goes to great lengths to only create the Facebook::Graph
object when needed, and tries hard to cache it as long as it applies.
So you can use the fb object repeatedly during a request, even in
different handlers, and be sure that it's not being rebuilt
needlessly.

=item store your applications registration information in a single place

Though it's not required that you have an registered app, if you do,
you need only record the app_id and secret in one place.

=item automatically create routes for handling authentication

If you pass an path to the setup_fb routine, the plugin will create
the routes necessary to support authentication in that location.

=item automatically manage user authentication tokens

It will transparently manage them through the user session for you,
collecting them when the user authenticates, and making sure that they
are used when creating the Facebook::Graph object if they're present.

There is also a hook available you can use to retrieve and store the
access_token when it is set.

=back

=head1 USAGE

=head2 Basic usage

Load the module into your dancer application as you normally would:

  use Dancer;
  use Dancer::Plugin::Facebook;

This alone will configure the absolute bare minimum functionality,
allowing you to make requests to Facebook's API for public
information.

=head2 Registered application

If you have registered an application with Facebook, you should
configure the module to use the relevant C<Application ID> and
C<Application Secret> (see L<CONFIGURATION> for details), and then
call C<setup_fb> within your application, like so:

  use Dancer;
  use Dancer::Plugin::Facebook;
  setup_fb;

=head2 Authenticating users

If you wish for your application to be able to authenticate users
using Facebook, you need to specify a point where the necessary web
routes can be mounted when you call C<setup_fb>, like so:

  use Dancer;
  use Dancer::Plugin::Facebook;
  setup_fb '/auth/facebook';

=head2 Acting on a user's behalf

If you wish for your application to be able to conncect to Facebook on
behalf of a particular user, you need to additionally configure the
permissions the application requires (see L<CONFIGURATION> for
details).  Doing so implies that you will be L<Authenticating users>
as well; if you did not specify a mounting point when you called
C<setup_fb>, it will default to C</auth/facebook>.

=head1 CONFIGURATION

Your L<Dancer> C<config.yml> file C<plugins> section should look
something like this.

  plugins:
    Facebook:
      application:
        app_id: XXXXXXXXXXXXXXX
        secret: XXXXXXXXXXXXXXX
      permissions:
        - create_event
        - email
        - offline_access
        - publish_stream
        - rsvp_event

The C<app_id> and C<secret> keys in the C<application> section
correspond to the values available from L<the information page for your
application|https://developers.facebook.com/apps>.

The C<permissions> key includes a list of additional permissions you
may request at the time the user authorizes your application.
Facebook maintains L<a full list of available extended
permissions|http://developers.facebook.com/docs/authentication/permissions>.

The presence of a C<permissions> list implies the setup of
authentication.  If an authentication URL is not specified when
calling C<setup_fb>, it will default to C</auth/facebook>.

=cut

my (%config, $fb);

sub _get_fb {
    debug "Getting fb object [", $fb // "undef", "]";

    # The first time out, turn our raw, local postback URL into a
    # fully qualified one (see _do_fb_postback for more explanation).
    if ($config{raw_postback}) {
        my $url = delete $config{raw_postback};
        # Place the postback url in $config for object instantiation
        $config{postback} = uri_for ($url);
        debug "Full postback URL is ", $config{postback};
    }

    # We use a before hook to clear a stale FB handle out, and just
    # use ||= to regenerate as necessary here.
    $fb ||= do {
        my %settings = %config;
        if (my $access_token = session->{auth}->{facebook}) {
            $settings{access_token} = $access_token;
        }
        debug "Creating Facebook::Graph object with settings ", \%settings;
        Facebook::Graph->new (%settings);
    };
}

sub _do_fb_redirect () {
    my $settings = plugin_setting;
    debug "Settings are ", $settings;
    # Make sure the permissions settings exist
    my @permissions = ref $settings->{permissions} eq "ARRAY" ? @{$settings->{permissions}} : ();
    sub {
        redirect _get_fb->authorize->extend_permissions (@permissions)->uri_as_string;
    }
}

sub _do_fb_postback ($) {
    my $settings = plugin_setting;
    debug "Settings are ", $settings;

    my ($url) = @_;

    # We can only determine the relative URL right now, but that's
    # enough for initializing the route.  We put the relative URL
    # in $config{raw_postback} so that when fb is called for the
    # first time, which will be within a route handler, we can sub
    # in the full URL, which is what FB actually needs
    die "You must give me the postback URL when calling fb_postback" unless ($url);
    $config{raw_postback} = "$url/postback";

    # This hook will get called when we successfully authenticate and have
    # put the token in the session, so the application developer can
    # retrieve it.  It doesn't need to exist if a postback route hasn't been
    # established
    register_hook (['fb_access_token_available']);

    my $success = $settings->{landing}->{success} || "/";
    my $failure = $settings->{landing}->{failure} || "/";

    sub {
        try {
            my $token = _get_fb->request_access_token (params->{code});
            session->{auth}->{facebook} = $token->token;
            execute_hooks 'fb_access_token_available', $token->token;
            # Go back wherever
            redirect $success;
        } catch {
            redirect $failure;
        };
    }
}

register setup_fb => sub (;$) {
    my ($url) = @_;
    debug "Setting up fb access";

    # We need global access to this, grab it here
    my $settings = plugin_setting;
    debug "Settings are ", $settings;

    # Copy our registered application information over
    if (ref $settings->{application} eq "HASH") {
        debug "Setting application information";
        $config{app_id} = $settings->{application}->{app_id} or die "You didn't give me an app_id for Dancer::Plugin::Facebook";
        $config{secret} = $settings->{application}->{secret} or die "You didn't give me a secret for Dancer::Plugin::Facebook";
    }

    # Set a hook to clear out any old object unless existing tokens in
    # the object and session match one another.  In theory, this means
    # that absent an access token, we should never replace it.
    debug "Setting hook to clear facebook context";
    hook before => sub {
        if (defined $fb) {
            debug "Considering clearing facebook context";
            if (defined session->{auth}->{facebook}) {
                if ($fb->has_access_token) {
                    if ($fb->access_token ne session->{auth}->{facebook}) {
                        debug "Current FB access token doesn't match";
                        undef $fb;
                    }
                } else {
                    debug "Current FB doesn't have access token";
                    undef $fb;
                }
            } else {
                if ($fb->has_access_token) {
                    debug "Current login doesn't have access token";
                    undef $fb;
                }
            }
        }
    };

    # If the user wants the automatic URL setup
    if ($url) {
        debug "Creating handler for ", $url;
        get $url => _do_fb_redirect;

        my $postback = "$url/postback";
        debug "Creating handler for ", $postback;
        get $postback => _do_fb_postback $postback;
    }

    debug "Done setting up fb access";
};

register fb => \&_get_fb;
register fb_redirect => \&_do_fb_redirect;
register fb_postback => \&_do_fb_postback;
register_plugin;

=head1 SEE ALSO

L<Dancer>

L<Facebook::Graph>

=cut

1;
