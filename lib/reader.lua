--
-- Copyright (C) 2021-2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--- assign to local
local find = string.find
local sub = string.sub
local pcall = pcall
local type = type
local fatalf = require('error').fatalf
local new_errno = require('errno').new
local is_str = require('lauxhlib.is').str
local is_uint = require('lauxhlib.is').uint
--- constants
local DEFAULT_BUFSIZE = 1024 * 4

--- @class bufio.reader
--- @field private reader table|userdata
--- @field private bufsize integer
--- @field buf string
local Reader = {}

--- new
--- @param src string|table|userdata
--- @return bufio.reader
--- @return string? err
function Reader:init(src)
    if is_str(src) then
        --- @cast src string
        self.reader = {
            read = function(_, n)
                if n == 0 or #src == 0 then
                    return nil
                end

                local s = sub(src, 1, n)
                src = sub(src, n + 1)
                return s
            end,
        }
    else
        --- @cast src table|userdata
        local ok, res = pcall(function()
            return type(src) == 'string' or type(src.read) == 'function'
        end)
        if not ok or not res then
            fatalf(2, 'src must be string or have read() method')
        end
        self.reader = src
    end

    self.bufsize = DEFAULT_BUFSIZE
    self.buf = ''
    return self
end

--- setbufsize
--- @param n integer
function Reader:setbufsize(n)
    if n == nil then
        self.bufsize = DEFAULT_BUFSIZE
    elseif is_uint(n) then
        self.bufsize = n
    else
        fatalf(2, 'n must be uint')
    end
end

--- size
--- @return integer
function Reader:size()
    return #self.buf
end

--- prepend a data to read buffer
--- @param s string
function Reader:prepend(s)
    if type(s) ~= 'string' then
        fatalf(2, 's must be string')
    end
    self.buf = s .. self.buf
end

--- read
--- @param n integer
--- @return string? s
--- @return any err
--- @return boolean? timeout
function Reader:read(n)
    if not is_uint(n) or n == 0 then
        fatalf(2, 'n must be uint greater than 0')
    end

    local buf = self.buf
    -- consume cached data
    if #buf > 0 then
        if #buf <= n then
            self.buf = ''
            return buf
        end

        -- consume n-bytes
        self.buf = sub(buf, n + 1)
        buf = sub(buf, 1, n)
        return buf
    end

    -- read from reader
    local bufsize = self.bufsize > 0 and self.bufsize or DEFAULT_BUFSIZE
    local s, err, timeout = self:readin(bufsize)
    if not s or err or timeout then
        return #buf > 0 and buf or nil, err, timeout
    end

    buf = buf .. s
    if #buf >= n then
        -- cache an extra substring
        self.buf = sub(buf, n + 1)
        buf = sub(buf, 1, n)
    end
    return buf
end

--- readfull
--- @param n integer
--- @return string s
--- @return any err
--- @return boolean? timeout
function Reader:readfull(n)
    if not is_uint(n) or n == 0 then
        fatalf(2, 'n must be uint greater than 0')
    end

    local buf = self.buf
    if #buf >= n then
        -- consume n-bytes of cached data
        self.buf = sub(buf, n + 1)
        buf = sub(buf, 1, n)
        return buf
    end
    self.buf = ''

    -- read from reader
    local bufsize = self.bufsize > 0 and self.bufsize or DEFAULT_BUFSIZE
    while true do
        local s, err, timeout = self:readin(bufsize)
        if err or timeout then
            return buf, err, timeout
        elseif not s then
            return buf, new_errno('ENODATA')
        end

        buf = buf .. s
        if #buf >= n then
            -- cache an extra substring
            self.buf = sub(buf, n + 1)
            s = sub(buf, 1, n)
            return s
        end
    end
end

--- scan
--- @param delim string
--- @param is_pattern boolean
--- @return string? s
--- @return any err
--- @return boolean? timeout
function Reader:scan(delim, is_pattern)
    if type(delim) ~= 'string' then
        fatalf(2, 'delim must be string')
    elseif is_pattern ~= nil and type(is_pattern) ~= 'boolean' then
        fatalf(2, 'is_pattern must be boolean')
    end

    local bufsize = self.bufsize > 0 and self.bufsize or DEFAULT_BUFSIZE
    local plain = is_pattern ~= true
    local str = ''
    local pos = 1
    while true do
        local s, err, timeout = self:read(bufsize)
        if not s or err or timeout then
            self:prepend(str)
            return nil, err, timeout
        end

        str = str .. s
        local head, tail = find(str, delim, pos, plain)
        if head then
            self:prepend(sub(str, tail + 1))
            str = sub(str, 1, head - 1)
            return str
        end
        pos = #str
    end
end

--- readin
--- @param n integer
--- @return string? s
--- @return any err
--- @return boolean? timeout
function Reader:readin(n)
    if not is_uint(n) or n == 0 then
        fatalf(2, 'n must be uint greater than 0')
    end

    local s, err, timeout = self.reader:read(n)
    if err or timeout then
        return nil, err, timeout and true
    elseif s == nil then
        return nil
    elseif type(s) ~= 'string' then
        fatalf('reader:read() returned a non-string value')
    elseif #s > n then
        fatalf('reader:read() returned a string larger than %d bytes', n)
    elseif #s > 0 then
        return s
    end
end

return {
    new = require('metamodule').new(Reader),
}
