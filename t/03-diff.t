# vi:ft= et ts=4 sw=4

use lib 't';
use Test::Nginx::Socket;
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/t/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

repeat_each(1);

plan tests => repeat_each() * 2 * blocks();

no_shuffle();
run_tests();

__DATA__



=== TEST 1: diff - will difference when both input have different size
--- http_config eval
"$::HttpConfig"
. q{ }

--- config
    location /t {
        content_by_lua_block {
            local d = require 'resty.upstream.diff'
            ngx.say(tostring(d.diff({}, { {} })))
        }
    }

--- request
GET /t

--- response_body
true



=== TEST 2: diff - will be the same if they all empty
--- http_config eval
"$::HttpConfig"
. q{ }

--- config
    location /t {
        content_by_lua_block {
            local d = require 'resty.upstream.diff'
            ngx.say(tostring(d.diff({}, {})))
        }
    }

--- request
GET /t

--- response_body
false



=== TEST 3: diff - will be the different when host and port is the different
--- http_config eval
"$::HttpConfig"
. q{ }

--- config
    location /t {
        content_by_lua_block {
            local d = require 'resty.upstream.diff'
            ngx.say(tostring(d.diff({
                { '127.0.0.2', 80 }
            }, {
                { '127.0.0.1', 80 }
            })))
        }
    }

--- request
GET /t

--- response_body
true



=== TEST 4: diff - will be the same even order is different 
--- http_config eval
"$::HttpConfig"
. q{ }

--- config
    location /t {
        content_by_lua_block {
            local d = require 'resty.upstream.diff'
            ngx.say(tostring(d.diff({
                { '127.0.0.2', 80 },
                { '127.0.0.1', 80 }
            }, {
                { '127.0.0.1', 80 },
                { '127.0.0.2', 80 }
            })))
        }
    }

--- request
GET /t

--- response_body
false

