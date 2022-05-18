# lua-bufio

[![test](https://github.com/mah0x211/lua-bufio/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-bufio/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-bufio/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-bufio)


buffered I/O module.


## Installation

```
luarocks install bufio
```

---

## bufio.Reader

## r = reader.new( src )

create a new bufio.Reader.

```lua
local reader = require('bufio.reader')

-- create with a lua file handle
local f = assert(io.tmpfile())
local r = reader.new(f)

-- create with a table that contains a read function
r = reader.new({
    -- a read must be the following function:
    --
    --   s:nil|string, err:any = read(self, n:uint)
    --
    -- the caller throws an error in the following cases:
    --
    --   * it returned non-nil s is not string.
    --   * it returned s length greater than n.
    --
    read = function(_, n)
        return 'hello', 'error'
    end
})
```

**Parameters**

- `src:table|userdata`: `table` or `userdata` with `read` method.

**Returns**

- `r:bufio.Reader`: an instance of `bufio.Reader`.


## Reader:setbufsize( [n] )

sets the buffer size.

```lua
local reader = require('bufio.reader')

local f = assert(io.tmpfile())
f:write('hello world')
f:seek('set')
local r = reader.new(f)

-- sets the buffer size to 3 bytes
r:setbufsize(3)

-- reads a string
print(r:read(3)) -- hel
-- size of bufferred string
print(r:size()) -- 0
```

**Parameters**

- `n:integer`: number of bytes (default: `4096`).


## n = Reader:size()

returns a size of buffered string.

```lua
local reader = require('bufio.reader')

local f = assert(io.tmpfile())
f:write('hello')
f:seek('set')
local r = reader.new(f)

-- reads a 1 bytes of string
print(r:read(1)) -- h
-- size of bufferred string
print(r:size()) -- 4
```

**Returns**

- `n:integer`: size of buffered string.


## Reader:prepend( s )

add `s` to the beginning of the buffer.

```lua
local reader = require('bufio.reader')
local f = assert(io.tmpfile())
f:write('hello world')
f:seek('set')
local r = reader.new(f)

-- reads up to 3 bytes of a string
local s = r:read(5)
print(s) -- hello
print(r:size()) -- 6

-- prepend a s to the buffer
r:prepend(s)
print(r:size()) -- 11

-- reads a string
print(r:read(20)) -- hello world
```

**Parameters**

- `n:integer`: number of bytes (default: `4096`).


## s, err = Reader:read( n )

reads up to `n` bytes of a string from the `src`.

```lua
local reader = require('bufio.reader')

local f = assert(io.tmpfile())
f:write('hello')
f:seek('set')
local r = reader.new(f)

-- reads up to 3 bytes of a string
-- actually, it reads `bufsize` bytes from `f` into a buffer and returns a 3-byte substring.
print(r:read(3)) -- hel
print(r:size()) -- 2 bytes buffered

-- reads remaining buffer string
print(r:read(10)) -- lo
```

**Parameters**

- `n:integer`: number of bytes to read.

**Returns**

- `s:string`: a string.
- `err:any`: a error value returned from `src`.


## s, err = Reader:scan( delim [, is_pattern] )

reads until the first occurrence of delimiter `delim` in the input from the `src`.

```lua
local format = string.format
local reader = require('bufio.reader')
local f = assert(io.tmpfile())
f:write('hello\n')
f:write('world\r\n')
f:write('foo\r\n')
f:write('bar')
f:seek('set')
local r = reader.new(f)

-- reads the first-line delimited by '\n'
local s = r:scan('\n')
print(format('%q', s)) -- 'hello'

-- reads the second-line delimited by '\n'
s = r:scan('\n')
print(format('%q', s)) -- 'world\r'

-- treat delimiter as a pattern string
s = r:scan('\r?\n', true)
print(format('%q', s)) -- 'foo'

-- no-match
s = r:scan('\n')
print(s) -- nil

print(r:read(10)) -- bar
```

**Parameters**

- `delim:string`: a delimiter string.
- `is_pattern:boolean`: `true` to treat a delimiter string as pattern string.

**Returns**

- `s:string`: a string.
- `err:any`: a error value returned from `src`.


## s, err = Reader:readin( n )

reads up to `n` bytes of a string from the `src` directly.

```lua
local reader = require('bufio.reader')

local f = assert(io.tmpfile())
f:write('hello')
f:seek('set')
local r = reader.new(f)

-- reads up to 3 bytes of a string
print(r:readin(3)) -- hel
print(r:size()) -- 0

-- reads remaining buffer string
print(r:readin(10)) -- lo
```

**Parameters**

- `n:integer`: number of bytes to read.

**Returns**

- `s:string`: a string.
- `err:any`: a error value returned from `src`.


***


## bufio.Writer

## w = writer.new( dst )

create a new bufio.Writer.

```lua
local writer = require('bufio.writer')

-- create with a lua file handle
local f = assert(io.tmpfile())
local w = writer.new(f)

-- create with a table that contains a write function
w = writer.new({
    -- a write must be the following function:
    --
    --   n:nil|uint, err:any = write(self, s:string)
    --
    -- the caller throws an error in the following cases:
    --
    --   * it returned n less than 0.
    --   * it returned n greater than #s.
    --   * it returned 0 without error when #s > 0.
    --
    write = function(_, s)
        return #s, 'error'
    end,
})
```

**Parameters**

- `src:table|userdata`: `table` or `userdata` with `write` method.

**Returns**

- `w:bufio.Writer`: an instance of `bufio.Writer`.


## Writer:setbufsize( [n] )

sets the buffer size.

```lua
local writer = require('bufio.writer')
local dst = {
    data = '',
    write = function(self, s)
        self.data = self.data .. s
        return #s
    end,
}
local w = writer.new(dst)

-- sets the buffer size to 3 bytes
w:setbufsize(3)

-- write a string to buffer
print(w:write('hello')) -- 5
print(w:size()) -- 0
print(w:flushed()) -- 5

-- flushed to dst
print(dst.data) -- 'hello'
```

**Parameters**

- `n:integer`: number of bytes (default: `4096`).


## n = Writer:size()

returns a size of buffered string.

**Returns**

- `n:integer`: size of buffered string.


## n = Writer:available()

returns a size of available buffer space.

```lua
local writer = require('bufio.writer')
local dst = {
    data = '',
    write = function(self, s)
        self.data = self.data .. s
        return #s
    end,
}
local w = writer.new(dst)

-- default buffer size is 4096
print(w:available()) -- 4096
-- write a string to buffer
print(w:write('hello')) -- 5
-- consumes 5 bytes of buffer space
print(w:available()) -- 4091
-- chage buffer size
w:setbufsize(8)
-- remaining available buffer space is 3 bytes
print(w:available()) -- 3
```

**Returns**

- `n:integer`: size of available buffer space.


## n = Writer:flushed()

returns a size of the string flushed to `dst`.

**Returns**

- `n:integer`: size of flushed string.


## len, err = Writer:flush()

flush the buffered strings to `dst`.

```lua
local writer = require('bufio.writer')
local dst = {
    data = '',
    write = function(self, s)
        self.data = self.data .. s
        return #s
    end,
}
local w = writer.new(dst)

-- write a string to buffer
print(w:write('hello')) -- 5
print(w:size()) -- 5

-- flush buffered strings
print(w:flush()) -- 5
print(w:size()) -- 0
print(w:flushed()) -- 5

print(dst.data) -- 'hello'
```

**Returns**

- `len:integer`: number of bytes flushed.
- `err:any`: an error value returned from `dst.write` method.


## len, err = Writer:write( s )

write a `s` to the buffer. when the buffer is full, the bufferred strings is automatically flushed to `dst`.

```lua
local dump = require('dump')
local writer = require('bufio.writer')
local dst = {
    data = {},
    write = function(self, s)
        self.data[#self.data + 1] = s
        return #s
    end,
}
local w = writer.new(dst)

-- write a string to buffer
print(w:write('hello')) -- 5
print(w:size()) -- 5
w:setbufsize(5)
-- this operation flushes buffer to dst
print(w:write('world')) -- 5
print(w:size()) -- 0

print(dump(dst.data))
-- {
--     [1] = "hello",
--     [2] = "world"
-- }
```

**Parameters**

- `s:string`: a string.

**Returns**

- `len:integer`: number of bytes written.
- `err:any`: an error value returned from `dst.write` method.


## len, err, ... = Writer:writeout( s )

write a `s` directly to the `dst`.

```lua
local dump = require('dump')
local writer = require('bufio.writer')
local dst = {
    data = {},
    write = function(self, s)
        self.data[#self.data + 1] = s
        return #s
    end,
}
local w = writer.new(dst)

-- write a string to buffer
print(w:writeout('hello')) -- 5
print(w:size()) -- 0

print(dump(dst.data))
-- {
--     [1] = "hello",
-- }
```

**Parameters**

- `s:string`: a string.

**Returns**

- `len:integer`: number of bytes written.
- `err:any`: an error value returned from `dst.write` method.
