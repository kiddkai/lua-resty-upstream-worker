use lib 't';
use TestDNS;
use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;$pwd/t/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

no_shuffle();
run_tests();

__DATA__

=== TEST 1: dns - returns error when query is empty
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'

            local t, e = worker.new({
                type = worker.TYPE_DNS
            })

            if not t then
                return ngx.say(e)
            end
        }
    }

--- request
GET /t

--- response_body
.name is required



=== TEST 2: dns - returns error when resolver is empty
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'

            local t, e = worker.new({
                type = worker.TYPE_DNS,
                name = 'google.com'
            })

            if not t then
                return ngx.say(e)
            end
        }
    }

--- request
GET /t

--- response_body
.resolver option is required, see https://github.com/openresty/lua-resty-dns#new



=== TEST 3: dns - returns error when co is empty
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'

            local t, e = worker.new({
                type = worker.TYPE_DNS,
                resolver = {},
                name = 'google.com'
            })

            if not t then
                return ngx.say(e)
            end
        }
    }

--- request
GET /t

--- response_body
a coroutine object need to provided in the co property


=== TEST 4: dns - consume normal dns record, and uses 80 as default port
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'

            local function handler()
                local upstreams
                upstreams = coroutine.yield()
                for i=1,#upstreams do
                  ngx.say(upstreams[i][1] .. ':' .. tostring(upstreams[i][2]))
                end
                ngx.exit(200)
            end

            local co = coroutine.create(handler)
            coroutine.resume(co)
            local t, e = worker.new({
                type = worker.TYPE_DNS,
                resolver = {
                    nameservers = { {'127.0.0.1', 1953} }
                },
                name = 'www.google.com',
                co = co,
                _id = 125
            })
        }
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [{ name => "www.google.com", ipv4 => "127.0.0.99", ttl => 123456 }],
}
--- request
GET /t
--- response_body
127.0.0.99:80


=== TEST 5: dns - consume normal dns record, and uses `default_port` option in the config
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local worker = require 'resty.upstream.worker'

            local function handler()
                local upstreams
                upstreams = coroutine.yield()
                for i=1,#upstreams do
                  ngx.say(upstreams[i][1] .. ':' .. tostring(upstreams[i][2]))
                end
                ngx.exit(200)
            end

            local co = coroutine.create(handler)
            coroutine.resume(co)
            local t, e = worker.new({
                type = worker.TYPE_DNS,
                resolver = {
                    nameservers = { {'127.0.0.1', 1953} }
                },
                name = 'www.google.com',
                co = co,
                default_port = 8888,
                _id = 125
            })
        }
    }
--- udp_listen: 1953
--- udp_reply dns
{
    id => 125,
    opcode => 0,
    qname => 'www.google.com',
    answer => [{ name => "www.google.com", ipv4 => "127.0.0.99", ttl => 123456 }],
}
--- request
GET /t
--- response_body
127.0.0.99:8888

