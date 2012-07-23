package Dancer::Plugin::Facebook;
{
  $Dancer::Plugin::Facebook::VERSION = '0.001';
}
# ABSTRACT: Plugin linking Dancer with Facebook::Graph

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

__END__
=pod

=head1 NAME

Dancer::Plugin::Facebook - Plugin linking Dancer with Facebook::Graph

=head1 VERSION

version 0.001

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

=head1 BUGS

Please report any bugs via e-mail.

=head1 SEE ALSO

Dancer - L<Dancer>

Facebook::Graph - L<Facebook::Graph>

=head1 AUTHOR

Michael Alan Dorman <mdorman@ironicdesign.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Michael Alan Dorman.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

