
local Queue = {}
-- Get an item from the font of the queue
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

-- Put an item back on the queue
function Queue:unshift(item)
    self.headLength = self.headLength + 1
    return table.insert(self.head, 1, item)
end

-- Push a new item on the back of the queue
function Queue:push(item)
    -- Pushes always go to the write-only tail
    self.length = self.length + 1
    return table.insert(self.tail, item)
end

function Queue:initialize()
end

local metaQueue = {__index=Queue}

local function newQueue()
  return setmetatable({
    head = {},
    tail = {},
    index = 1,
    headLength = 0,
    length = 0
  }, metaQueue)
end


local function newStream()

  -- If there are more than this many buffered input chunks, readStop the source
  local highWaterMark = 1
  -- If there are less than this many buffered chunks, readStart the source
  local lowWaterMark = 1

  local paused = false
  local processing = false

  local inputQueue = newQueue()
  local readerQueue = newQueue()
  local resumeList = {}

  local function processReaders()
    if processing then return end
    processing = true
    while inputQueue.length > 0 and readerQueue.length > 0 do
      local chunk = inputQueue:shift()
      local reader = readerQueue:shift()
      reader(nil, chunk)
    end
    local watermark = inputQueue.length - readerQueue.length
    if not paused then
      if watermark > highWaterMark then
        paused = true
      end
    else
      if watermark < lowWaterMark then
        paused = false
        if #resumeList > 0 then
          local callbacks = resumeList
          resumeList = {}
          for i = 1, #callbacks do
            callbacks[i]()
          end
        end
      end
    end
    processing = false
  end

  local function read() return function (callback)
    readerQueue:push(callback)
    processReaders()
  end end

  local function write(chunk) return function (callback)
    inputQueue:push(chunk)
    processReaders()
    if callback then
      if paused then
        table.insert(resumeList, callback)
      else
        callback()
      end
    end
  end end

  return {
    read = read,
    write = write
  }
end

local function newPipe()
  -- Create two streams
  local a, b = newStream(), newStream()
  -- Cross their write functions
  a.write, b.write = b.write, a.write
  -- Return them as two duplex streams that are the two ends of the pipe
  return a, b
end


return {
  newStream = newStream,
  newPipe = newPipe
}
