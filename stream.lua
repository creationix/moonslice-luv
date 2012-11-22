
local function newQueue()
  local head = {}
  local tail = {}
  local index = 1
  local headLength = 0
  local queue = {
    length = 0
  }

  function queue.shift()

    if index > headLength then
      -- When the head is empty, swap it with the tail to get fresh items
      head, tail = tail, head
      index = 1
      headLength = #head
      -- If it's still empty, return nothing
      if headLength == 0 then
        return
      end
    end

    -- There was an item in the head, let's pull it out
    local value = head[index]
    -- And remove it from the head
    head[index] = nil
    -- And bump the index
    index = index + 1
    queue.length = queue.length - 1
    return value

  end

  function queue.unshift()
    -- Insert the item at the front of the head queue
    headLength = headLength + 1
    return table.insert(head, 1, item)
  end

  function queue.push(item)
    -- Pushes always go to the write-only tail
    queue.length = queue.length + 1
    return table.insert(tail, item)
  end

  return queue
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
      local chunk = inputQueue.shift()
      local reader = readerQueue.shift()
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
    readerQueue.push(callback)
    processReaders()
  end end

  local function write(chunk) return function (callback)
    inputQueue.push(chunk)
    processReaders()
    if callback then
      if paused then
        table.insert(resumeList, callback)
      else
        callback()
      end
    end
  end end

  local function unshift(chunk)
    inputQueue.unshift(chunk)
    processReaders()
  end

  return {
    read = read,
    write = write,
    unshift = unshift
  }
end

return {
  newStream = newStream,
  newQueue = newQueue
}
