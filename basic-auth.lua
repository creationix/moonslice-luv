local base64 = require "base64"

return function (app, options)
	return function (req, res)
		if req.url.path == options.path then
			local authorization = req.headers.authorization
			if not authorization then
				return res(401,{["Content-Type"] = "text/plain", ["WWW-Authenticate"] = "Basic realm="..options.realm},"Please auth!")
			end

			local userpass_b64 = authorization:match("Basic%s+(.*)")
			if not userpass_b64 then
				return res(400, {["Content-Type"] = "text/plain"}, "Your browser sent a bad Authorization HTTP header!")
			end

			local userpass = base64.decode(userpass_b64)
			if not userpass then
				return res(400, {["Content-Type"] = "text/plain"}, "Your browser sent a bad Authorization HTTP header!")
			end

			local username, password = userpass:match("([^:]*):(.*)")
			if not (username and password) then
				return res(400, {["Content-Type"] = "text/plain"}, "Your browser sent a bad Authorization HTTP header!")
			end

			local success, err = options.provider:authenticate(username, password)
			if not success then
				return res(403,{["Content-Type"] = "text/plain", ["WWW-Authenticate"] = "Basic realm="..options.realm},"<html><body><h1>Auth failed!</h1><p>"..err.."</p></body></html>")
			end
		end

		app(req, res)
	end
end
