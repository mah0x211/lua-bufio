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
local isa = require('isa')
local is_string = isa.string
local is_table = isa.table
local is_uint = isa.uint
local is_userdata = isa.userdata
local is_function = isa.Function
--- constants
local MAX_BUFSIZE = 1024 * 4

--- @class bufio.writer
--- @field writer table|userdata
--- @field maxbufsize integer
--- @field buf string[]
--- @field bufsize integer
--- @field nflush integer
local Writer = {}

--- init
--- @param writer table|userdata
--- @return bufio.writer
--- @return string? err
function Writer:init(writer)
    if not is_table(writer) and not is_userdata(writer) then
        error('writer must be table or userdata', 2)
    elseif not is_function(writer.write) then
        error('writer.write must be function', 2)
    end

    self.maxbufsize = MAX_BUFSIZE
    self.writer = writer
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
--- @return integer n
--- @return any err
function Writer:flush()
    local buf = self.buf
    local nflush = 0

    while #buf > 0 do
        local s = buf[1]
        local nwrite = #s
        local n, err = self:writeout(s)

        nflush = nflush + n
        if n < nwrite or err then
            buf[1] = sub(s, n + 1)
            self.bufsize = self.bufsize - nflush
            self.nflush = nflush
            return nflush, err
        end

        remove(buf, 1)
    end

    -- all data has been write
    self.buf = {}
    self.bufsize = 0
    self.nflush = nflush or 0

    return self.nflush
end

--- write
--- @param s string
--- @return integer n
--- @return any err
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
        local n, err = self:flush()
        if err then
            return n, err
        end
    end

    -- NOTE: concatenate a data with the last data to reduce the number of
    -- writer.write() operations.
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
--- @return integer n
--- @return any err
function Writer:writeout(s)
    if not is_string(s) then
        error('s must be string', 2)
    end

    local writer = self.writer
    local nwrite = 0
    local len = #s

    while len > 0 do
        local n, err = writer:write(s)

        if n == nil then
            if err == nil then
                error('writer:write() returned nil without error')
            end
            return nwrite, err
        elseif n < 0 then
            error(format('writer:write() returned %d less than 0', n))
        elseif n > len then
            error(format('writer:write() returned %d greater than data size %d',
                         n, len))
        end

        nwrite = nwrite + n
        if n == len or err then
            -- done or got error
            return nwrite, err
        elseif n == 0 then
            error('writer:write() returned 0 without error')
        end
        s = sub(s, n + 1)
        len = #s
    end

    return nwrite
end

return {
    new = require('metamodule').new(Writer),
}
