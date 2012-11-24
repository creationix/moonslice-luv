local stringFormat = require('string').format
local osDate = require('os').date

return function (app, options)
  if not options then
    options = {}
  end
  if options.autoServer == nil then
    options.autoServer = "MoonSlice " .. _VERSION
  end
  if options.autoDate == nil then
    options.autoDate = true
  end
  if options.autoChunkedEncoding == nil then
    options.autoChunkedEncoding = true
  end
  if options.autoContentLength == nil then
    options.autoContentLength = true
  end
  return function (req, res)
    if req.headers.expect == "100-continue" then
      req.socket:write("HTTP/1.1 100 Continue\r\n\r\n")()
    end
    app(req, function (code, headers, body)
      local hasDate = false
      local hasServer = false
      local hasContentLength = false
      local hasTransferEncoding = false
      for name, value in pairs(headers) do
        if type(name) == "number" then
          local a, b
          a, b, name = value:find("([^:]*)")
        end
        name = name:lower()
        if name == "date" then hasDate = true end
        if name == "server" then hasServer = true end
        if name == "content-length" then hasContentLength = true end
        if name == "transfer-encoding" then hasTransferEncoding = true end
      end
      if not hasDate and options.autoDate then
        headers['Date'] = osDate("!%a, %d %b %Y %H:%M:%S GMT")
      end
      if not hasServer and options.autoServer then
        headers['Server'] = options.autoServer
      end
      if body and (not hasContentLength) and (not hasTransferEncoding) then
        local isStream = type(body) == "table" and type(body.read) == "function"
        if not isStream and options.autoContentLength then
          if type(body) == "table" then
            local length = 0
            for i, v in ipairs(body) do
              length = length + #v
            end
            headers["Content-Length"] = length
          else
            headers["Content-Length"] = #body
          end
          hasContentLength = true
        end

        if not hasContentLength and options.autoChunkedEncoding then
          headers["Transfer-Encoding"] = "chunked"
          hasTransferEncoding = true
          if not isStream then
            if type(body) == "table" then
              local length = 0
              for i, v in ipairs(body) do
                length = length + #v
              end
              table.insert(body, 1, stringFormat("%X\r\n", length))
              table.insert(body, "\r\n0\r\n\r\n")
            else
              body = {
                stringFormat("%X\r\n", #body),
                body,
                "\r\n0\r\n\r\n"
              }
           end
          else
            local originalStream = body
            local done = false
            body = {}
            -- http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1
            function body:read() return function (callback)
              if done then
                return callback()
              end
              originalStream:read()(function (err, chunk)
                if err then return callback(err) end
                if chunk then
                  local parts = {}
                  if type(chunk) == "table" then
                    local length = 0
                    for i, v in ipairs(chunk) do
                      length = length + #v
                    end
                    table.insert(parts, stringFormat("%X\r\n", length))
                    for i, v in ipairs(chunk) do
                      table.insert(parts, v)
                    end
                  else
                    table.insert(parts, stringFormat("%X\r\n", #chunk))
                    table.insert(parts, chunk)
                  end
                  table.insert(parts, "\r\n")
                  return callback(nil, parts)
                end
                done = true
                -- This line is last-chunk, an empty trailer, and CRLF combined
                callback(nil, "0\r\n\r\n")
              end)
            end end
          end
        end

      end
      if req.should_keep_alive and (hasContentLength or hasTransferEncoding or code == 304) then
        headers["Connection"] = "keep-alive"
      else
        headers["Connection"] = "close"
        req.should_keep_alive = false
      end
      res(code, headers, body)
    end)
  end
end
