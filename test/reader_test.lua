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
    assert.equal(r.maxbufsize, 5)

    -- test that set nil to default buffering size
    r:setbufsize()
    assert.equal(r.maxbufsize, 4096)

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
            return msg
        end,
    })
    r:prepend('foo bar baz qux')

    -- test that read cached data
    local data, err = r:read(5)
    assert.equal(data, 'foo b')
    assert.is_nil(err)

    -- test that read empty-data
    data = assert(r:read(0))
    assert.equal(data, '')

    -- test that read all cached data
    data = assert(r:read())
    assert.equal(data, 'ar baz qux')

    -- test that read data from src
    data = assert(r:read())
    assert.equal(data, 'data from src.read')
    assert.equal(ncall, 1)

    -- test that cache extra data
    data = assert(r:read(5))
    assert.equal(data, string.sub(msg, 1, 5))
    assert.equal(ncall, 2)
    assert.equal(r.buf, string.sub(msg, 6))

    -- test that read cached data
    data = assert(r:read(20))
    assert.equal(data, string.sub(msg, 6))
    assert.equal(ncall, 2)

    -- test that read data larger than bufsize
    r = reader.new({
        read = function()
            return 'hello world'
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
    data, err, extra = r:read()
    assert.is_nil(data)
    assert.match(err, 'read-error')
    assert.is_false(extra)

    -- test that throws an error if src return invalid data
    r = reader.new({
        read = function()
            return {}
        end,
    })
    err = assert.throws(r.read, r)
    assert.match(err, 'method returned an invalid string')

    -- test that throws an error if src return invalid data
    r = reader.new({
        read = function()
            return 'hello world'
        end,
    })
    r:setbufsize(5)
    err = assert.throws(r.read, r)
    assert.match(err, 'method returned a string .+ larger than 5 bytes', false)

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
    assert.equal(r:read(), 'foo')
    f:close()

    -- test that throws an error if delimiter is invalid
    err = assert.throws(r.scan, r, {})
    assert.match(err, 'delim must be string')

    -- test that throws an error if is_pattern is invalid
    err = assert.throws(r.scan, r, '\n', {})
    assert.match(err, 'is_pattern must be boolean')
end

