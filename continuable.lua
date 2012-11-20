local uv = require('luv')
local Object = require('core').Object
local table = require('table')

local function noop() end
local continuable = {}

local Queue = Object:extend()
continuable.Queue = Queue

function Queue:initialize()
  self.head = {}
  self.tail = {}
  self.index = 1
  self.headLength = 0
  self.length = 0
end

function Queue:shift()
  if self.index > self.headLength then
    -- When the head is empty, swap it with the tail to get fresh items
    self.head, self.tail = self.tail, self.head
    self.index = 1
    self.headLength = #self.head
    -- If it's still empty, return nothing
    if self.headLength == 0 then
      return
    end
  end

  -- There was an item in the head, let's pull it out
  local value = self.head[self.index]
  -- And remove it from the head
  self.head[self.index] = nil
  -- And bump the index
  self.index = self.index + 1
  self.length = self.length - 1
  return value
end

function Queue:push(item)
  -- Pushes always go to the write-only tail
  self.length = self.length + 1
  return table.insert(self.tail, item)
end

local ReadableStream = Object:extend()
continuable.ReadableStream = ReadableStream

-- If there are more than this many buffered input chunks, readStop the source
ReadableStream.highWaterMark = 1
-- If there are less than this many buffered chunks, readStart the source
ReadableStream.lowWaterMark = 1

function ReadableStream:initialize()
  self.inputQueue = Queue:new()
  self.readerQueue = Queue:new()
end

function ReadableStream:read() return function (callback)
  self.readerQueue:push(callback)
  self:processReaders()
end end

function ReadableStream:processReaders()
  while self.inputQueue.length > 0 and self.readerQueue.length > 0 do
    local chunk = self.inputQueue:shift()
    local reader = self.readerQueue:shift()
    reader(nil, chunk)
  end
  local watermark = self.inputQueue.length - self.readerQueue.length
  if watermark > self.highWaterMark and not self.paused then
    self.paused = true
    self:pause()
  elseif watermark < self.lowWaterMark and self.paused then
    self.paused = false
    self:resume()
  end
end

local TcpStream = ReadableStream:extend()
continuable.TcpStream = TcpStream

function TcpStream:initialize(handle)
  self.handle = handle
  -- Readable stuff
  ReadableStream.initialize(self)
  handle.ondata = function (handle, chunk)
    self.inputQueue:push(chunk)
    self:processReaders()
  end
  handle.onend = function (handle)
    self.inputQueue:push()
    self:processReaders()
  end
  handle:readStart()
end

--[[function TcpStream:close() return function (callback)
  self.handle:close()
end end]]
function TcpStream:close()
  return self.handle:close()
end

function TcpStream:resume()
  return self.handle:readStart()
end

function TcpStream:pause()
  return self.handle:readStop()
end

function TcpStream:write(chunk) return function (callback)
  if chunk then
    return self.handle:write(chunk, callback)
  end
  return self.handle:shutdown(callback)
end end

function continuable.createServer(host, port, onConnection)
  local server = uv.newTcp()
  server:bind(host, port)
  function server:onconnection()
    local client = uv.newTcp()
    server:accept(client)
    onConnection(TcpStream:new(client))
  end
  server:listen()
  return server
end

return continuable
