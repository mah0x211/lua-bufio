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
local select = select
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

--- varg2list
--- @varg ...
--- @return integer n number of arguments
--- @return table<integer, any> list
local function varg2list(...)
    return select('#', ...), {
        ...,
    }
end

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
--- @return string err
--- @return ...
function Writer:flush()
    local buf = self.buf
    local nflush

    while #buf > 0 do
        local s = buf[1]
        local nwrite = #s
        local nres, res = varg2list(self:writeout(s))
        local n = res[1]

        if nres == 0 or not n then
            self.nflush = nflush or 0
            res[1] = nflush
            return unpack(res)
        end

        nflush = (nflush or 0) + n
        if n < nwrite then
            buf[1] = sub(s, n + 1)
            self.bufsize = self.bufsize - nflush
            self.nflush = nflush
            res[1] = nflush
            return unpack(res)
        end

        remove(buf, 1)
    end

    -- all data has been write
    self.buf = {}
    self.bufsize = 0
    self.nflush = nflush

    return nflush
end

--- write
--- @param s string
--- @return integer len
--- @return string err
--- @return ...
function Writer:write(s)
    if not is_string(s) then
        error('s must be string', 2)
    end

    local nwrite = #s
    if nwrite == 0 then
        return 0
    end

    local maxbufsize = self.maxbufsize
    local avail = self:available()
    if self.bufsize > 0 and
        (avail <= 0 or nwrite > maxbufsize or avail - nwrite < 0) then
        -- buffer space not available
        local nres, res = varg2list(self:flush())
        if nres == 0 or nres > 1 then
            return unpack(res)
        end
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

--- writeout
--- @param s string
--- @return integer len
--- @return string err
--- @return ...
function Writer:writeout(s)
    local dst = self.dst
    local len = #s
    local nwrite

    while 1 do
        local nres, res = varg2list(dst:write(s))
        local n = res[1]

        if nres == 0 or not n then
            res[1] = nwrite
            return unpack(res)
        elseif not is_uint(n) then
            return nwrite,
                   'dst.write method returned an invalid number of bytes written'
        elseif n == 0 then
            res[1] = nwrite
            return unpack(res)
        elseif n == #s then
            res[1] = (nwrite or 0) + n
            return unpack(res)
        elseif n < #s then
            nwrite = (nwrite or 0) + n
            if nres > 1 then
                res[1] = nwrite
                return unpack(res)
            end
            s = sub(s, n + 1)
        else
            return nwrite,
                   format(
                       'dst.write method returned a number of bytes written greater than %d',
                       len)
        end
    end
end

return {
    new = require('metamodule').new(Writer),
}
