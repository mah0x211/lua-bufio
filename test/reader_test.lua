require('luacov')
local testcase = require('testcase')
local reader = require('bufio.reader')

function testcase.new()
    -- test that create bufio.reader with src with read method
    local r = reader.new({
        read = function()
        end,
    })
    assert.match(tostring(r), '^bufio.reader: ', false)

    -- test that throws an error with invalid src arguments
    for _, v in ipairs({
        true,
        0,
        function()
        end,
        coroutine.create(function()
        end),
    }) do
        local err = assert.throws(function()
            reader.new(v)
        end)
        assert.match(err, 'src must be table or userdata')
    end
    local err = assert.throws(function()
        reader.new()
    end)
    assert.match(err, 'src must be table or userdata')

    err = assert.throws(function()
        reader.new({})
    end)
    assert.match(err, 'src must have a read method')
end

function testcase.setbufsize()
    local r = reader.new({
        read = function()
        end,
    })

    -- test that set buffering size
    r:setbufsize(5)
    assert.equal(r.bufsize, 5)

    -- test that set nil to default buffering size
    r:setbufsize()
    assert.equal(r.bufsize, 4096)

    -- test that throws an error if invalid size
    local err = assert.throws(r.setbufsize, r, {})
    assert.match(err, 'n must be uint')
end

function testcase.prepend()
    local r = reader.new({
        read = function()
        end,
    })

    -- test that prepend string
    r:prepend('hello')
    assert.equal(r.buf, 'hello')
    r:prepend('world')
    assert.equal(r.buf, 'worldhello')

    -- test that throws an error with invalid argument
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
            r:prepend(v)
        end)
        assert.match(err, 's must be string')
    end
    local err = assert.throws(function()
        r:prepend()
    end)
    assert.match(err, 's must be string')
end

function testcase.read()
    local ncall = 0
    local msg = 'data from src.read'
    local r = reader.new({
        read = function()
            ncall = ncall + 1
            local s = msg
            msg = nil
            return s
        end,
    })
    r:prepend('foo bar baz qux')

    -- test that read cached data
    local data, err = r:read(5)
    assert.equal(data, 'foo b')
    assert.is_nil(err)

    -- test that read all cached data
    data = assert(r:read(10))
    assert.equal(data, 'ar baz qux')

    -- test that read data from src
    local n = #msg
    msg = msg .. '+extra data'
    data = assert(r:read(n))
    assert.equal(data, 'data from src.read')

    -- test that cache extra data
    data = assert(r:read(6))
    assert.equal(data, '+extra')
    assert.equal(ncall, 2)
    assert.equal(r.buf, ' data')

    -- test that read cached data
    data = assert(r:read(20))
    assert.equal(data, ' data')

    -- test that read data larger than bufsize
    msg = 'hello world'
    r = reader.new({
        read = function(_, nread)
            if #msg > 0 then
                local s = string.sub(msg, 1, nread)
                msg = string.sub(msg, nread + 1)
                return s
            end
        end,
    })
    r:setbufsize(5)
    data = assert(r:read(20))
    assert.equal(data, 'hello world')
    assert.equal(r.buf, '')

    -- test that return error from reader
    r = reader.new({
        read = function()
            return nil, 'read-error', false
        end,
    })
    local extra
    data, err, extra = r:read(6)
    assert.equal(data, '')
    assert.match(err, 'read-error')
    assert.is_false(extra)

    -- test that return an error if src return invalid data
    r = reader.new({
        read = function()
            return {}
        end,
    })
    data, err = r:read(1)
    assert.equal(data, '')
    assert.match(err, 'method returned a non-string value')

    -- test that return an error if src return a string larger than n
    r = reader.new({
        read = function()
            return 'hello world'
        end,
    })
    r:setbufsize(5)
    data, err = r:read(1)
    assert.equal(data, '')
    assert.match(err, 'method returned .+ larger than 5 bytes', false)

    -- test that throws an error if n is not greater than 0
    err = assert.throws(r.readin, r, 0)
    assert.match(err, 'n must be uint greater than 0')

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
            r:read(v)
        end)
        assert.match(err, 'n must be uint')
    end
end

function testcase.scan()
    local f = assert(io.tmpfile())
    f:write('hello\r\n')
    f:write('world\r\n')
    f:write('foo')
    f:seek('set')

    -- test that reads until the first occurrence of delimiter in the input
    local r = reader.new(f)
    local data, err = assert(r:scan('\n'))
    assert.equal(data, 'hello\r')
    assert.is_nil(err)

    -- test that treat delimiter as pattern string
    data = assert(r:scan('\r*\n', true))
    assert.equal(data, 'world')

    -- test that return nil if delimiter not found
    data, err = r:scan('\n')
    assert.is_nil(data)
    assert.is_nil(err)
    assert.equal(r:size(), 3)
    assert.equal(r:read(3), 'foo')
    f:close()

    -- test that throws an error if delimiter is invalid
    err = assert.throws(r.scan, r, {})
    assert.match(err, 'delim must be string')

    -- test that throws an error if is_pattern is invalid
    err = assert.throws(r.scan, r, '\n', {})
    assert.match(err, 'is_pattern must be boolean')
end

function testcase.readin()
    local msg = 'data from src.read'
    local r = reader.new({
        read = function(_, n)
            local s = string.sub(msg, 1, n)
            msg = string.sub(msg, n + 1)
            return s
        end,
    })

    -- test that read from reader
    local data, err, timeout = r:readin(5)
    assert.equal(data, 'data ')
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that abort if reader return empty-string
    data, err, timeout = r:readin(100)
    assert.equal(data, 'from src.read')
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that abort if reader return nil
    r = reader.new({
        read = function()
        end,
    })
    data, err, timeout = r:readin(5)
    assert.equal(data, '')
    assert.is_nil(timeout)
    assert.is_nil(err)

    -- test that return error if reader return a non-string value
    r = reader.new({
        read = function()
            return true
        end,
    })
    data, err, timeout = r:readin(5)
    assert.equal(data, '')
    assert.match(err, 'returned a non-string value')
    assert.is_nil(timeout)

    -- test that return error if reader returned a string is larger than n bytes
    r = reader.new({
        read = function(_, n)
            return string.rep('a', n + 1)
        end,
    })
    data, err, timeout = r:readin(5)
    assert.equal(data, '')
    assert.match(err, 'string larger than 5 bytes')
    assert.is_nil(timeout)

    -- test that throws an error if n is not greater than 0
    err = assert.throws(r.readin, r, 0)
    assert.match(err, 'n must be uint greater than 0')

    -- test that throws an error if n is not uint
    err = assert.throws(r.readin, r, true)
    assert.match(err, 'n must be uint')
end
