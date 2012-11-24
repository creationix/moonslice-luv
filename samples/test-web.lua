local p = require('utils').prettyPrint
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('continuable').createServer
local websocket = require('websocket')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
--  p{req=req,res=res}
  if req.upgrade then
    local socket = websocket.upgrade(req)
    socket:on("message", function (message, head)
      p({
        message=message,
        opcode=head.opcode
      })
      socket:send("Hello " .. message)
    end)
    socket:on("end", function ()
      p("end")
    end)
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
