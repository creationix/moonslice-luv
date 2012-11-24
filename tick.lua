
local tickQueue = {}
local function tick() return function (callback)
  table.insert(tickQueue, callback)
end end

local function flushTickQueue()
  while #tickQueue > 0 do
    local queue = tickQueue
    tickQueue = {}
    for i, v in ipairs(queue) do
      v()
    end
  end
end

return {
  tick = tick,
  flushTickQueue = flushTickQueue
}
