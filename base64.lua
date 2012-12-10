local bit = require("bit")

-- map: byte -> char
local bytes = {
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"
}

-- map: char -> byte
local chars = {}
for i, v in ipairs(bytes) do
	chars[v] = i
end

local base64 = {}

function base64.decode(data)
	local parts = {}

	for i = 1, #data, 4 do
		local val = bit.lshift(chars[data:sub(i,i)] - 1, 18)
		          + bit.lshift((chars[data:sub(i+1,i+1)] or 1) - 1, 12)
		          + bit.lshift((chars[data:sub(i+2,i+2)] or 1) - 1, 6)
		          + (chars[data:sub(i+3,i+3)] or 1) - 1

		table.insert(parts, string.char(bit.band(bit.rshift(val, 16), 0xff)))
		table.insert(parts, string.char(bit.band(bit.rshift(val, 8), 0xff)))
		table.insert(parts, string.char(bit.band(val, 0xff)))
	end

	if data:sub(#data-1) == "==" then
		parts[#parts] = nil
		parts[#parts-1] = nil
	elseif data:sub(#data) == "=" then
		parts[#parts] = nil
	end

	return table.concat(parts)
end

function base64.encode(data)
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

return base64
