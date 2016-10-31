-- Copyright (C) Zekai Zheng (kiddkai)

local ngx = require 'ngx'
local json = require 'cjson'
local http = require 'resty.http'
local resolver = require 'resty.dns.resolver'
local d = require 'resty.upstream.diff'
local diff = d.diff
local spawn = ngx.thread.spawn
local resume = coroutine.resume
local decode = json.decode
local encode = json.encode
local encode_args = ngx.encode_args 

local TYPE_DNS = 'DNS'
local TYPE_CONSUL = 'CONSUL'
local CONSUL_HEALTH_ROUTE = '/v1/health/service/'



local _M = {
    TYPE_DNS = TYPE_DNS,
    TYPE_CONSUL = TYPE_CONSUL
}



local function get_json(opts)
    local client = http.new()
    local timeout = opts.timeout
    local ok, err, res, body

    ok, err = client:connect(opts.host, opts.port)

    if not ok then
        return nil, err
    end

    client:set_timeout(timeout)
    res, err = client:request({
        path = opts.path,
        headers = opts.headers
    })

    if not res then
        ngx.log(ngx.ERR, '[request] no res: ', err)
        return nil, err
    elseif res.headers['connection'] == 'close' then
        body = res:read_body()
        ok, err = client:close()
        if not ok then
            return nil, err
        end
    else
        body = res:read_body()
        client:set_keepalive()
    end

    return {
        body = decode(body),
        status = res.status,
        headers = res.headers
    }
end




local function consul_health_to_upstreams(body)
    local result = {}

    for _, health_node in ipairs(body) do
        local service = health_node.Service

        if service then
            table.insert(result, { service.Address, service.Port })
        end
    end

    return result
end



local function fetch_consul(opts)
    if not opts.name then
        return nil, '.name is required'
    end

    if not opts.co then
        return nil, 'a coroutine object need to provided in the co property'
    end

    local th, err, resp
    local name = opts.name
    local co = opts.co
    local protocol = opts.protocol or 'http'
    local host = opts.host or 'localhost'
    local port = opts.port or 8500
    local search = encode_args(opts.query or { passing = true })
    local path = CONSUL_HEALTH_ROUTE .. name .. '?' .. search

    th, err = spawn(function ()
        local consul_index
        local headers
        local _path

        while true do
            _path = path

            if consul_index then
                _path = _path .. '&index=' .. tostring(consul_index)
            end

            resp, err = get_json({
                protocol = protocol,
                host = host,
                port = port,
                path = _path,
                headers = headers
            })

            if not resp then
                return nil, err
            end

            if resp.status ~= 200 then
                return nil, encode(resp.body)
            end

            headers = resp.headers
            consul_index = headers['x-consul-index']
            resume(co, consul_health_to_upstreams(resp.body))
        end
    end)

    if not th then
        return nil, err
    end

    return th
end



local function fetch_dns(opts)
    if not opts.name then
        return nil, '.name is required'
    end

    if not opts.resolver then
        return nil, '.resolver option is required, see https://github.com/openresty/lua-resty-dns#new'
    end

    if not opts.co then
        return nil, 'a coroutine object need to provided in the co property'
    end


    local r, err, answers
    local co = opts.co

    while true do
        r, err = resolver:new(opts.resolver)
        if not r then
            return nil, err
        end

        if opts._id then
            r._id = opts._id
        end
        answers, err = r:query(opts.name, opts.query or { qtype = r.TYPE_A })
        if not answers then
            return nil, err
        end

        if answers.errcode then
            return nil, '[' .. tostring(answers.errcode) .. ']' .. answers.errstr
        end

        local result = {}
        local ttl
        for _, ans in ipairs(answers) do
            if ans.type == r.TYPE_A then
                table.insert(result, { ans.address, opts.default_port or 80 })
            end
            if ans.ttl then
                ttl = ans.ttl
            end
        end
        resume(co, result)

        if ttl and ttl > 0 then
            ngx.sleep(ttl)
        else
            --- minimum ttl, make it not query the dns server too freq...
            ngx.sleep(1)
        end
    end
end



function _M.new(opts)
    local t = opts['type']
    if t == TYPE_CONSUL then
        return fetch_consul(opts)
    elseif t == TYPE_DNS then
        return fetch_dns(opts)
    end
    return nil, 'unknown type ' .. tostring(t)
end



function _M.forwarder(opts)

end



return _M
