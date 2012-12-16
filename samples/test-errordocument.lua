local p = require('utils').prettyPrint
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer
local errhdl = require('errorhandlers')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local state = 1
local app = function (req, res)
  local code = 200
  if state > 3 then
    code = 404
  end

  res(code, {
    ["Content-Type"] = "text/plain"
  }, {"Hello ", "World ", tostring(state), "\n"})

  if req.url.path == "/" then
    state = state + 1
  end
end

app = require('error-document')(app, {
	[404] = errhdl.text("TEST 404"),
})

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

print("done.")
