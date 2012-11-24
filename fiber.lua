local coroutine = require('coroutine')
local debug = require('debug')

local fiber = {}

-- Map of managed coroutines
local fibers = {}

local function check(co, success, ...)
  local fiber = fibers[co]

  if not success then
    if fiber and fiber.callback then
      return fiber.callback(...)
    end
    error(err)
  end

  -- Abort on non-managed coroutines.
  if not fiber then
    return ...
  end

  -- If the fiber is done, pass the result to the callback and cleanup.
  if not fiber.paused then
    fibers[co] = nil
    if fiber.callback then
      fiber.callback(nil, ...)
    end
    return ...
  end

  fiber.paused = false
end

-- Create a managed fiber as a continuable
function fiber.new(fn, ...)
  local args = {...}
  local nargs = select("#", ...)
  return function (callback)
    local co = coroutine.create(fn)
    local fiber = {
      callback = callback
    }
    fibers[co] = fiber

    check(co, coroutine.resume(co, unpack(args, 1, nargs)))
  end
end

-- Wait in this coroutine for the continuation to complete
function fiber.wait(continuation)

  if type(continuation) ~= "function" then
    error("Continuation must be a function.")
  end

  -- Find out what thread we're running in.
  local co, isMain = coroutine.running()

  -- When main, Lua 5.1 `co` will be nil, lua 5.2, `isMain` will be true
  if not co or isMain then
    error("Can't wait from the main thread.")
  end

  local fiber = fibers[co]

  -- Execute the continuation
  local async, ret, nret
  continuation(function (...)

    -- If async hasn't been set yet, that means the callback was called before
    -- the continuation returned.  We should store the result and wait till it
    -- returns later on.
    if not async then
      async = false
      ret = {...}
      nret = select("#", ...)
      return
    end

    -- Callback was called we can resume the coroutine.
    -- When it yields, check for managed coroutines
    check(co, coroutine.resume(co, ...))

  end)

  -- If the callback was called early, we can just return the value here and
  -- not bother suspending the coroutine in the first place.
  if async == false then
    return unpack(ret, 1, nret)
  end

  -- Mark that the contination has returned.
  async = true

  -- Mark the fiber as paused if there is one.
  if fiber then fiber.paused = true end

  -- Suspend the coroutine and wait for the callback to be called.
  return coroutine.yield()
end

-- This is a wrapper around wait that strips off the first result and
-- interprets is as an error to throw.
function fiber.await(...)
  -- TODO: find out if there is a way to count the number of return values from
  -- fiber.wait while still storing the results in a table.
  local results = {fiber.wait(...)}
  local nresults = sel
  if results[1] then
    error(results[1])
  end
  return unpack(results, 2)
end

return fiber
