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
  local mysterySteps=longSteps("250"); mysterySteps.key="mystery_lure_steps"; mysterySteps.label="MYSTERY LURE STEPS"
  local resonatorSteps=longSteps("250"); resonatorSteps.key="prototype_resonator_steps"; resonatorSteps.label="PROTO RESONATOR STEPS"
  local glitchSteps=longSteps("250"); glitchSteps.key="glitch_detector_steps"; glitchSteps.label="GLITCH DET. STEPS"
  mod.options:define({
    { key="prism_scent_chance", label="PRISM SCENT ODDS", type="choice", default="100", choices={{"1 / 1","1"},{"1 / 10","10"},{"1 / 100","100"},{"1 / 1000","1000"}} },
    { key="prism_scent_steps", label="PRISM SCENT STEPS", type="choice", default="250", choices={{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"},{"2500","2500"}} },
    { key="elusive_scent_strength", label="ELUSIVE SCENT POWER", type="choice", default="mild", choices={{"MILD","mild"},{"STRONG","strong"},{"EXTREME","extreme"}} },
    { key="elusive_scent_steps", label="ELUSIVE SCENT STEPS", type="choice", default="250", choices={{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"},{"2500","2500"}} },
    { key="mystery_lure_share", label="MYSTERY LURE RATE", type="choice", default="low", choices={{"LOW - 5%","low"},{"MED - 10%","medium"},{"HIGH - 20%","high"}} },
    mysterySteps,
    { key="mystery_lure_seen_only", label="MYSTERY LURE POOL", type="choice", default="seen", choices={{"SEEN ONLY","seen"},{"ALLOW UNSEEN","all"}} },
    { key="species_whistle_strength", label="WHISTLE POWER", type="choice", default="mild", choices={{"MILD","mild"},{"STRONG","strong"},{"EXTREME","extreme"}} },
    { key="species_whistle_steps", label="WHISTLE STEPS", type="choice", default="100", choices={{"25","25"},{"50","50"},{"100","100"},{"250","250"},{"500","500"},{"1000","1000"}} },
    { key="species_whistle_nonlocal", label="WHISTLE NONLOCAL", type="choice", default="off", choices={{"OFF","off"},{"ON","on"}} },
    { key="species_whistle_nonlocal_rate", label="WHISTLE NONLOCAL RATE", type="choice", default="0.5", choices={{"0.5%","0.5"},{"1%","1"},{"2%","2"}} },
    { key="prototype_resonator_power", label="PROTO RESONATOR POWER", type="choice", default="strong", choices={{"MILD +10","mild"},{"STRONG +20","strong"},{"EXTREME +35","extreme"}} },
    resonatorSteps,
    { key="safari_kit_bait_power", label="SAFARI KIT BAIT POWER", type="choice", default="strong", choices={{"MILD","mild"},{"STRONG","strong"},{"EXTREME","extreme"}} },
    { key="safari_kit_pass_steps", label="SAFARI KIT PASS STEPS", type="choice", default="250", choices={{"100","100"},{"250","250"},{"500","500"}} },
    { key="safari_kit_pass_balls", label="SAFARI KIT PASS BALLS", type="choice", default="5", choices={{"3","3"},{"5","5"},{"10","10"}} },
    { key="glitch_detector_spots", label="GLITCH DET. SPOTS", type="choice", default="1", choices={{"1","1"},{"2","2"},{"3","3"},{"5","5"}} },
    { key="glitch_detector_flash_rate", label="GLITCH DET. FLASH RATE", type="choice", default="subtle", choices={{"SUBTLE - ~4S","subtle"},{"NORMAL - ~2S","normal"},{"FREQUENT - ~1S","frequent"}} },
    glitchSteps,
    { key="treasure_detector_volume", label="TREASURE DET. VOLUME", type="choice", default="loud", choices={{"QUIET","quiet"},{"NORMAL","normal"},{"LOUD","loud"},{"MAX","max"}} },
  })

  local Items=loadLocal(mod,"lib/items.lua")
  local Runtime=loadLocal(mod,"lib/runtime.lua")
  local Debug=loadLocal(mod,"lib/debug.lua")
  local Weights=loadLocal(mod,"lib/encounter_weights.lua")
  local PrismScent=loadLocal(mod,"lib/shiny_finder.lua")
  local ElusiveScent=loadLocal(mod,"lib/elusive_scent.lua")
  local MysteryLure=loadLocal(mod,"lib/mystery_lure.lua")
  local SpeciesWhistle=loadLocal(mod,"lib/species_whistle.lua")
  local PrototypeResonator=loadLocal(mod,"lib/prototype_resonator.lua")
  local SafariKit=loadLocal(mod,"lib/safari_kit.lua")
  local OverworldFx=loadLocal(mod,"lib/overworld_fx.lua")
  local GlitchDetector=loadLocal(mod,"lib/glitch_detector.lua")
  local TreasureDetector=loadLocal(mod,"lib/treasure_detector.lua")
  local SilphTracker=loadLocal(mod,"lib/silph_tracker.lua")
  local PokedexChip=loadLocal(mod,"lib/pokedex_chip.lua")
  local RocketIncidents=loadLocal(mod,"lib/rocket_incidents.lua")
  local RocketDecoder=loadLocal(mod,"lib/rocket_decoder.lua")
  local PrototypeBall=loadLocal(mod,"lib/prototype_ball.lua")
  local ExpBattery=loadLocal(mod,"lib/exp_battery.lua")
  local Gadgets=loadLocal(mod,"lib/gadgets.lua")
  local runtime=Runtime.new(mod.save)

  Items.registerBagItems(mod)
  local fx=OverworldFx.install(mod)
  PrismScent.install(mod,runtime)
  ElusiveScent.install(mod,runtime,Weights)
  local mystery=MysteryLure.install(mod,runtime,Weights)
  local whistle=SpeciesWhistle.install(mod,runtime,Weights)
  local resonator=PrototypeResonator.install(mod,runtime,Weights)
  local safariKit=SafariKit.install(mod,runtime,Weights)
  local glitch=GlitchDetector.install(mod,runtime,fx,MysteryLure)
  local treasure=TreasureDetector.install(mod,runtime,fx)
  local tracker=SilphTracker.install(mod,runtime,Weights,ElusiveScent,MysteryLure,whistle,safariKit)
  local trackerScan=tracker.scan
  tracker.scan=function(game)
    local rows,empty=trackerScan(game)
    local pos=mod.world:current()
    if pos and glitch.hasAnomalies and glitch.hasAnomalies(pos.mapId) then
      table.insert(rows,1,{ species="__DS_INTERFERENCE", name="INTERFERENCE", band="DETECTED", share=math.huge })
      empty=nil
    end
    return rows,empty
  end
  local pokedexChip=PokedexChip.install(mod,runtime,Weights,{
    elusive=ElusiveScent,mystery=MysteryLure,whistle=whistle,
    resonator=resonator,safari=safariKit,
  })
  local rocketDecoder=RocketDecoder.install(mod,runtime,Items,RocketIncidents)
  local prototypeBall=PrototypeBall.install(mod)
  local expBattery=ExpBattery.install(mod,runtime)
  local gadgets=Gadgets.install(mod,Items,runtime,{
    silph_tracker=function(game) tracker.open(game) end,
    treasure_detector=function(game) treasure.open(game) end,
    pokedex_chip=function(game) pokedexChip.help(game) end,
    rocket_decoder=function(game) rocketDecoder.open(game) end,
  })
  Debug.install(mod,Items,runtime,{
    treasure=treasure,glitch=glitch,rocket=rocketDecoder,expBattery=expBattery,
  })

  mod.exports.version=mod.version
  mod.exports.items=Items
  mod.exports.runtime=runtime
  mod.exports.encounterWeights=Weights
  mod.exports.prismScent=PrismScent
  mod.exports.elusiveScent=ElusiveScent
  mod.exports.mysteryLure=MysteryLure
  mod.exports.speciesWhistle=whistle
  mod.exports.prototypeResonator=resonator
  mod.exports.safariKit=safariKit
  mod.exports.glitchDetector=glitch
  mod.exports.treasureDetector=treasure
  mod.exports.silphTracker=tracker
  mod.exports.pokedexChip=pokedexChip
  mod.exports.rocketDecoder=rocketDecoder
  mod.exports.rocketIncidents=RocketIncidents
  mod.exports.prototypeBall=prototypeBall
  mod.exports.expBattery=expBattery
  mod.exports.gadgets=gadgets
  mod.exports.shinyFinder=PrismScent
end