--
-- Copyright (C) 2022 Masatoshi Fukunaga
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
local format = string.format
local sub = string.sub
local remove = table.remove
local unpack = unpack or table.unpack
local isa = require('isa')
local is_string = isa.string
local is_table = isa.table
local is_uint = isa.uint
local is_userdata = isa.userdata
local is_function = isa.Function
--- constants
local MAX_BUFSIZE = 1024 * 4

--- @class bufio.writer
--- @field dst table|userdata
--- @field maxbufsize integer
--- @field buf string[]
--- @field bufsize integer
--- @field nflush integer
local Writer = {}

--- init
--- @param dst table|userdata
--- @return bufio.writer
--- @return string? err
function Writer:init(dst)
    if not is_table(dst) and not is_userdata(dst) then
        error('dst must be table or userdata', 2)
    elseif not is_function(dst.write) then
        error('dst must have a write method', 2)
    end

    self.maxbufsize = MAX_BUFSIZE
    self.dst = dst
    self.buf = {}
    self.bufsize = 0
    self.nflush = 0
    return self
end

--- setbufsize
--- @param n integer
function Writer:setbufsize(n)
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
function Writer:size()
    return self.bufsize
end

--- available
--- @return integer
function Writer:available()
    return self.maxbufsize - self.bufsize
end

--- flushed returns the number of flushed bytes
function Writer:flushed()
    return self.nflush
end

--- flush
--- @return integer len
--- @return any err
--- @return ...
function Writer:flush()
    local buf = self.buf
    local dst = self.dst
    local total = 0

    -- clear nflush
    self.nflush = 0

    while #buf > 0 do
        local s = buf[1]
        local nwrite = #s
        local ret = {
            dst:write(s),
        }
        local len = ret[1]

        if len == nil then
            return unpack(ret)
        elseif not is_uint(len) then
            error(
                'dst.write method returned an invalid number of bytes written',
                2)
        elseif len > nwrite then
            error(format(
                      'dst.write method returned a number of bytes written greater than %d',
                      nwrite), 2)
        end

        total = total + len
        if len < nwrite then
            buf[1] = sub(s, len + 1)
            self.bufsize = self.bufsize - total
            self.nflush = total
            ret[1] = total
            return unpack(ret)
        end
        remove(buf, 1)
    end

    -- all data has been write
    self.buf = {}
    self.bufsize = 0
    self.nflush = total

    return total
end

--- write
--- @param s string
--- @return integer len
--- @return ...
function Writer:write(s)
    if not is_string(s) then
        error('s must be string', 2)
    end

    local nwrite = #s
    local maxbufsize = self.maxbufsize
    local avail = self:available()
    if self.bufsize > 0 and
        (avail <= 0 or nwrite > maxbufsize or avail - nwrite < 0) then
        -- buffer space not available
        local ret = {
            self:flush(),
        }
        if ret[2] then
            ret[1] = nil
            return unpack(ret)
        end
    end

    if nwrite == 0 then
        return 0
    end

    -- NOTE: concatenate a data with the last data to reduce the number of
    -- dst.write() operations.
    local buf = self.buf
    local tail = buf[#buf]
    if not tail or nwrite > MAX_BUFSIZE or #tail + nwrite >= MAX_BUFSIZE then
        buf[#buf + 1] = s
    else
        buf[#buf] = tail .. s
    end
    self.bufsize = self.bufsize + nwrite

    if self.bufsize >= maxbufsize then
        return self:flush()
    end

    return nwrite
end

return {
    new = require('metamodule').new(Writer),
}