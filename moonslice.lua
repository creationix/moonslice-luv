local newFiber = require('fiber').new
local wait = require('fiber').wait
local fs = require('uv').fs
local websocket = require('websocket')
local sendFile = require('send').file
local numToBase= require('send').numToBase

local App = {}

function App:get(path, fn)
  table.insert(self, {function (req)
    return req.method == "GET" and req.url.path:match(path)
  end, fn, "get " .. path})
end

function App:post(path, fn)
  table.insert(self, {function (req)
    return req.method == "POST" and req.url.path:match(path)
  end, fn, "post " .. path})
end

function App:put(path, fn)
  table.insert(self, {function (req)
    return req.method == "PUT" and req.url.path:match(path)
  end, fn, "put " .. path})
end

function App:delete(path, fn)
  table.insert(self, {function (req)
    return req.method == "DELETE" and req.url.path:match(path)
  end, fn, "delete " .. path})
end

function App:websocket(path, fn)
  table.insert(self, {function (req)
    return req.upgrade and req.url.path:match(path)
  end, function (req, res)
    fn(req, websocket.upgrade(req))
  end, "websocket " .. path})
end

function App:static(root, options)
  table.insert(self, {function (req)
    if not(req.method == "GET" or req.method == "HEAD") then
      return false
    end
    if options.index and req.url.path:sub(#req.url.path) == "/" then
      req.url.path = req.url.path .. options.index
    end
    local path = root .. req.url.path
    local err, stat = wait(fs.stat(path))
    return stat and stat.is_file
  end, function (req, res)
    local path = root .. req.url.path
    sendFile(path, req, res)
  end, "static " .. root})
end

--------------------------------------------------------------------------------

local appMeta = { __index = App }

local index = 0
function appMeta:__call(req, res)
  local id
  if self.log then
    index = index + 1
    id = numToBase(index, 64)
    local realRes = res
    res = function (code, headers, body)
      print("-> " .. id  .. " " .. code)
      realRes(code, headers, body)
    end
  end
  newFiber(function()
    if id then
      local address = req.socket.address.address .. ":" .. req.socket.address.port
      print("<- " .. id  .. " " .. req.method .. " " .. req.url.path .. " " .. address)
    end
    for i, pair in ipairs(self) do
      if pair[1](req) then
        if id then
          print("-- " .. id  .. " " .. pair[3])
        end
        return pair[2](req, res)
      end
    end
    return res(404, {}, "")
  end)(function (err)
    if err then
      err = tostring(err) .. "\n"
      io.stderr:write(err)
      return res(500, {
        ["Content-Length"] = #err,
        ["Content-Type"] = "text/plain"
      }, err)
    end
  end)
end

return function ()
  return setmetatable({}, appMeta)
end
