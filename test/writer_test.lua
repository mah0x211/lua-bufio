require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local writer = require('bufio.writer')

function testcase.new()
    -- test that create bufio.writer with a dst with write method
    local w = writer.new({
        write = function()
        end,
    })
    assert.match(tostring(w), '^bufio.writer: ', false)

    -- test that throws an error with invalid dst arguments
    for _, v in ipairs({
        true,
        0,
        {},
        function()
        end,
        coroutine.create(function()
        end),
    }) do
        local err = assert.throws(function()
            writer.new(v)
        end)
        assert.match(err, 'dst.write must be function')
    end
    local err = assert.throws(writer.new)
    assert.match(err, 'dst.write must be function')
end

function testcase.setbufsize()
    local w = writer.new({
        write = function()
        end,
    })

    -- test that set buffering size
    w:setbufsize(5)
    assert.equal(w:available(), 5)

    -- test that set nil to default buffering size
    w:setbufsize()
    assert.equal(w:available(), 4096)

    -- test that throws an error if invalid size
    local err = assert.throws(w.setbufsize, w, {})
    assert.match(err, 'n must be uint')
end

function testcase.write()
    local ncall = 0
    local msg = ''
    local w = writer.new({
        write = function(_, data)
            ncall = ncall + 1
            msg = msg .. data
            return #data
        end,
    })

    -- test that write data to buffer
    w:setbufsize(10)
    local len, err = w:write('hello')
    assert.equal(len, 5)
    assert.is_nil(err)
    assert.equal(w.buf, {
        'hello',
    })
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    len, err = w:write(' ')
    assert.equal(len, 1)
    assert.is_nil(err)
    assert.equal(w.buf, {
        'hello ',
    })
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    -- test that flush buffer if buffer size will be reaching the maxbufsize
    msg = ''
    len, err = w:write('world')
    assert.equal(len, 5)
    assert.is_nil(err)
    assert.equal(w.buf, {
        'world',
    })
    assert.equal(ncall, 1)
    assert.equal(msg, 'hello ')

    -- test that write directly to dst if s length is greater than maxbufsize
    ncall = 0
    msg = ''
    len, err = w:write('! ')
    assert.equal(len, 2)
    assert.is_nil(err)
    assert.equal(w.buf, {
        'world! ',
    })
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    len, err = w:write('foobarbazqux')
    assert.equal(len, 12)
    assert.is_nil(err)
    assert.empty(w.buf)
    assert.equal(ncall, 2)
    assert.equal(msg, 'world! foobarbazqux')

    -- test that write empty data
    ncall = 0
    msg = ''
    len, err = w:write('')
    assert.equal(len, 0)
    assert.is_nil(err)
    assert.equal(w.buf, {})
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    -- test that return error from dst
    w = writer.new({
        write = function()
            return nil, 'write-error'
        end,
    })
    w.buf = {
        'bar',
    }
    w.bufsize = 3
    w:setbufsize(0)
    len, err = w:write('foo')
    assert.is_nil(len)
    assert.equal(err, 'write-error')
    assert.equal(w.buf, {
        'bar',
    })

    -- test that throws an error with invalid argument
    for _, v in ipairs({
        true,
        1.1,
        -1,
        {},
        function()
        end,
        coroutine.create(function()
        end),
    }) do
        err = assert.throws(function()
            w:write(v)
        end)
        assert.match(err, 's must be string')
    end
end

function testcase.flush()
    local ncall = 0
    local msg = ''
    local w = writer.new({
        write = function(_, data)
            ncall = ncall + 1
            msg = msg .. string.sub(data, 1, 1)
            return 1
        end,
    })

    -- test that flush buffer
    w.buf = {
        'hello',
        ' ',
        'world!',
    }
    w.bufsize = #table.concat(w.buf)
    local nbyte = w.bufsize
    local len, err = w:flush()
    assert.equal(len, nbyte)
    assert.equal(w:flushed(), len)
    assert.is_nil(err)
    assert.equal(ncall, 12)
    assert.equal(w.buf, {})
    assert.equal(w:size(), 0)
    assert.equal(msg, 'hello world!')

    -- test that return 0 if no-buffers
    len, err = w:flush()
    assert.equal(len, 0)
    assert.is_nil(err)

    -- test that abort if writer returns no value
    w = writer.new({
        write = function()
            return nil, 'abort'
        end,
    })
    w.buf = {
        'hello',
    }
    len, err = w:flush()
    assert.is_nil(len)
    assert.equal(err, 'abort')
    assert.equal(w.buf, {
        'hello',
    })

    -- test that abort if writer returns multiple values
    ncall = 0
    w = writer.new({
        write = function()
            ncall = ncall + 1
            if ncall > 1 then
                return 1, nil, true
            end
            return 3
        end,
    })
    w.buf = {
        'hello',
    }
    local timeout
    len, err, timeout = w:flush()
    assert.equal(len, 4)
    assert.is_nil(err)
    assert.is_true(timeout)
    assert.equal(w.buf, {
        'o',
    })

    -- test that throws an error if a bytes written is greater than data size
    w = writer.new({
        write = function()
            return 100
        end,
    })
    w.buf = {
        'hello',
    }
    err = assert.throws(w.flush, w)
    assert.match(err, 'returned 100 greater than data size 5')

    -- test that return an error if dst returned invalid value type
    w = writer.new({
        write = function()
            return {}
        end,
    })
    w.buf = {
        'hello',
    }
    err = assert.throws(w.flush, w)
    assert.match(err, 'returned non-number value')
end

function testcase.writeout()
    local msg = ''
    local ncall = 0
    local w = writer.new({
        write = function(_, data)
            ncall = ncall + 1
            msg = msg .. data
            return #data
        end,
    })

    -- test that write directly to writer
    local len, err, timeout = w:writeout('foo')
    assert.equal(len, 3)
    assert.equal(w:flushed(), 0)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(w.buf, {})
    assert.equal(w:size(), 0)
    assert.equal(msg, 'foo')
    assert.equal(ncall, 1)

    -- test that abort if writer returns nil without error
    w = writer.new({
        write = function()
        end,
    })
    len, err = w:writeout('foo')
    assert.is_nil(len)
    assert.is_nil(err)

    -- test that abort if writer return an error
    w = writer.new({
        write = function(_, data)
            return #data, 'error'
        end,
    })
    len, err = w:writeout('foo')
    assert.is_nil(len)
    assert.equal(err, 'error')

    -- test that abort if writer return a timeout
    w = writer.new({
        write = function(_, data)
            return #data, nil, true
        end,
    })
    len, err, timeout = w:writeout('foo')
    assert.equal(len, 3)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that write empty-string
    ncall = 0
    len, err = w:writeout('')
    assert.equal(len, 0)
    assert.is_nil(err)
    assert.equal(ncall, 0)

    -- test that throws an error if s is not string
    err = assert.throws(w.writeout, w)
    assert.match(err, 's must be string')

    -- test that throws an error if writer returns <0
    w = writer.new({
        write = function()
            return -1
        end,
    })
    err = assert.throws(w.writeout, w, 'foo')
    assert.match(err, 'returned -1 less than 0')

    -- test that throws an error if writer returns 0 without error
    w = writer.new({
        write = function()
            return 0
        end,
    })
    err = assert.throws(w.writeout, w, 'foo')
    assert.match(err, 'returned 0 with not timeout')
end

function testcase.bytes_out()
    local msg = ''
    local ncall = 0
    local w = writer.new({
        write = function(_, data)
            ncall = ncall + 1
            msg = msg .. data
            return #data
        end,
    })

    -- test that update bytes_out counter
    local len, err, timeout = w:writeout('foo')
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(len, 3)
    assert.equal(w:bytes_out(), 3)

    -- test that did not count bytes_out if data is buffering in writer
    len, err, timeout = w:write('bar')
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(len, 3)
    assert.equal(w:bytes_out(), 3)

    -- test that update bytes_out counter if flush
    len, err = w:flush()
    assert.is_nil(err)
    assert.equal(len, 3)
    assert.equal(w:bytes_out(), 6)

    -- test that clear bytes_out counter
    assert.equal(w:bytes_out(true), 6)
    assert.equal(w:bytes_out(), 0)
end
