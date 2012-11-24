local p = require('utils').prettyPrint
local runOnce = require('luv').runOnce
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
--  p{req=req,res=res}
  res(200, {
    ["Content-Type"] = "text/plain"
  }, "Hello World\n")
end

app = require('autoheaders')(app)

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
