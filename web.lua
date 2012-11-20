local newHttpParser = require('lhttp_parser').new
local parseUrl = require('lhttp_parser').parseUrl
local ReadableStream = require('continuable').ReadableStream
local table = require('table')

local web = {}

local STATUS_CODES = {
  [100] = 'Continue',
  [101] = 'Switching Protocols',
  [102] = 'Processing',                 -- RFC 2518, obsoleted by RFC 4918
  [200] = 'OK',
  [201] = 'Created',
  [202] = 'Accepted',
  [203] = 'Non-Authoritative Information',
  [204] = 'No Content',
  [205] = 'Reset Content',
  [206] = 'Partial Content',
  [207] = 'Multi-Status',               -- RFC 4918
  [300] = 'Multiple Choices',
  [301] = 'Moved Permanently',
  [302] = 'Moved Temporarily',
  [303] = 'See Other',
  [304] = 'Not Modified',
  [305] = 'Use Proxy',
  [307] = 'Temporary Redirect',
  [400] = 'Bad Request',
  [401] = 'Unauthorized',
  [402] = 'Payment Required',
  [403] = 'Forbidden',
  [404] = 'Not Found',
  [405] = 'Method Not Allowed',
  [406] = 'Not Acceptable',
  [407] = 'Proxy Authentication Required',
  [408] = 'Request Time-out',
  [409] = 'Conflict',
  [410] = 'Gone',
  [411] = 'Length Required',
  [412] = 'Precondition Failed',
  [413] = 'Request Entity Too Large',
  [414] = 'Request-URI Too Large',
  [415] = 'Unsupported Media Type',
  [416] = 'Requested Range Not Satisfiable',
  [417] = 'Expectation Failed',
  [418] = 'I\'m a teapot',              -- RFC 2324
  [422] = 'Unprocessable Entity',       -- RFC 4918
  [423] = 'Locked',                     -- RFC 4918
  [424] = 'Failed Dependency',          -- RFC 4918
  [425] = 'Unordered Collection',       -- RFC 4918
  [426] = 'Upgrade Required',           -- RFC 2817
  [500] = 'Internal Server Error',
  [501] = 'Not Implemented',
  [502] = 'Bad Gateway',
  [503] = 'Service Unavailable',
  [504] = 'Gateway Time-out',
  [505] = 'HTTP Version not supported',
  [506] = 'Variant Also Negotiates',    -- RFC 2295
  [507] = 'Insufficient Storage',       -- RFC 4918
  [509] = 'Bandwidth Limit Exceeded',
  [510] = 'Not Extended'                -- RFC 2774
}


function web.socketHandler(app) return function (client)

  local currentField, headers, url, request, done
  local parser
  parser = newHttpParser("request", {
    onMessageBegin = function ()
      headers = {}
    end,
    onUrl = function (value)
      url = parseUrl(value)
    end,
    onHeaderField = function (field)
      currentField = field
    end,
    onHeaderValue = function (value)
      headers[currentField:lower()] = value
    end,
    onHeadersComplete = function (info)
      request = info
      request.body = ReadableStream:new()
      request.url = url
      request.headers = headers
      request.parser = parser
      request.socket = client
      app(request, function (statusCode, headers, body)
        local reasonPhrase = STATUS_CODES[statusCode] or 'unknown'
        if not reasonPhrase then error("Invalid response code " .. tostring(statusCode)) end

        local head = {"HTTP/1.1 " .. tostring(statusCode) .. " " .. reasonPhrase .. "\r\n"}
        for key, value in pairs(headers) do
          table.insert(head, key .. ": " .. value .. "\r\n")
        end
        table.insert(head, "\r\n")
        local isStream = type(body) == "table" and type(body.read) == "function"
        if not isStream then
          if type(body) == "table" then
            for i, v in ipairs(body) do
              table.insert(head, body[i])
            end
          else
            table.insert(head, body)
          end

        end
        client:write(head)()
        if not isStream then
          done(info.should_keep_alive)
        else

          local function abort(err)
            client:write(tostring(err))(function ()
              done(false)
            end)
          end
          -- Assume it's a readable stream and pipe it to the client
          local function consume()
            local isAsync
            -- pump with trampoline in case of sync streams
            repeat
              isAsync = nil
              body:read()(function (err, chunk)
                if err then return abort(err) end
                if chunk then
                  client:write(chunk)()
                else
                  return done(info.should_keep_alive)
                end
                if isAsync == true then
                  -- It was async, so we need to start a new repeat loop
                  consume()
                elseif isAsync == nil then
                  -- It was sync, mark as sure
                  isAsync = false
                end
              end)
              -- read returned before calling the callback, it's async.
              if isAsync == nil then
                isAsync = true
              end
            until isAsync == true
          end
          consume()

        end
      end)
    end,
    onBody = function (chunk)
      request.body.inputQueue:push(chunk)
      request.body:processReaders()
    end,
    onMessageComplete = function ()
      request.body.inputQueue:push()
      request.body:processReaders()
    end
  })

  done = function(keepAlive)
    if keepAlive then
      parser:reinitialize("request")
    else
      client:write()(function (err)
        if (err) then error(err) end
        client:close()
      end)
    end
  end

  -- Consume the tcp stream and send it to the HTTP parser
  local function onRead(err, chunk)
    if (err) then error(err) end
    if chunk then
      if #chunk > 0 then
        local nparsed = parser:execute(chunk, 0, #chunk)
        -- TODO: handle various cases here
      end
      return client:read()(onRead)
    end
    parser:finish()
  end
  client:read()(onRead)

end end

return web
