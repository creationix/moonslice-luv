local p = require('utils').prettyPrint
local fs = require('uv').fs
local await = require('fiber').await
local wait = require('fiber').wait
local newStream = require('stream').newStream
local getType = require('mime').getType
local floor = require('math').floor

-- For encoding numbers using bases up to 64
local digits = {
  "0", "1", "2", "3", "4", "5", "6", "7",
  "8", "9", "A", "B", "C", "D", "E", "F",
  "G", "H", "I", "J", "K", "L", "M", "N",
  "O", "P", "Q", "R", "S", "T", "U", "V",
  "W", "X", "Y", "Z", "a", "b", "c", "d",
  "e", "f", "g", "h", "i", "j", "k", "l",
  "m", "n", "o", "p", "q", "r", "s", "t",
  "u", "v", "w", "x", "y", "z", "_", "$"
}
local function numToBase(num, base)
  local parts = {}
  repeat
    table.insert(parts, digits[(num % base) + 1])
    num = floor(num / base)
  until num == 0
  return table.concat(parts)
end

local function calcEtag(stat)
  return (not stat.is_file and 'W/' or '') ..
         '"' .. numToBase(stat.ino or 0, 64) ..
         '-' .. numToBase(stat.size, 64) ..
         '-' .. numToBase(stat.mtime, 64) .. '"'
end
local function sendFile(path, req, res)
  local err, fd = wait(fs.open(path, "r"))
  if not fd then
    return res(404, {}, err)
  end
  local stat = await(fs.fstat(fd))
  local etag = calcEtag(stat)
  local code = 200
  local headers = {
    ['Last-Modified'] = os.date("!%a, %d %b %Y %H:%M:%S GMT", stat.mtime),
    ["ETag"] = etag
  }
  local body
  if req.headers["if-none-match"] == etag then
    code = 304
  end

  if code ~= 304 then
    headers["Content-Type"] = getType(path)
    headers["Content-Length"] = stat.size
  end

  if not (req.method == "HEAD" or code == 304) then
    body = newStream()
  end

  -- Start the response
  res(code, headers, body)

  if not body then return end

  -- Stream the file to the browser
  repeat
    local chunk = await(fs.read(fd, 10))
    if #chunk == 0 then
      chunk = nil
    end
    await(body.write(chunk))
  until not chunk

end

return {
  file = sendFile,
  numToBase = numToBase
}