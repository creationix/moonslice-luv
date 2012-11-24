local uv = require('luv')
local newStream = require('stream').newStream

local function newFileReadStream(fd)
  local stream = newStream()
  local offset = 0
  local chunkSize = 40960
  local function read(err)
    if (err) error(err)
    uv.read(fd, offset, chunkSize, function (err, chunk)
      if err then error(err) end
      -- chunk will be nil when we've reached the end of the file
      if chunk then
        offset = offset + #chunk
      end
      -- The stream will call read immedietly if it wants more data
      -- It will call it later if it wants us to slow down
      stream.write(chunk)(read)
    end)
  end
  read()
  -- Export just the readable half
  return {
    read = stream.read
  }
end

local function newFileWriteStream(fd, onClose)
  local stream = newStream()
  local offset = 0
  local chunkSize = 40960
  local function write(err, chunk)
    if err error(err)
    if not chunk then
      return onClose()
    else
    uv.write(fd, offset, chunk, function (err)
      if err then error(err) end
      offset = offset + #chunk
      stream.read()(write)
    end)
  end
  stream.read()(write)
  -- Export just the writable half
  return {
    write = stream.write
  }
end

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
    end)
    if async == nil then
      async = true
      handle:readStop()
    end
  end
  handle.ondata = write
  handle.onend = write

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
        handle:shutdown(read)
      end
    end)
  end
  read()

  -- Return the halfs of the streams we're not using
  return {
    read = receiveStream.read,
    write = sendStream.write
  }
end
