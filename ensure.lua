local p = require('utils').prettyPrint
local wrap = require('fiber').new
local pathKey = {} -- key for paths

local pass = "\27[1;32m◀\27[0mPASS\27[1;32m▶\27[0m\27[0;32m "
local fail = "\27[1;31m◀\27[0mFAIL\27[1;31m▶\27[0m\27[0;31m "
local tests
local index = 1
local position
local test

-- Emulate Lua 5.1 getfenv if it is missing:
local getfenv = getfenv or function(f, t)
	f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
	local name, env
	local up = 0
	repeat
		up = up + 1
		name, env = debug.getupvalue(f, up)
	until name == '_ENV' or name == nil
	return env
end

-- Emulate Lua 5.1 setfenv if it is missing:
local setfenv = setfenv or function(f, t)
	f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
	local name
	local up = 0
	repeat
		up = up + 1
		name = debug.getupvalue(f, up)
	until name == '_ENV' or name == nil
	if name then
		debug.upvaluejoin(f, up, function() return t end, 1) -- use unique upvalue, set it to f
	end
end

local function run()
  test = tests[index]
  if not test then
    os.exit()
  end
  position = "(" .. index .. "/" .. #tests .. ") "
  index = index + 1
  wrap(test.block, function ()
    print(position .. pass .. test.name .. "\27[0m")
    run()
  end)(function (err)
    if err then
      print(position .. fail .. test.name .. "\27[0m")
      print(err)
      run()
    end
  end)

end

local function describe(name, block, cleanup)
  local isOuter = not tests
  if isOuter then
    tests = {}
  end
  local parentenv = getfenv(block)
  local parentPath = parentenv[pathKey]
  local path = parentPath and (parentPath .. " - " .. name) or name
  local env = setmetatable({
    [pathKey] = path,
    describe = describe,
    it = function (name, block)
      table.insert(tests, {name=path .. " - " .. name, block=block})
    end
  }, { __index = parentenv })
  setfenv(block, env)
  block()
  if isOuter then
    run()
    if cleanup then cleanup() end
    print(position .. fail .. test.name .. "\27[0m")
    print("Process exited before done() was called")
    os.exit(-1)
  end
end

local function same(a, b)
  if a == b then return true end
  if not (type(a) == "table" and type(b) == "table") then return false end
  for k, v in pairs(a) do
    if not same(b[k], v) then return false end
  end
  for k in pairs(b) do
    if not a[k] then return false end
  end
  return true
end

return {
  describe = describe,
  same = same
}
