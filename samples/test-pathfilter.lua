local p = require('utils').prettyPrint
local socketHandler = require('web').socketHandler
local createServer = require('uv').createServer
local pflt = require('utils.path-filter')

local host = os.getenv("IP") or "0.0.0.0"
local port = os.getenv("PORT") or 8080

local app = function (req, res)
  res(200, {
    ["Content-Type"] = "text/plain"
  }, {"Hello ", "World\n"})
end

app = require('path-filter')(app, pflt.equal("/f"), function (app)
	return function(req, res)
		res(404, {}, {"Bam!"})
	end
end)

app = require('path-filter')(app, pflt.notmatch("/f"), function (app)
	return function(req, res)
		res(403, {}, {"Bingo!"})
	end
end)

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

require('luv').run('default')

print("done.")
