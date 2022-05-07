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
local format = string.format
local select = select
local sub = string.sub
local unpack = unpack or table.unpack
local isa = require('isa')
local is_boolean = isa.boolean
local is_string = isa.string
local is_uint = isa.uint
local is_table = isa.table
local is_userdata = isa.userdata
local is_function = isa.Function
--- constants
local MAX_BUFSIZE = 1024 * 4

--- varg2list
--- @varg ...
--- @return integer n number of arguments
--- @return table<integer, any> list
local function varg2list(...)
    return select('#', ...), {
        ...,
    }
end

--- @class bufio.reader
--- @field src table|userdata
--- @field maxbufsize integer
--- @field buf string
local Reader = {}

--- new
--- @param src table|userdata
--- @return bufio.reader
--- @return string? err
function Reader:init(src)
    if not is_table(src) and not is_userdata(src) then
        error('src must be table or userdata', 2)
    elseif not is_function(src.read) then
        error('src must have a read method', 2)
    end

    self.maxbufsize = MAX_BUFSIZE
    self.src = src
    self.buf = ''
    return self
end

--- setbufsize
--- @param n integer
function Reader:setbufsize(n)
    if n == nil then
        self.maxbufsize = MAX_BUFSIZE
    elseif is_uint(n) then
        self.maxbufsize = n
    else
        error('n must be uint', 2)
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
    if not is_string(s) then
        error('s must be string', 2)
    end
    self.buf = s .. self.buf
end

--- read
--- @param n integer
--- @return string s
--- @return ...
function Reader:read(n)
    local nread = self.maxbufsize
    if n == nil then
        n = nread > 0 and nread or MAX_BUFSIZE
    elseif not is_uint(n) then
        error('n must be uint', 2)
    elseif n == 0 then
        return ''
    elseif n > nread then
        nread = n
    end

    local buf = self.buf
    local nbyte = #buf
    if nbyte > 0 then
        if n >= nbyte then
            -- consume all cached data
            self.buf = ''
            return buf
        end

        -- consume n-bytes of cached data
        self.buf = sub(buf, n + 1)
        return sub(buf, 1, n)
    end

    -- read from src
    local ret = {
        self.src:read(nread),
    }
    local s = ret[1]
    if s == nil then
        return unpack(ret)
    elseif not is_string(s) then
        error('src.read method returned an invalid string', 2)
    elseif #s > nread then
        error(format(
                  'src.read method returned a string (%d bytes) larger than %d bytes',
                  #s, n), 2)
    end

    -- cache an extra substring
    if n < nread then
        self.buf = sub(s, n + 1)
        return sub(s, 1, n)
    end

    return s
end

--- scan
--- @param delim string
--- @param is_pattern boolean
--- @return string s
--- @return ...
function Reader:scan(delim, is_pattern)
    if not is_string(delim) then
        error('delim must be string', 2)
    elseif is_pattern ~= nil and not is_boolean(is_pattern) then
        error('is_pattern must be boolean', 2)
    end

    local plain = is_pattern ~= true
    local s = ''
    local pos = 1
    while 1 do
        local ret = {
            self:read(),
        }
        local chunk = ret[1]
        if chunk == nil or #chunk == 0 then
            self:prepend(s)
            ret[1] = nil
            return unpack(ret)
        end
        s = s .. chunk

        local head, tail = find(s, delim, pos, plain)
        if head then
            self:prepend(sub(s, tail + 1))
            return sub(s, 1, head - 1)
        end
        pos = #s
    end
end

--- readin
--- @param n integer
--- @return string s
--- @return string err
--- @return ...
function Reader:readin(n)
    if not is_uint(n) or n == 0 then
        error('n must be uint greater than 0', 2)
    end

    local nread = n
    local src = self.src
    local str = ''
    while 1 do
        local nres, res = varg2list(src:read(n))
        local s = res[1]

        if nres == 0 or not s then
            res[1] = str
            return unpack(res)
        elseif not is_string(s) then
            return str, 'src.read method returned a non-string value'
        end

        local slen = #s
        if slen == 0 then
            res[1] = str
            return unpack(res)
        elseif slen == n then
            return str .. s
        elseif slen < n then
            str = str .. s
            n = n - slen
        else
            return str, format(
                       'src.read method returned a string larger than %d bytes',
                       nread)
        end
    end
end

return {
    new = require('metamodule').new(Reader),
}
