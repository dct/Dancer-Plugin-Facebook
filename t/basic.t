#!/usr/bin/perl

use strict;
use warnings;
# Stupid Test::More
use Test::More import => ['!pass'];

use Dancer::Test appdir => '..';
use Dancer;

{
    package FBTestApp;
    use strict;
    use warnings;
    use Dancer ':syntax';
    use Dancer::Plugin::Facebook;
    set log => "error";
    set logger => "console";
    set warnings => 1;
    get '/perl'               => sub { fb->fetch ('16665510298')->{name}; };
    1;
}

route_exists        [ GET => '/perl' ], "GET /perlpage handled";
response_status_is  [ GET => '/perl' ], 200, "GET /perlpage 200";
response_content_is [ GET => '/perl' ], "perl", "Correct response received";

done_testing;
