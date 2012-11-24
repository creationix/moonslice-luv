Moonslice is a collection of interfaces and lua libraries.

It's a mix of the code and technology from the luvit project mixed with some
new experimental APIs that are designed to make it more lua friendly and easier
to code.

Two external dependencies are `luv` and `lhttp_parser`.  The first is a new set
of lua - libuv bindings designed to be standalone, minimal and fast.  The latter
is the http_parser bindings used in luvit, but packaged as a standalone project.

Included in this directory is a `Makefile` that pulls in the gitsubmodules and
builds the two libraries.  The respective libraries that use them have symlinks
in place already.

# Continuable

This is a collection of libraries that implement the continuable interface.

In short, the continuable interface is like node.js style callbacks except the
function that accepts the callback is returned from the initial function call
as a continuable closure.

```lua
fs.readFile("/path/to/file.txt")(function (err, contents)
  ...
end)
```

# Continuable.stream

This library contains the stream implementation.  It's a simple queue where
writes to one end come out in reads to the other end.  Built-in is backpressure
and controlled buffering via low-water and high-water marks for full proper
flow-control.

The streams have only `.read()` and `.write()` continuable style functions.
They are mobile and can be moved around at will as seen in this example for
creating a duplex pipe with a stream at each end.

```lua
local function newPipe()
  -- Create two streams
  local a, b = newStream(), newStream()
  -- Cross their write functions
  a.write, b.write = b.write, a.write
  -- Return them as two duplex streams that are the two ends of the pipe
  return a, b
end
```

# Web

This library is a new web interface.  Web consumes a raw http stream (usually
over TCP, but any stream will do) and a web `app`.  It parses HTTP requests on
the stream and calls the app function.  When the app function responds, it
writes the corresponding HTTP data to the socket.

```lua
local function app(req, res)
  res(200, {
    ["Content-Type"] = "text/plain"
  }, "Hello World\n")
end
```

## Web.autoheaders

This middleware wraps around any web app and adds in all sorts of useful spec
adherence.  It does useful things like auto Content-Length header.  Also it can
do chunked encoding on the body stream if it's unable to calculate the length.

```lua
-- Just wrap your app in autoheaders to get a new app
app = autoheaders(app)
```

## Web.log

A very simple middleware to log HTTP requests.

```lua
-- Just wrap your app in autoheaders to get a new app
app = log(app)
```

## Web.websocket

**TODO**: Finish implementing this API

A sample websocket implementation to prove that web is capable of handling HTTP
upgrades.

```lua
local app = function (req, res)
  if not req.upgrade then
    res(400, {}, "Websocket only\n")
  end
  local socket = websocket.upgrade(req)
  repeat
    local message, head = await(socket.read())
    p({
      message=message,
      opcode=head.opcode
    })
    socket.write("Hello " .. message)()
  until not message
end
```

## Web.gzip

**TODO**: Implement this

A middleware to gzip body streams.  This is just an example of how this would be
done.  I think I'll implement it using FFI calls to zlib.