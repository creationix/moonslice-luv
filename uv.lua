local uv = require('luv')
local newPipe = require('stream').newPipe

local function noop() end
local continuable = {}

-- Handle is a uv_tcp_t instance from uv, it can be either client or server,
-- the API is the same
local function newHandleStream(handle)
  -- Get a duplex pipe from the stream library
  local internal, external = newPipe()
  -- Connect data coming from the socket to emit on the stream
  local function write(handle, chunk)
    -- If write doesn't callback sync, then we need to pause and resume the socket
    local async
    internal.write(chunk)(function (err)
      if err then error(err) end
      if async == nil then async = false end
      if async then
        uv.read_start(handle)
      end
    end)
    if async == nil then
      async = true
      uv.readStop(handle)
    end
  end
  handle.ondata = write
  handle.onend = write
  uv.read_start(handle)

  -- Connect data being written to the stream and write it to the handle
  local function read(err)
    if err then error(err) end
    local async
    internal.read()(function (err, chunk)
      if err then error(err) end
      if chunk then
        uv.write(handle, chunk, read)
      else
        uv.shutdown(handle, function ()
          uv.close(handle)
        end)
      end
    end)
  end
  read()

  external.address = uv.tcp_getpeername(handle)
  return external
end

function continuable.createServer(host, port, onConnection)
  local server = uv.new_tcp()
  uv.tcp_bind(server, host, port)
  function server:onconnection()
    local client = uv.new_tcp()
    uv.accept(server, client)
    onConnection(newHandleStream(client))
  end
  uv.listen(server)
  return server
end

function continuable.timeout(ms) return function (callback)
  local timer = uv.new_timer()
  timer.ontimeout = function ()
    callback()
    uv.close(timer)
  end
  uv.timer_start(timer, ms, 0)
  return timer
end end

function continuable.interval(ms) return function (callback)
  local timer = uv.new_timer()
  timer.ontimeout = callback
  uv.timer_start(timer, ms, ms)
  return timer
end end

local fs = {}
continuable.fs = fs
function fs.open(path, flags, mode) return function (callback)
  mode = mode or tonumber("666", 8)
  return uv.fs_open(path, flags, mode, callback)
end end

function fs.close(fd) return function (callback)
  return uv.fs_close(fd, callback or noop)
end end

function fs.stat(path) return function (callback)
  return uv.fs_stat(path, callback)
end end
function fs.fstat(fd) return function (callback)
  return uv.fs_fstat(fd, callback)
end end
function fs.lstat(path) return function (callback)
  return uv.fs_lstat(path, callback)
end end

function fs.read(path, length, offset) return function (callback)
  return uv.fs_read(path, length, offset, callback)
end end


return continuable
