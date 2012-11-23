local uv = require('luv')
local newStream = require('stream').newStream

local function noop() end
local continuable = {}

-- Handle is a uv_tcp_t instance from uv, it can be either client or server,
-- the API is the same
local function newHandleStream(handle)

  -- Connect data coming from the socket to emit on the stream
  local receiveStream = newStream()
  local function write(handle, chunk)
    -- If write doesn't callback sync, then we need to pause and resume the socket
    local async
    receiveStream.write(chunk)(function (err)
      if err then error(err) end
      if async == nil then async = false end
      if async then
        handle:readStart()
      end
    end)
    if async == nil then
      async = true
      handle:readStop()
    end
  end
  handle.ondata = write
  handle.onend = write
  handle:readStart()

  -- Connect data being written to the stream and write it to the handle
  local sendStream = newStream()
  local function read(err)
    if err then error(err) end
    local async
    sendStream.read()(function (err, chunk)
      if err then error(err) end
      if chunk then
        handle:write(chunk, read)
      else
        handle:shutdown(function ()
          handle:close()
        end)
      end
    end)
  end
  read()

  -- Return the halfs of the streams we're not using
  return {
    read = receiveStream.read,
    unshift = receiveStream.unshift,
    write = sendStream.write
  }
end

function continuable.createServer(host, port, onConnection)
  local server = uv.newTcp()
  server:bind(host, port)
  function server:onconnection()
    local client = uv.newTcp()
    server:accept(client)
    onConnection(newHandleStream(client))
  end
  server:listen()
  return server
end

function continuable.timeout(ms) return function (callback)
  local timer = uv.newTimer()
  timer.ontimeout = function ()
    callback()
    timer:close()
  end
  timer:start(ms, 0)
end end

local tickQueue = {}
function continuable.nextTick() return function (callback)
  table.insert(tickQueue, callback)
end end

function continuable.flushTickQueue()
  while #tickQueue > 0 do
    local queue = tickQueue
    tickQueue = {}
    for i, v in ipairs(queue) do
      v()
    end
  end
end

return continuable
