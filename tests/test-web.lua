local web = require('web')
local newStream = require('stream').newStream
local await = require('fiber').await
local p = require('utils').prettyPrint
local describe = require('ensure').describe
local same = require('ensure').same

local function newPipe()
  local a = newStream()
  local b = newStream()
  return { write = a.write, read = b.read }, { write = b.write, read = a.read }
end

describe("web", function ()

  it("should have a socketHandler function", function (done)
    assert(type(web) == "table")
    assert(type(web.socketHandler) == "function")
    done()
  end)

  describe("socketHandler", function ()
    it("should return a function", function (done)
      local handler = web.socketHandler(function (req, res) end)
      assert(type(handler) == "function")
      done()
    end)

    it("should parse html and call app", function (done)
      local client, server = newPipe()
      client.write(
        "GET / HTTP/1.1\r\n" ..
        "User-Agent: curl/7.27.0\r\n" ..
        "Host: localhost:8080\r\n" ..
        "Accept: */*\r\n\r\n")()
      client.write()()
      web.socketHandler(function (req, res)
        assert(type(req.headers) == "table")
        assert(req.method == "GET")
        assert(req.upgrade == false)
        assert(same(req.url, {path="/"}))
        assert(same(req.headers, {
          ["user-agent"] = "curl/7.27.0",
          host = "localhost:8080",
          accept = "*/*"
        }))
        res(200, {
          ["Content-Type"] = "text/plain",
          ["Content-Length"] = 12
        }, "Hello World\n")
        local response = ""
        local expected =
          "HTTP/1.1 200 OK\r\n" ..
          "Content-Length: 12\r\n" ..
          "Content-Type: text/plain\r\n" ..
          "\r\n" ..
          "Hello World\n"
        local function read()
          client.read()(function (err, chunk)
            if err then error(err) end
            if chunk then
              if type(chunk) == "table" then
                chunk = table.concat(chunk)
              end
              response = response .. chunk
              if #response >= #expected then
                assert(expected == response)
                done()
              end
              read()
            else
              assert(expected == response)
            end
          end)
        end
        read()
      end)(server)
    end)
  end)



end)