return function (app, pathfilter, f, ...)
	local f2 = f(app, ...)
	return function (req, res)
		if req.url.path:match(pathfilter) then
			f2(req, res)
		else
			app(req, res)
		end
	end
end
