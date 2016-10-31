-- Copyright (C) Zekai Zheng (kiddkai)
--

local _M = {}

local function as_str(u)
    return u[1] .. ':' .. tostring(u[2])
end

function _M.diff(usa, usb)
    if #usa ~= #usb then
        return true
    end

    local ua, ub, found
    for i = 1, #usb do
        found = false
        ub = as_str(usb[i])

        for j = 1, #usa do
            ua = as_str(usa[j])
            if ua == ub then
                found = true
            end
        end

        if not found then
            return true
        end
    end

    return false
end

return _M

