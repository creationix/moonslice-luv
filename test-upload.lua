local p = require('utils').prettyPrint
local dump = require('utils').dump
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('continuable').createServer
local ReadableStream = require('continuable').ReadableStream
local fiber = require('fiber')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
  fiber.new(function ()
    local parts = {}
    repeat
      local chunk = fiber.await(req.body:read())
      if chunk then
        table.insert(parts, chunk)
      end
    until not chunk
    req.body = parts
    local body = dump(req) .. "\n"
    res(200, {
      ["Content-Type"] = "text/plain"
    }, body)
  end)(function (err)
    if err then
      res(500, {
        ["Content-Type"] = "text/plain"
      }, err)
    end
  end)
end

app = require('autoheaders')(app)

app = require('log')(app)

p{app=app}

local body = ReadableStream:new()

app({
  method = "PUT",
  body = body,
  url = { path = "/" },
  headers = {}
}, p)

body.inputQueue:push("Hello ")
body:processReaders()

body.inputQueue:push("World\n")
body:processReaders()

body.inputQueue:push()
body:processReaders()

createServer(host, port, socketHandler(app))
print("http server listening at http://localhost:8080/")

require('luv').run()

--repeat
--  print(".\n")
--until runOnce() == 0
print("done.")
