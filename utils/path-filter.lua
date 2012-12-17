local pathfilter = {}

function pathfilter.equal(path)
	return function (urlpath)
		return urlpath == path
	end
end

function pathfilter.notequal(path)
	return function (urlpath)
		return urlpath ~= path
	end
end

function pathfilter.match(path)
	return function (urlpath)
		return urlpath:match(path)
	end
end

function pathfilter.notmatch(path)
	return function (urlpath)
		return not urlpath:match(path)
	end
end

return pathfilter
