local p = require('utils').prettyPrint
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer
local fiber = require('fiber')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local tickQueue = {}
local function nextTick(fn)
  table.insert(tickQueue, fn)
end

local body = {
  "Hello ",
  "World ",
  "A very long chunk goes here to test multiple byte lengths",
  {"1","2","3"},
  "\n"
}

local app = function (req, res)
--  p{req=req,res=res}

  local stream = {}
  local index = 1
  function stream:read() return function (callback)
    -- Make the stream sometimes async and sometimes sync
    if index > 3 then
      nextTick(function ()
        callback(null, body[index])
        index = index + 1
      end)
    else
      callback(null, body[index])
      index = index + 1
    end
  end end

  res(200, {
    ["Content-Type"] = "text/plain"
  }, stream)
end

app = require('autoheaders')(app)

app = require('log')(app)

p{app=app}

app({
  method = "GET",
  url = { path = "/" },
  headers = {}
}, function (code, headers, body)
  fiber.new(function ()
    -- Log the response and body chunks
    p(code, headers, body)
    repeat
      local chunk = fiber.await(body:read())
      p(chunk)
    until not chunk
  end)()
end)

createServer(host, port, socketHandler(app))
print("http server listening at http://localhost:8080/")

repeat
  while #tickQueue > 0 do
    p("flushing nextTick queue of length", #tickQueue)
    local queue = tickQueue
    tickQueue = {}
    for i, v in ipairs(queue) do
      v()
    end
  end
  p("waiting for further events...")
until runOnce() == 0

--repeat
--  print(".\n")
--
print("done.")
