local errordocument = {}

function errordocument.text(text)
	return function (code, headers, body, res)
		res(code, headers, text)
	end
end

function errordocument.file(path)
	return function (code, headers, body, res)
		local file = io.open(path)
		body = file:read("*a")
		res(code, headers, body)
	end
end

function errordocument.execute(path)
	return function (code, headers, body, res)
		local chunk = loadfile(path)
		local success, err = pcall(chunk, code, headers, body, res)
		if not success then
			error("Failed to execute error document handler: " .. err)
			res(code, headers, body)
		end
	end
end

function errordocument.redirect(url)
	return function (code, headers, body, res)
		code = 302
		headers["Location"] = url
		res(code, headers, {})
	end
end

return errordocument
