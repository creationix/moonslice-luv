local ffi = require('ffi')
local bit = require('bit')
local sha1_binary = require("sha1").sha1_binary
local newPipe = require('stream').newPipe
local p = require('utils').prettyPrint

local bytes = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
               'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
               'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
               'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
               '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'}

local function base64Encode(data)
  local parts = {}
  for i = 1, #data, 3 do
    local val = bit.lshift(data:byte(i), 16)
              + bit.lshift(data:byte(i + 1) or 0, 8)
              + (data:byte(i + 2) or 0)
    table.insert(parts, bytes[bit.band(bit.rshift(val, 18), 0x3f) + 1])
    table.insert(parts, bytes[bit.band(bit.rshift(val, 12), 0x3f) + 1])
    table.insert(parts, bytes[bit.band(bit.rshift(val, 6), 0x3f) + 1])
    table.insert(parts, bytes[bit.band(val, 0x3f) + 1])
  end
  local rem = #data % 3
  if rem == 1 then
    parts[#parts] = "="
    parts[#parts - 1] = "="
  elseif rem == 2 then
    parts[#parts] = "="
  end
  return table.concat(parts)
end

ffi.cdef([[
typedef struct {
  int8_t fin, rsv1, rsv2, rsv3, opcode, mask;
  uint64_t length, offset;
} websocket_frame;
]])

local function frame(message, head)
  local key
  local len = #message
  local size = len + 2
  if head.mask then
    key = ffi.new("unsigned char[?]", 4)
    key[0] = math.random(0,255)
    key[1] = math.random(0,255)
    key[2] = math.random(0,255)
    key[3] = math.random(0,255)
    size = size + 4
  end
  if len >= 65536 then
    head.length = 127
    size = size + 8
  elseif len >= 126 then
    head.length = 126
    size = size + 2
  else
    head.length = len
  end

  local payload = ffi.new("unsigned char[?]", size)
  payload[0] = (head.fin and 128 or 0)
             + (head.rsv1 and 64 or 0)
             + (head.rsv2 and 32 or 0)
             + (head.rsv3 and 16 or 0)
             + (head.opcode or 0)
  payload[1] = (head.mask and 128 or 0)
             + (head.length)
  local offset

  if head.length == 127 then
    payload[2] = bit.band(bit.rshift(len, 56), 0xff)
    payload[3] = bit.band(bit.rshift(len, 48), 0xff)
    payload[4] = bit.band(bit.rshift(len, 40), 0xff)
    payload[5] = bit.band(bit.rshift(len, 32), 0xff)
    payload[6] = bit.band(bit.rshift(len, 24), 0xff)
    payload[7] = bit.band(bit.rshift(len, 16), 0xff)
    payload[8] = bit.band(bit.rshift(len, 8), 0xff)
    payload[9] = bit.band(len, 0xff)
    offset = 10
  elseif head.length == 126 then
    payload[2] = bit.band(bit.rshift(len, 8), 0xff)
    payload[3] = bit.band(len, 0xff)
    offset = 4
  else
    offset = 2
  end

  if key then
    payload[offset] = key[0]
    payload[offset + 1] = key[1]
    payload[offset + 2] = key[2]
    payload[offset + 3] = key[3]
    offset = offset + 4
  end

  for i = 1, len do
    local byte = message:byte(i)
    if key then
      payload[offset] = bit.bxor(byte, key[(i-1)%4])
    else
      payload[offset] = byte
    end
    offset = offset + 1
  end
  return ffi.string(payload, offset)
end

-- Simple state machine to deframe websocket 13 traffic
local function deframer(onMessage)
  local state = 0
  local head, payload

  local function startKey()
    key = ffi.new("unsigned char[?]", 4)
    state = 12
  end

  local function emit(message)
    onMessage(message, head)
    head = nil
    key = nil
    payload = nil
    state = 0
  end

  local function startBody()
    if head.length == 0 then
      return emit("")
    end
    payload = ffi.new("unsigned char[?]", head.length)
    head.offset = 0
    state = 16
  end
  local states = {
    [0] = function (byte) -- HEADER BYTE 1
      head = ffi.new("websocket_frame")
      head.fin = bit.rshift(bit.band(byte, 128), 7)
      head.rsv1 = bit.rshift(bit.band(byte, 64), 6)
      head.rsv2 = bit.rshift(bit.band(byte, 32), 5)
      head.rsv3 = bit.rshift(bit.band(byte, 16), 4)
      head.opcode = bit.band(byte, 15)

      state = 1
    end,
    [1] = function (byte) -- HEADER BYTE 2
      head.mask = bit.rshift(bit.band(byte, 128), 7)
      length = bit.band(byte, 127)
      if length == 126 then
        state = 2
      elseif length == 127 then
        state = 5
      else
        head.length = length
        if head.mask then
          startKey()
        else
          startBody()
        end
      end
    end,
    [2] = function (byte) -- length16-1
      head.length = bit.lshift(byte, 8)
      state = 3
    end,
    [3] = function (byte) -- length16-2
      head.length = head.length + byte
      if head.mask then
        startKey()
      else
        startBody()
      end
    end,
    [4] = function (byte) -- length64-1
      head.length = bit.lshift(byte, 56)
      state = 5
    end,
    [5] = function (byte) -- length64-2
      head.length = head.length + bit.lshift(byte, 48)
      state = 6
    end,
    [6] = function (byte) -- length64-3
      head.length = head.length + bit.lshift(byte, 40)
      state = 7
    end,
    [7] = function (byte) -- length64-4
      head.length = head.length + bit.lshift(byte, 32)
      state = 8
    end,
    [8] = function (byte) -- length64-5
      head.length = head.length + bit.lshift(byte, 24)
      state = 9
    end,
    [9] = function (byte) -- length64-6
      head.length = head.length + bit.lshift(byte, 16)
      state = 10
    end,
    [10] = function (byte) -- length64-7
      head.length = head.length + bit.lshift(byte, 8)
      state = 11
    end,
    [11] = function (byte) -- length64-8
      head.length = head.length + byte
      if head.mask then
        startKey()
      else
        startBody()
      end
    end,
    [12] = function (byte) -- masking-key-1
      key[0] = byte
      state = 13
    end,
    [13] = function (byte) -- masking-key-2
      key[1] = byte
      state = 14
    end,
    [14] = function (byte) -- masking-key-3
      key[2] = byte
      state = 15
    end,
    [15] = function (byte) -- masking-key-4
      key[3] = byte
      startBody()
    end,
    [16] = function (byte) -- payload data
      if head.offset >= head.length then
        error("OOB error")
      end
      if key then
        payload[head.offset] = bit.bxor(byte, key[head.offset % 4])
      else
        payload[head.offset] = byte
      end
      head.offset = head.offset + 1
      if head.offset == head.length then
        emit(ffi.string(payload, head.length))
      end
    end
  }

  return function (chunk)
    for i = 1, #chunk do
      states[state](chunk:byte(i))
    end
  end
end

local function getToken(key)
  return base64Encode(sha1_binary(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
end

local function upgrade(req)
  local key = req.headers["sec-websocket-key"]
  local token = getToken(key)
  local socket = req.socket
  socket.write({
    "HTTP/1.1 101 Switching Protocols\r\n",
    "Upgrade: websocket\r\n",
    "Connection: Upgrade\r\n",
    "Sec-WebSocket-Accept: ", token, "\r\n",
    "\r\n"
  })()
  local internal, external = newPipe()
  local parser = deframer(function (message, head)
    if head.opcode == 0x8 then
      internal.write()()
    else
      internal.write(message)()
    end
  end)
  local function onRead(err, chunk)
    if err then error(err) end
    if chunk then
      parser(chunk)
      socket.read()(onRead)
    else
      internal.write()()
    end
  end
  socket.read()(onRead)

  local function read()
    internal.read()(function (err, message)
      if err then error(err) end
      if message then
        socket.write(frame(message, {
          fin = true,
          opcode = 1
        }))()
        read()
      end
    end)
  end
  read()

  return external

end

return {
  upgrade = upgrade,
  deframer = deframer,
  frame = frame,
  getToken = getToken
}
