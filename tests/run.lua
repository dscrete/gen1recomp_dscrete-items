-- Standalone DScrete tests. No Gen1Recomp checkout is required.

local passed, failed = 0, 0

_G.test = function(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    io.write("ok - " .. name .. "\n")
  else
    failed = failed + 1
    io.stderr:write("not ok - " .. name .. ": " .. tostring(err) .. "\n")
  end
end

_G.eq = function(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

_G.check = function(value, message)
  if not value then error(message or "check failed", 2) end
end

dofile("tests/items_test.lua")
dofile("tests/runtime_test.lua")
dofile("tests/shiny_finder_test.lua")
dofile("tests/encounter_weights_test.lua")
dofile("tests/silph_tracker_test.lua")

io.write(("%d passed, %d failed\n"):format(passed, failed))
if failed > 0 then os.exit(1) end
