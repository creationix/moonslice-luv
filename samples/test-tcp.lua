local p = require('utils').prettyPrint
local run = require('luv').run
local createServer = require('uv').createServer
local fiber = require('fiber')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

-- Implement a simple echo server
createServer(host, port, function (client)
  fiber.new(function ()
    repeat
      local chunk = fiber.await(client.read())
      fiber.await(client.write(chunk))
    until not chunk
  end)()
end)
print("tcp echo server listening at port " .. port)

run('default')
