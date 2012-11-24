local p = require('utils').prettyPrint
local dump = require('utils').dump
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer
local newStream = require('stream').newStream
local fiber = require('fiber')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
  fiber.new(function ()
    local parts = {}
    repeat
      local chunk = fiber.await(req.body.read())
      if chunk then
        table.insert(parts, chunk)
      end
    until not chunk
  p(parts)
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

local body = newStream()

app({
  method = "PUT",
  body = {read = body.read},
  url = { path = "/" },
  headers = {}
}, p)

body.write("Hello ")()
body.write("World\n")()
body.write()()

createServer(host, port, socketHandler(app))
print("http server listening at http://localhost:8080/")

repeat
  print(".\n")
until runOnce() == 0
print("done.")
