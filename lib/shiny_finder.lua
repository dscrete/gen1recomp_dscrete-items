-- Prism Scent: a timed Gen 1 shiny-encounter field effect.
--
-- Gen 1 has no stored shiny flag. Gen1Recomp's public Stats.isShiny predicate
-- defines a virtual shiny from DVs, so successful Prism Scent rolls assign a
-- valid shiny DV set to eligible natural wild Pokemon.

local PrismScent = {}

PrismScent.EFFECT_ID = "prism_scent"
PrismScent.ITEM_EFFECT_ID = "DS_PRISM_SCENT_EFFECT"
PrismScent.DURATION_STEPS = 250
PrismScent.CHANCE_NUMERATOR = 1
PrismScent.CHANCE_DENOMINATOR = 100
PrismScent.CHANCE_OPTION = "prism_scent_chance"
PrismScent.STEPS_OPTION = "prism_scent_steps"

local WILDS_ID = "overworld_wild_spawns"
local VALID_CHANCES = { [1] = true, [10] = true, [100] = true, [1000] = true }
local VALID_DURATIONS = { [50]=true, [100]=true, [250]=true, [500]=true, [1000]=true, [2500]=true }
local SHINY_ATTACK = { 2, 3, 6, 7, 10, 11, 14, 15 }
local SHINY_ATTACK_SET = {}
for _, value in ipairs(SHINY_ATTACK) do SHINY_ATTACK_SET[value] = true end

local function hpDV(dvs)
  return (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4 + (dvs.speed % 2) * 2 + (dvs.special % 2)
end

local function copyDVs(dvs)
  if type(dvs) ~= "table" then return nil end
  return { attack=dvs.attack, defense=dvs.defense, speed=dvs.speed, special=dvs.special, hp=dvs.hp }
end

function PrismScent.resolveChanceDenominator(value)
  local parsed = tonumber(value)
  if parsed and VALID_CHANCES[parsed] then return parsed end
  return PrismScent.CHANCE_DENOMINATOR
end

function PrismScent.resolveDuration(value)
  local parsed = tonumber(value)
  if parsed and VALID_DURATIONS[parsed] then return parsed end
  return PrismScent.DURATION_STEPS
end

function PrismScent.makeShinyDVs(rng)
  assert(type(rng) == "function", "Prism Scent RNG is required")
  local dvs = { attack=SHINY_ATTACK[rng(1,#SHINY_ATTACK)], defense=10, speed=10, special=10 }
  dvs.hp = hpDV(dvs)
  return dvs
end

function PrismScent.isKnownShinyShape(dvs)
  return type(dvs) == "table" and dvs.defense == 10 and dvs.speed == 10 and dvs.special == 10
    and SHINY_ATTACK_SET[dvs.attack] == true and dvs.hp == hpDV(dvs)
end

function PrismScent.rollSucceeds(rng, numerator, denominator)
  numerator = numerator or PrismScent.CHANCE_NUMERATOR
  denominator = denominator or PrismScent.CHANCE_DENOMINATOR
  assert(type(rng) == "function" and type(numerator) == "number" and type(denominator) == "number"
    and denominator > 0 and numerator > 0 and numerator <= denominator, "invalid Prism Scent roll")
  return rng(1, denominator) <= numerator
end

function PrismScent.markVisibleSpawn(target, dvs)
  if type(target) ~= "table" or not PrismScent.isKnownShinyShape(dvs) then return false end
  target.dscretePrismDVs = copyDVs(dvs)
  target.isShiny = true
  target.shiny = true
  return true
end

local function sameNaturalEncounter(pending, ev)
  return pending and ev and pending.species == ev.species and pending.level == ev.level
    and (ev.kind == "wild" or ev.kind == "safari")
end

local function sameWildsBattle(pending, ev)
  return type(pending) == "table" and pending.dscretePrismDVs and ev
    and pending.species == ev.species and pending.level == ev.level
    and (ev.kind == "wild" or ev.kind == "safari")
end

function PrismScent.install(mod, runtime)
  local Stats = require("src.pokemon.Stats")
  local rng = function(lo, hi) return love.math.random(lo, hi) end
  local liveGame, logicTick, lastCountedTick = nil, 0, -1
  local wildsWrapped = false

  local function configuredDuration()
    return PrismScent.resolveDuration(mod.options:get(PrismScent.STEPS_OPTION))
  end
  local function configuredChanceDenominator()
    return PrismScent.resolveChanceDenominator(mod.options:get(PrismScent.CHANCE_OPTION))
  end

  local function applyDVs(ev, dvs)
    local battle = ev and ev.battle
    local mon = battle and battle.enemy and battle.enemy.mon
    if not (mon and mon.species and mon.level and PrismScent.isKnownShinyShape(dvs)) then return false end
    if not Stats.isShiny(dvs) then return false end
    local def = battle.data and battle.data.pokemon and battle.data.pokemon[mon.species]
    if not def then return false end
    local wasAtFull = mon.stats and mon.hp == mon.stats.hp
    mon.dvs = copyDVs(dvs)
    mon.stats = Stats.calc(def, mon.level, mon.dvs, mon.statExp)
    if wasAtFull or mon.hp == nil then mon.hp = mon.stats.hp
    else mon.hp = math.max(1, math.min(mon.hp, mon.stats.hp)) end
    return true
  end

  local function wildsExports()
    if type(mod.find) ~= "function" then return nil end
    local found = mod.find(WILDS_ID)
    return found and found.exports or nil
  end

  local function installWildsCompatibility()
    if wildsWrapped then return true end
    local exports = wildsExports()
    local render = exports and exports.render
    if not (render and type(render.makeEntity) == "function") then return false end
    if render._dscretePrismScentWrapped then wildsWrapped = true return true end
    local original = render.makeEntity
    render.makeEntity = function(self, game, record)
      if type(record) == "table" and not record.testSpawn and runtime:isActive(PrismScent.EFFECT_ID)
          and not record.dscretePrismRolled then
        record.dscretePrismRolled = true
        runtime.debugRolls = runtime.debugRolls + 1
        local denominator = configuredChanceDenominator()
        if PrismScent.rollSucceeds(rng, PrismScent.CHANCE_NUMERATOR, denominator) then
          local dvs = PrismScent.makeShinyDVs(rng)
          if Stats.isShiny(dvs) then
            PrismScent.markVisibleSpawn(record, dvs)
            runtime.debugSuccesses = runtime.debugSuccesses + 1
          end
        end
      end
      local entity = original(self, game, record)
      if entity and record and record.dscretePrismDVs then PrismScent.markVisibleSpawn(entity, record.dscretePrismDVs) end
      return entity
    end
    render._dscretePrismScentWrapped = true
    wildsWrapped = true
    return true
  end

  local function pendingWildsSpawn()
    local exports = wildsExports()
    local logic = exports and exports.logic
    local pending = logic and logic.pendingBattle
    if type(pending) == "table" and pending.dscretePrismDVs then return pending end
    return nil
  end

  mod.content.item_effects:register(PrismScent.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function()
      if runtime.activeFieldEffect == PrismScent.EFFECT_ID then
        return "failed", { "PRISM SCENT is\nalready in the air." }
      end
      local replace = false
      if runtime.activeFieldEffect then
        replace = runtime:requestFieldReplacement(PrismScent.EFFECT_ID)
        if not replace then
          return "failed", { "Another field effect\nis already active.\fUse PRISM SCENT\nagain to replace it." }
        end
      end
      local duration = configuredDuration()
      local ok = runtime:activateFieldEffect(PrismScent.EFFECT_ID, duration, replace)
      if not ok then return "failed", { "The PRISM SCENT\nfailed to spread." } end
      return "consumed", { ("PRISM SCENT drifts\nthrough the area!\fIt will last for\n%d steps."):format(duration) }, { useJingle=true }
    end,
  })

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local encounter = next(encDef, ctx)
    if encounter then runtime.pendingNaturalEncounter = { species=encounter.species, level=encounter.level } end
    return encounter
  end)

  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates)
    local encounter = next(rod, mapId, candidates)
    if encounter then runtime.pendingNaturalEncounter = { species=encounter.species, level=encounter.level } end
    return encounter
  end)

  mod.events:on("battle.started", function(ev)
    local wildsPending = pendingWildsSpawn()
    if sameWildsBattle(wildsPending, ev) and applyDVs(ev, wildsPending.dscretePrismDVs) then return end
    local pending = runtime.pendingNaturalEncounter
    runtime.pendingNaturalEncounter = false
    if not runtime:isActive(PrismScent.EFFECT_ID) or not sameNaturalEncounter(pending, ev) then return end
    runtime.debugRolls = runtime.debugRolls + 1
    local denominator = configuredChanceDenominator()
    if not PrismScent.rollSucceeds(rng, PrismScent.CHANCE_NUMERATOR, denominator) then return end
    local dvs = PrismScent.makeShinyDVs(rng)
    if applyDVs(ev, dvs) then runtime.debugSuccesses = runtime.debugSuccesses + 1 end
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    liveGame = game
    logicTick = logicTick + 1
    local result = next(game, dt)
    if runtime.pendingExpirationNotice then
      local _, busy = mod.world:availableFieldActions()
      if busy == nil then
        runtime.pendingExpirationNotice = nil
        game.stack:push(mod.ui.TextBox.new(game, "The PRISM SCENT\nfaded away."))
      end
    end
    return result
  end)

  mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    if not (result and runtime.activeFieldEffect and liveGame and liveGame.input) then return result end
    local current = mod.world:current()
    local input = liveGame.input
    local manual = ctx.dir and (input:isDown(ctx.dir) or input:wasPressed(ctx.dir))
    if current and manual and lastCountedTick ~= logicTick and current.x == ctx.fromX and current.y == ctx.fromY then
      lastCountedTick = logicTick
      local expired = runtime:onEligibleStep()
      if expired then runtime.pendingExpirationNotice = expired end
    end
    return result
  end)

  local function reloadPersistentEffect()
    runtime:reloadPersistentState()
    liveGame, logicTick, lastCountedTick = nil, 0, -1
    installWildsCompatibility()
  end

  mod.events:on("game.ready", reloadPersistentEffect)
  mod.events:on("save.loaded", reloadPersistentEffect)
  mod.events:on("save.created", reloadPersistentEffect)
  mod.events:on("mods.loaded", installWildsCompatibility)
end

return PrismScent
