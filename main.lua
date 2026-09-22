-- DScrete Items -- Gen1Recomp Mod API 2 entrypoint.

local function loadLocal(mod, path)
  local source, readErr = mod:read(path)
  assert(source, ("DScrete Items could not read %s: %s"):format(path, tostring(readErr)))
  local chunk, loadErr = load(source, "@" .. path)
  assert(chunk, ("DScrete Items could not load %s: %s"):format(path, tostring(loadErr)))
  return chunk()
end

local function longSteps(default)
  return { key=nil, label=nil, type="choice", default=default or "250", choices={
    {"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"},{"2500","2500"},
  } }
end

return function(mod)
  local mysterySteps=longSteps("250"); mysterySteps.key="mystery_lure_steps"; mysterySteps.label="MYSTERY STEPS"
  mod.options:define({
    { key="prism_scent_chance", label="PRISM ODDS", type="choice", default="100", choices={{"1 / 1","1"},{"1 / 10","10"},{"1 / 100","100"},{"1 / 1000","1000"}} },
    { key="prism_scent_steps", label="PRISM STEPS", type="choice", default="250", choices={{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"},{"2500","2500"}} },
    { key="elusive_scent_strength", label="ELUSIVE POWER", type="choice", default="mild", choices={{"MILD","mild"},{"STRONG","strong"},{"EXTREME","extreme"}} },
    { key="elusive_scent_steps", label="ELUSIVE STEPS", type="choice", default="250", choices={{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"},{"2500","2500"}} },
    { key="mystery_lure_share", label="MYSTERY RATE", type="choice", default="low", choices={{"LOW - 5%","low"},{"MED - 10%","medium"},{"HIGH - 20%","high"}} },
    mysterySteps,
    { key="mystery_lure_seen_only", label="MYSTERY POOL", type="choice", default="seen", choices={{"SEEN ONLY","seen"},{"ALLOW UNSEEN","all"}} },
    { key="species_whistle_strength", label="WHISTLE POWER", type="choice", default="mild", choices={{"MILD","mild"},{"STRONG","strong"},{"EXTREME","extreme"}} },
    { key="species_whistle_steps", label="WHISTLE STEPS", type="choice", default="100", choices={{"25","25"},{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"}} },
    { key="species_whistle_nonlocal", label="WHISTLE RARE", type="choice", default="off", choices={{"OFF","off"},{"ON","on"}} },
    { key="species_whistle_nonlocal_rate", label="WHISTLE RARE %", type="choice", default="0.5", choices={{"0.5%","0.5"},{"1%","1"},{"2%","2"}} },
  })

  local Items=loadLocal(mod,"lib/items.lua")
  local Runtime=loadLocal(mod,"lib/runtime.lua")
  local Debug=loadLocal(mod,"lib/debug.lua")
  local Weights=loadLocal(mod,"lib/encounter_weights.lua")
  local PrismScent=loadLocal(mod,"lib/shiny_finder.lua")
  local ElusiveScent=loadLocal(mod,"lib/elusive_scent.lua")
  local MysteryLure=loadLocal(mod,"lib/mystery_lure.lua")
  local SpeciesWhistle=loadLocal(mod,"lib/species_whistle.lua")
  local SilphTracker=loadLocal(mod,"lib/silph_tracker.lua")
  local Gadgets=loadLocal(mod,"lib/gadgets.lua")
  local runtime=Runtime.new(mod.save)

  Items.registerBagItems(mod)
  PrismScent.install(mod,runtime)
  ElusiveScent.install(mod,runtime,Weights)
  local mystery=MysteryLure.install(mod,runtime,Weights)
  local whistle=SpeciesWhistle.install(mod,runtime,Weights)
  local tracker=SilphTracker.install(mod,runtime,Weights,ElusiveScent,MysteryLure,whistle)
  local gadgets=Gadgets.install(mod,Items,runtime,{ silph_tracker=function(game) tracker.open(game) end })
  Debug.install(mod,Items,runtime)

  mod.exports.version=mod.version
  mod.exports.items=Items
  mod.exports.runtime=runtime
  mod.exports.encounterWeights=Weights
  mod.exports.prismScent=PrismScent
  mod.exports.elusiveScent=ElusiveScent
  mod.exports.mysteryLure=MysteryLure
  mod.exports.speciesWhistle=whistle
  mod.exports.silphTracker=tracker
  mod.exports.gadgets=gadgets
  mod.exports.shinyFinder=PrismScent
end
