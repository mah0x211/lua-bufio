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
local sub = string.sub
local pcall = pcall
local remove = table.remove
local type = type
local fatalf = require('error').fatalf
local is_uint = require('lauxhlib.is').uint
--- constants
local MAX_BUFSIZE = 1024 * 4

--- @class bufio.writer
--- @field writer table|userdata
--- @field maxbufsize integer
--- @field buf string[]
--- @field bufsize integer
--- @field nflush integer
--- @field nout integer
local Writer = {}

--- init
--- @param dst table|userdata
--- @return bufio.writer
--- @return string? err
function Writer:init(dst)
    local ok, res = pcall(function()
        return type(dst.write) == 'function'
    end)
    if not ok or not res then
        error('dst.write must be function', 2)
    end

    self.maxbufsize = MAX_BUFSIZE
    self.writer = dst
    self.buf = {}
    self.bufsize = 0
    self.nflush = 0
    self.nout = 0
    return self
end

--- setbufsize sets the size of the maximum buffer space in bytes
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

--- size returns the size of the buffered data
--- @return integer
function Writer:size()
    return self.bufsize
end

--- available returns the size of the remaining buffer space
--- @return integer
function Writer:available()
    return self.maxbufsize - self.bufsize
end

--- bytes_out returns the number of bytes written out to the underlying writer
--- @param clear boolean? clear the counter
--- @return integer nout
function Writer:bytes_out(clear)
    local nout = self.nout
    if clear == true then
        self.nout = 0
    end
    return nout
end

--- flushed returns the number of flushed bytes
--- @return integer nflush
function Writer:flushed()
    return self.nflush
end

--- flush writes any buffered data to the underlying writer
--- @return integer? n
--- @return any err
--- @return boolean? timeout
function Writer:flush()
    local buf = self.buf
    local nflush = 0

    while #buf > 0 do
        local s = buf[1]
        local nwrite = #s
        local n, err = self:writeout(s)
        if not n then
            return nil, err
        end

        nflush = nflush + n
        if n < nwrite then
            buf[1] = sub(s, n + 1)
            self.bufsize = self.bufsize - nflush
            self.nflush = nflush
            -- it is treated as a timeout if the number of bytes written is
            -- less than #s.
            return nflush, nil, true
        end

        remove(buf, 1)
    end

    -- all data has been write
    self.buf = {}
    self.bufsize = 0
    self.nflush = nflush or 0

    return self.nflush
end

--- write stores data into the buffer and write it out to the underlying writer
--- if the buffer space is not enough.
--- at first, if the buffer space is not enough, it will be written buffered
--- data out to the writer.
--- @param s string
--- @return integer? n
--- @return any err
--- @return boolean? timeout
function Writer:write(s)
    if type(s) ~= 'string' then
        fatalf(2, 's must be string')
    end

    local nwrite = #s
    if nwrite == 0 then
        return 0
    end

    local avail = self:available()
    if avail <= 0 or avail < nwrite then
        -- buffer space not available
        local n, err, timeout = self:flush()
        if not n then
            return nil, err
        elseif timeout then
            return 0, nil, timeout
        end
    end

    if nwrite > self.maxbufsize then
        -- not enough buffer space
        return self:writeout(s)
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

    return nwrite
end

--- writeout writes data directly to the underlying writer
--- @param s string
--- @return integer? n
--- @return any err
--- @return boolean? timeout
function Writer:writeout(s)
    if type(s) ~= 'string' then
        fatalf(2, 's must be string')
    end

    local len = #s
    if len == 0 then
        return 0
    end

    local writer = self.writer
    local nwrite = 0
    while len > 0 do
        local n, err, timeout = writer:write(s)

        if n ~= nil and type(n) ~= 'number' then
            fatalf('writer:write() returned non-number value: %s', type(n))
        elseif n == nil or err then
            -- connection closed by peer or got an error
            return nil, err
        elseif n < 0 then
            fatalf('writer:write() returned %d less than 0', n)
        elseif n > len then
            fatalf('writer:write() returned %d greater than data size %d', n,
                   len)
        end

        self.nout = self.nout + n
        nwrite = nwrite + n
        if timeout then
            return nwrite, nil, true
        elseif n == len then
            -- done
            return nwrite
        elseif n == 0 then
            fatalf('writer:write() returned 0 with not timeout')
        end
        s = sub(s, n + 1)
        len = len - n
    end

    return nwrite
end

return {
    new = require('metamodule').new(Writer),
}
