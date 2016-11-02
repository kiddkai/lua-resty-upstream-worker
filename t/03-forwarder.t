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

plan tests => repeat_each() * 3 * blocks();

no_shuffle();
run_tests();

__DATA__



=== TEST 1: forwards single upstream
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 9999;
        location = /update {
            content_by_lua_block {
                ngx.req.read_body()
                local data = ngx.req.get_body_data()
                ngx.log(ngx.ERR, data)
                ngx.say('ok')
            }
        }
    }
}

--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'
            local f = worker.forwarder({
                host = '127.0.0.1',
                port = 9999,
                path = '/update'
            })

            coroutine.resume(f, {
                { '88.88.88.88', 88 }
            })

            ngx.say('ok')
        }
    }

--- request
GET /t

--- response_body
ok

--- error_log
[["88.88.88.88",88]]


=== TEST 2: forwards multiple upstreams
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 9999;
        location = /update {
            content_by_lua_block {
                ngx.req.read_body()
                local data = ngx.req.get_body_data()
                ngx.log(ngx.ERR, data)
                ngx.say('ok')
            }
        }
    }
}

--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'
            local f = worker.forwarder({
                host = '127.0.0.1',
                port = 9999,
                path = '/update'
            })

            coroutine.resume(f, {
                { '88.88.88.88', 88 }
            })

            ngx.sleep(1)

            coroutine.resume(f, {
                { '99.99.99.99', 99 }
            })

            ngx.say('ok')
        }
    }

--- request
GET /t

--- response_body
ok

--- error_log
[["88.88.88.88",88]]



=== TEST 3: sends multiple upstreams
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 9999;
        location = /update {
            content_by_lua_block {
                ngx.req.read_body()
                local data = ngx.req.get_body_data()
                ngx.log(ngx.ERR, data)
                ngx.say('ok')
            }
        }
    }
}

--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'
            local f = worker.forwarder({
                host = '127.0.0.1',
                port = 9999,
                path = '/update'
            })

            coroutine.resume(f, {
                { '88.88.88.88', 88 }
            })

            ngx.sleep(1)

            coroutine.resume(f, {
                { '99.99.99.99', 99 }
            })

            ngx.say('ok')
        }
    }

--- request
GET /t

--- response_body
ok

--- error_log
[["99.99.99.99",99]]



=== TEST 4: sends single upstream duplicated
--- http_config eval
"$::HttpConfig"
. q{
    lua_shared_dict count 1m;
    server {
        listen 9999;
        location = /update {
            content_by_lua_block {
                local dict = ngx.shared.count;
                local count = dict:get('count')

                if not count then
                    count = 1
                else
                    count = count + 1
                end

                dict:set('count', count)
                ngx.log(ngx.ERR, 'count is: ' .. tostring(count))
                ngx.say('ok')
            }
        }
    }
}

--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'
            local f = worker.forwarder({
                host = '127.0.0.1',
                port = 9999,
                path = '/update'
            })
            coroutine.resume(f, {
                { '88.88.88.88', 88 }
            })
            ngx.sleep(1)
            coroutine.resume(f, {
                { '88.88.88.88', 88 }
            })
            ngx.say('ok')
        }
    }

--- request
GET /t

--- response_body
ok

--- no_error_log
count is: 2

