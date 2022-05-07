require('luacov')
local testcase = require('testcase')
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
        function()
        end,
        coroutine.create(function()
        end),
    }) do
        local err = assert.throws(function()
            writer.new(v)
        end)
        assert.match(err, 'dst must be table or userdata')
    end
    local err = assert.throws(function()
        writer.new()
    end)
    assert.match(err, 'dst must be table or userdata')

    err = assert.throws(function()
        writer.new({})
    end)
    assert.match(err, 'dst must have a write method')
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
    local len, err, timeout = w:write('hello')
    assert.equal(len, 5)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(w.buf, {
        'hello',
    })
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    -- test that flush buffer when buffer size reaches a maxbufsize
    msg = ''
    len, err, timeout = w:write('world')
    assert.equal(len, 10)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(w.buf, {})
    assert.equal(ncall, 1)
    assert.equal(msg, 'helloworld')

    -- test that write empty data
    ncall = 0
    msg = ''
    len, err, timeout = w:write('')
    assert.equal(len, 0)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(w.buf, {})
    assert.equal(ncall, 0)
    assert.equal(msg, '')

    -- test that return error from dst
    w = writer.new({
        write = function()
            return nil, 'write-error', true
        end,
    })
    w.buf = {
        'bar',
    }
    w.bufsize = 3
    w:setbufsize(0)
    len, err, timeout = w:write('foo')
    assert.is_nil(len)
    assert.equal(err, 'write-error')
    assert.equal(w.buf, {
        'bar',
    })
    assert.is_true(timeout)

    w.buf = {}
    len, err, timeout = w:write('foo')
    assert.is_nil(len)
    assert.equal(err, 'write-error')
    assert.is_true(timeout)
    assert.equal(w.buf, {
        'foo',
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
    local len, err, timeout = w:flush()
    assert.equal(len, nbyte)
    assert.equal(w:flushed(), len)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(ncall, 12)
    assert.equal(w.buf, {})
    assert.equal(w:size(), 0)
    assert.equal(msg, 'hello world!')

    -- test that abort if writer returns no value
    w = writer.new({
        write = function()
        end,
    })
    w.buf = {
        'hello',
    }
    len, err, timeout = w:flush()
    assert.is_nil(len)
    assert.is_nil(err)
    assert.is_nil(timeout)
    assert.equal(w.buf, {
        'hello',
    })

    -- test that abort if writer returns multiple values
    ncall = 0
    w = writer.new({
        write = function()
            ncall = ncall + 1
            if ncall > 1 then
                return 1, 'error', false
            end
            return 3
        end,
    })
    w.buf = {
        'hello',
    }
    len, err, timeout = w:flush()
    assert.equal(len, 4)
    assert.equal(err, 'error')
    assert.is_false(timeout)
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
    assert.match(err, 'method returned a number of bytes written greater than 5')

    -- test that throws an error if dst returned invalid value type
    w = writer.new({
        write = function()
            return {}
        end,
    })
    w.buf = {
        'hello',
    }
    err = assert.throws(w.flush, w)
    assert.match(err, 'method returned an invalid number of bytes written')
end

function testcase.writeout()
    local msg = ''
    local w = writer.new({
        write = function(_, data)
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

    -- test that abort if writer returns 0
    w = writer.new({
        write = function()
            return 0
        end,
    })
    len, err, timeout = w:writeout('foo')
    assert.is_nil(len)
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that abort if writer returns multiple values
    w = writer.new({
        write = function(_, data)
            return #data, 'error', true
        end,
    })
    len, err, timeout = w:writeout('foo')
    assert.equal(len, 3)
    assert.equal(err, 'error')
    assert.is_true(timeout)
end

