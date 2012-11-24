local p = require('utils').prettyPrint
local wrap = require('fiber').new
local pathKey = {} -- key for paths

local pass = "\27[1;32m◀\27[0mPASS\27[1;32m▶\27[0m\27[0;32m "
local fail = "\27[1;31m◀\27[0mFAIL\27[1;31m▶\27[0m\27[0;31m "
local tests
local index = 1

local function run()
  local test = tests[index]
  if not test then
    os.exit()
  end
  local position = "(" .. index .. "/" .. #tests .. ") "
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

local function describe(name, block)
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
    print("Not all tests completed")
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
