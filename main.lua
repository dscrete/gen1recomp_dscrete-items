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
      key = "prism_scent_chance",
      label = "PRISM ODDS",
      type = "choice",
      default = "100",
      choices = {
        { "1 / 1", "1" }, { "1 / 10", "10" },
        { "1 / 100", "100" }, { "1 / 1000", "1000" },
      },
    },
    {
      key = "prism_scent_steps",
      label = "PRISM STEPS",
      type = "choice",
      default = "250",
      choices = {
        { "50", "50" }, { "100", "100" }, { "250", "250" },
        { "500", "500" }, { "1000", "1000" }, { "2500", "2500" },
      },
    },
    {
      key = "elusive_scent_strength",
      label = "ELUSIVE POWER",
      type = "choice",
      default = "mild",
      choices = {
        { "MILD", "mild" }, { "STRONG", "strong" }, { "EXTREME", "extreme" },
      },
    },
    {
      key = "elusive_scent_steps",
      label = "ELUSIVE STEPS",
      type = "choice",
      default = "250",
      choices = {
        { "50", "50" }, { "100", "100" }, { "250", "250" },
        { "500", "500" }, { "1000", "1000" }, { "2500", "2500" },
      },
    },
  })

  local Items = loadLocal(mod, "lib/items.lua")
  local Runtime = loadLocal(mod, "lib/runtime.lua")
  local Debug = loadLocal(mod, "lib/debug.lua")
  local Weights = loadLocal(mod, "lib/encounter_weights.lua")
  local PrismScent = loadLocal(mod, "lib/shiny_finder.lua")
  local ElusiveScent = loadLocal(mod, "lib/elusive_scent.lua")
  local SilphTracker = loadLocal(mod, "lib/silph_tracker.lua")
  local Gadgets = loadLocal(mod, "lib/gadgets.lua")
  local runtime = Runtime.new(mod.save)

  Items.registerBagItems(mod)
  PrismScent.install(mod, runtime)
  ElusiveScent.install(mod, runtime, Weights)
  local tracker = SilphTracker.install(mod, runtime, Weights, ElusiveScent)
  local gadgets = Gadgets.install(mod, Items, runtime, {
    silph_tracker = function(game)
      game.stack:push(mod.ui.TextBox.new(game, tracker.text(game)))
    end,
  })
  Debug.install(mod, Items, runtime)

  mod.exports.version = mod.version
  mod.exports.items = Items
  mod.exports.runtime = runtime
  mod.exports.encounterWeights = Weights
  mod.exports.prismScent = PrismScent
  mod.exports.elusiveScent = ElusiveScent
  mod.exports.silphTracker = tracker
  mod.exports.gadgets = gadgets
  -- Compatibility alias for anything already consuming the early dev export.
  mod.exports.shinyFinder = PrismScent
end
