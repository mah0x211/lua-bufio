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
local sub = string.sub
local isa = require('isa')
local is_boolean = isa.boolean
local is_string = isa.string
local is_uint = isa.uint
local is_table = isa.table
local is_userdata = isa.userdata
local is_function = isa.Function
--- constants
local DEFAULT_BUFSIZE = 1024 * 4

--- @class bufio.reader
--- @field reader table|userdata
--- @field bufsize integer
--- @field buf string
local Reader = {}

--- new
--- @param reader table|userdata
--- @return bufio.reader
--- @return string? err
function Reader:init(reader)
    if not is_table(reader) and not is_userdata(reader) then
        error('reader must be table or userdata', 2)
    elseif not is_function(reader.read) then
        error('reader.read must be function', 2)
    end

    self.bufsize = DEFAULT_BUFSIZE
    self.reader = reader
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
--- @return any? err
function Reader:read(n)
    if not is_uint(n) or n == 0 then
        error('n must be uint greater than 0', 2)
    end

    local buf = self.buf
    if #buf >= n then
        -- consume n-bytes of cached data
        self.buf = sub(buf, n + 1)
        return sub(buf, 1, n)
    end
    self.buf = ''

    -- read from reader
    local bufsize = self.bufsize > 0 and self.bufsize or DEFAULT_BUFSIZE
    local s, err = self:readin(bufsize)

    buf = buf .. s
    if err or #s == 0 then
        return buf, err
    elseif #buf >= n then
        -- cache an extra substring
        self.buf = sub(buf, n + 1)
        s = sub(buf, 1, n)
        return s
    end
    return buf
end

--- scan
--- @param delim string
--- @param is_pattern boolean
--- @return string? s
--- @return any? err
function Reader:scan(delim, is_pattern)
    if not is_string(delim) then
        error('delim must be string', 2)
    elseif is_pattern ~= nil and not is_boolean(is_pattern) then
        error('is_pattern must be boolean', 2)
    end

    local bufsize = self.bufsize > 0 and self.bufsize or DEFAULT_BUFSIZE
    local plain = is_pattern ~= true
    local str = ''
    local pos = 1
    while true do
        local s, err = self:read(bufsize)

        str = str .. s
        if #s == 0 or err then
            self:prepend(str)
            return nil, err
        end

        local head, tail = find(str, delim, pos, plain)
        if head then
            self:prepend(sub(str, tail + 1))
            return sub(str, 1, head - 1)
        end
        pos = #str
    end
end

--- readin
--- @param n integer
--- @return string s
--- @return any? err
function Reader:readin(n)
    if not is_uint(n) or n == 0 then
        error('n must be uint greater than 0', 2)
    end

    local s, err = self.reader:read(n)
    if s == nil then
        return '', err
    elseif not is_string(s) then
        error('reader:read() returned a non-string value')
    elseif #s > n then
        error(format('reader:read() returned a string larger than %d bytes', n))
    end

    return s, err
end

return {
    new = require('metamodule').new(Reader),
}
