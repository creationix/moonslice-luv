local autoheaders = require('autoheaders')
local newStream = require('stream').newStream
local await = require('fiber').await
local p = require('utils').prettyPrint
local tick = require('tick').tick
local flushTickQueue = require('tick').flushTickQueue
local describe = require('ensure').describe
local same = require('ensure').same

describe("autoheaders", function ()

  it("is a function", function (done)
    assert(type(autoheaders) == "function")
    done()
  end)

  describe("string body", function ()
    local app = function (req, res)
      res(200, {
        ["Content-Type"] = "text/plain"
      }, "Hello World\n")
    end
    local request = {
      method = "GET",
      url = { path = "/" },
      headers = {}
    }

    it("proxies to main app", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(code == 200)
        assert(body == "Hello World\n")
      end)
      done()
    end)

    it("adds Server header", function (done)
      autoheaders(app, {autoServer="BustedServer"})(request, function (code, headers, body)
        assert(headers["Server"] == "BustedServer")
      end)
      done()
    end)

    it("adds Date header", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(type(headers["Date"]) == "string")
      end)
      done()
    end)

    it("adds Content-Length header", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Content-Length"] == #body)
      end)
      done()
    end)

    it("Adds Connection: close", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Connection"]:lower() == "close")
      end)
      done()
    end)

    it("Adds Connection: keep-alive", function (done)
      local request = {
        method = "GET",
        url = { path = "/" },
        should_keep_alive = true,
        headers = {
          Connection = "Keep-Alive"
        }
      }
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Connection"]:lower() == "keep-alive")
      end)
      done()
    end)

    it("should do chunked encoding", function (done)
      autoheaders(app, {autoContentLength=false})(request, function (code, headers, body)
        assert(headers["Transfer-Encoding"] == "chunked")
        assert(headers["Content-Length"] == nil)
        assert(same(body, {
          "C\r\n",
          "Hello World\n",
          "\r\n0\r\n\r\n"
        }))
      end)
      done()
    end)

  end)

  describe("array body", function ()
    local app = function (req, res)
      res(200, {
        ["Content-Type"] = "text/plain"
      }, {"Hello ", "World\n"})
    end
    local request = {
      method = "GET",
      url = { path = "/" },
      headers = {}
    }

    it("should add Content-Length header", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Content-Length"] == 12)
      end)
      done()
    end)

    it("should do chunked encoding", function (done)
      autoheaders(app, {autoContentLength=false})(request, function (code, headers, body)
        assert(headers["Transfer-Encoding"] == "chunked")
        assert(headers["Content-Length"] == nil)
        assert(same(body, {
          "C\r\n",
          "Hello ",
          "World\n",
          "\r\n0\r\n\r\n"
        }))
      end)
      done()
    end)

  end)

  describe("sync stream body", function ()
    local stream = newStream()
    local app = function (req, res)
      res(200, {
        ["Content-Type"] = "text/plain"
      }, stream)
    end
    local request = {
      method = "GET",
      url = { path = "/" },
      headers = {}
    }
    stream.write("Hello ")()
    stream.write({"my ", "fun "})()
    stream.write("World\n")()
    stream.write()()

    it("should do chunked encoding", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Transfer-Encoding"] == "chunked")
        assert(headers["Content-Length"] == nil)
        assert(type(body) == "table")
        assert(type(body.read) == "function")
        local parts = {}
        repeat
          local chunk = await(body.read())
          if chunk then
            table.insert(parts, chunk)
          end
        until not chunk
        assert(same({
          { "6\r\n", "Hello ", "\r\n" },
          { "7\r\n", "my ", "fun ", "\r\n" },
          { "6\r\n", "World\n", "\r\n" },
          "0\r\n\r\n"
        }, parts))
      end)
      done()
    end)

  end)

  describe("async stream body", function ()
    local stream = newStream()
    local app = function (req, res)
      res(200, {
        ["Content-Type"] = "text/plain"
      }, stream)
    end
    local request = {
      method = "GET",
      url = { path = "/" },
      headers = {}
    }

    it("should do chunked encoding", function (done)
      autoheaders(app)(request, function (code, headers, body)
        assert(headers["Transfer-Encoding"] == "chunked")
        assert(headers["Content-Length"] == nil)
        assert(type(body) == "table")
        assert(type(body.read) == "function")
        local parts = {}
        repeat
          local chunk = await(body.read())
          if chunk then
            table.insert(parts, chunk)
          end
        until not chunk
        assert(same({
          { "6\r\n", "Hello ", "\r\n" },
          { "7\r\n", "my ", "fun ", "\r\n" },
          { "6\r\n", "World\n", "\r\n" },
          "0\r\n\r\n"
        }, parts))
      end)
      done()
    end)

    local input = {
      "Hello ",
      {"my ", "fun "},
      "World\n"
    }
    local index = 1
    local function next()
      local message = input[index]
      index = index + 1
      stream.write(message)(function ()
        if message then
          tick()(next)
        end
      end)
    end
    tick()(next)

  end)


end)

flushTickQueue()
