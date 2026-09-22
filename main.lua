-- DScrete Items -- Gen1Recomp Mod API 2 entrypoint.

local function loadLocal(mod, path)
  local source, readErr = mod:read(path)
  assert(source, ("DScrete Items could not read %s: %s"):format(path, tostring(readErr)))
  local chunk, loadErr = load(source, "@" .. path)
  assert(chunk, ("DScrete Items could not load %s: %s"):format(path, tostring(loadErr)))
  return chunk()
end

return function(mod)
  mod.options:define({
    {
      key = "shiny_finder_chance",
      label = "PRISM ODDS",
      type = "choice",
      default = "100",
      choices = {
        { "1 / 1", "1" },
        { "1 / 10", "10" },
        { "1 / 100", "100" },
        { "1 / 1000", "1000" },
      },
    },
    {
      key = "shiny_finder_steps",
      label = "PRISM STEPS",
      type = "choice",
      default = "250",
      choices = {
        { "50", "50" },
        { "100", "100" },
        { "250", "250" },
        { "500", "500" },
        { "1000", "1000" },
        { "2500", "2500" },
      },
    },
  })

  local Items = loadLocal(mod, "lib/items.lua")
  local Runtime = loadLocal(mod, "lib/runtime.lua")
  local Debug = loadLocal(mod, "lib/debug.lua")
  local PrismScent = loadLocal(mod, "lib/shiny_finder.lua")
  local runtime = Runtime.new(mod.save)

  Items.registerBagItems(mod)
  PrismScent.install(mod, runtime)
  Debug.install(mod, Items, runtime)

  -- Stable public surface for later DScrete systems (Oak Research, Safari
  -- ecology, etc.) without requiring them to reach into this mod's files.
  mod.exports.version = mod.version
  mod.exports.items = Items
  mod.exports.runtime = runtime
  mod.exports.prismScent = PrismScent
  -- Compatibility alias for anything already consuming the early dev export.
  mod.exports.shinyFinder = PrismScent
end
