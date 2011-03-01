package Dancer::Plugin::Facebook;

use Dancer ':syntax';
use Dancer::Plugin;

use Facebook::Graph;

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

1;
