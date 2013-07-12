#!/usr/bin/lua

-- Workaround Lua module system for modules loaded by modules:
package.path = package.path .. ";lua-?/?.lua;lua-pwauth/?.lua"
package.cpath = package.cpath .. ";lua-?/?.so;lua-pwauth/lua-?/?.so"

local p = require('utils').prettyPrint
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
  res(200, {
    ["Content-Type"] = "text/plain"
  }, {"Hello ", "World\n"})
end

--local sasl = require("pwauth").sasl
--local provider = sasl.new{application="TEST", service="www", hostname="localhost", realm="TEST", mechanism=sasl.mechanisms.PLAIN}

local pam = require("pwauth").pam
local provider = pam.new("system-auth")

app = require("basic-auth")(app, {realm="TEST", provider=provider})

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
