return function (app, pathfilter, f, ...)
	local f2 = f(app, ...)
	return function (req, res)
		local doit
		if type(pathfilter) == "string" then
			doit = req.url.path == pathfilter
		elseif type(pathfilter) == "function" then
			doit = pathfilter(req.url.path)
		elseif type(pathfilter) == "table" then
			local compstr, filter = pathfilter[1], pathfilter[2]
			if compstr == "equal" then
				doit = req.url.path == filter
			elseif compstr == "notequal" then
				doit = req.url.path ~= filter
			elseif compstr == "match" then
				doit = req.url.path:match(filter)
			elseif compstr == "notmatch" then
				doit = not req.url.path:match(filter)
			else
				error("Unsupported comparison type: " .. compstr)
			end
		else
			error("Unsupported filter: " .. pathfilter)
		end

		if doit then
			f2(req, res)
		else
			app(req, res)
		end
	end
end
