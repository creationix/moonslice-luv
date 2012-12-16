return function (app, options)
	return function (req, res)
		app(req, function (code, headers, body)
			local errordocument = options[code]
			if errordocument then
				errordocument(code, headers, body, res)
			else
				res(code, headers, body)
			end
		end)
	end
end
