local p = require('utils').prettyPrint
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer
local websocket = require('websocket')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
--  p{req=req,res=res}
  if req.upgrade then
    local socket = websocket.upgrade(req)
    local function read()
      socket.read()(function (err, message)
        if err then error(err) end
        p(message)
        if message then
          socket.write("Hello " .. message)()
          read()
        else
          socket.write()()
        end
      end)
    end
    read()
    return
  end
  res(200, {
    ["Content-Type"] = "text/plain"
  }, {"Hello ", "World\n"})
end

app = require('autoheaders')(app)

app = require('log')(app)

p{app=app}

app({
  method = "GET",
  url = { path = "/" },
  headers = {}
}, p)

createServer(host, port, socketHandler(app))
print("http server listening at http://localhost:8080/")

require('luv').run()

--repeat
--  print(".\n")
--until runOnce() == 0
print("done.")
