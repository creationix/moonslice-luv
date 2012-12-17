return function (app, pathfilter, f, ...)
	local f2 = f(app, ...)
	return function (req, res)
		if pathfilter(req.url.path) then
			f2(req, res)
		else
			app(req, res)
		end
	end
end
