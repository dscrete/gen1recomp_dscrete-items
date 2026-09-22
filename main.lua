-- DScrete Items -- Gen1Recomp Mod API 2 entrypoint.

local function loadLocal(mod, path)
  local source, readErr = mod:read(path)
  assert(source, ("DScrete Items could not read %s: %s"):format(path, tostring(readErr)))
  local chunk, loadErr = load(source, "@" .. path)
  assert(chunk, ("DScrete Items could not load %s: %s"):format(path, tostring(loadErr)))
  return chunk()
end

return function(mod)
  local Items = loadLocal(mod, "lib/items.lua")
  local Runtime = loadLocal(mod, "lib/runtime.lua")
  local Debug = loadLocal(mod, "lib/debug.lua")
  local ShinyFinder = loadLocal(mod, "lib/shiny_finder.lua")
  local runtime = Runtime.new(mod.save)

  Items.registerBagItems(mod)
  ShinyFinder.install(mod, runtime)
  Debug.install(mod, Items, runtime)

  -- Stable public surface for later DScrete systems (Oak Research, Safari
  -- ecology, etc.) without requiring them to reach into this mod's files.
  mod.exports.version = mod.version
  mod.exports.items = Items
  mod.exports.runtime = runtime
  mod.exports.shinyFinder = ShinyFinder
end
