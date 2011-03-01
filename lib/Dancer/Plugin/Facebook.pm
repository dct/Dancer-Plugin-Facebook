package Dancer::Plugin::Facebook;
# ABSTRACT: Plugin linking Dancer with Facebook::Graph

use Dancer ':syntax';
use Dancer::Plugin;

use Facebook::Graph;

=head1 SYNOPSIS

  use Dancer;
  use Dancer::Plugin::Facebook;

  get '/' => sub {
    fb->fetch ('16665510298')->{name};
  } # returns 'perl'

=head1 DESCRIPTION

Dancer::Plugin::Facebook is a simple shim taking the repetitious
scut-work out of using Facebook::Graph from within a Dancer
application.



=cut

my $fb;
my $cf;

register fb => sub {
    return $fb if $fb;
    unless (defined $cf) {
        my $conf = plugin_setting;
        if (ref $conf->{registration} eq "HASH") {
            $cf = plugin_setting->{registration}
        } else {
            $cf = {};
        }
    }
    $fb = Facebook::Graph->new (%{$cf});
};

register_plugin;

=head1 BUGS

Please report any bugs via e-mail.

=head1 SEE ALSO

Dancer - L<Dancer>

Facebook::Graph - L<Facebook::Graph>

=cut

1;
