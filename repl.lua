local utils = require('utils')
local uv = require('luv')

local buffer = ''
local prompt = '>'

io.stdin = uv.new_tty(0, 1)
io.stdout = uv.new_tty(1)
io.stderr = uv.new_tty(2)
io.stdout.write = uv.write
io.stderr.write = uv.write
io.stdout:write("TEST\n")

local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end

local function printResults(results)
  for i = 1, results.n do
    results[i] = utils.dump(results[i])
  end
  print(table.concat(results, '\t'))
end

local function evaluateLine(line)
  local chunk  = buffer .. line
  local f, err = loadstring('return ' .. chunk, 'REPL') -- first we prefix return

  if not f then
    f, err = loadstring(chunk, 'REPL') -- try again without return
  end

  if f then
    buffer = ''
    local success, results = gatherResults(xpcall(f, debug.traceback))

    if success then
      -- successful call
      if results.n > 0 then
        printResults(results)
      end
    else
      -- error
      print(results[1])
    end
  else

    if err:match "'<eof>'$" then
      -- Lua expects some more input; stow it away for next time
      buffer = chunk .. '\n'
      return '>>'
    else
      print(err)
      buffer = ''
    end
  end

  return '>'
end

uv.read_start(io.stdin)

io.stdout:write(prompt .. " ")
function io.stdin:ondata(line)
  evaluateLine(line)
  io.stdout:write(prompt .. " ")
end
function io.stdin:onend()
  os.exit()
end

uv.run()