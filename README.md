# lua-resty-upstream-worker

## Name

lua-resty-upstream-worker - a consul & dns crowler/pusher for openresty.

## Table of Contents

* [Name](#Name)
* [Status](#Status)
* [Description](#Description)

## Status

This library is still work in progress.

## Description

This lua library provides a simple way to fetch upstream informations from multiple sources:

1. consul
2. DNS Server

Which run as a worker will keep checking the updates of upstream informations and pushes updates
to target endpoint.

## Synopsis

```lua
#!/usr/local/openresty/bin/resty
local worker = require 'resty.upstream.worker'

local f1 = worker.forwarder({
  host = '127.0.0.1',
  port = 9999,
  path = '/v1/upstreams/consul-foo'
})

local ct, e1 = worker.new({
    type = worker.TYPE_CONSUL,
    host = '127.0.0.1',
    port = 1999,
    name = 'test',
    co = f1
})

local f2 = worker.forwarder({
  host = '127.0.0.1',
  port = 9999,
  path = '/v1/upstreams/dns-bar'
})

local dt, e2 = worker.new({
    type = worker.TYPE_DNS,
    host = '8.8.8.8',
    port = 53,
    name = 'google.com',
    co = f2
})

ngx.thread.wait(ct, dt)

--- or

local w1 = {
  source = {
    type = worker.TYPE_DNS,
    host = '8.8.8.8',
    port = 53,
    name = 'google.com',
    co = f2
  },
  dest = {
    host = '127.0.0.1',
    port = 9999,
    path = '/v1/upstreams/consul-foo'
  }
}

local w2 = {
  source = {
    type = worker.TYPE_DNS,
    host = '8.8.8.8',
    port = 53,
    name = 'google.com',
    co = f2
  },
  dest = {
    host = '127.0.0.1',
    port = 9999,
    path = '/v1/upstreams/consul-foo'
  }
}

--- it will run and restart dead one's
local stop = worker.run({
  w1, w2
})

--- stop() to stop the task
```

