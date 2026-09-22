-- Shiny Finder vertical slice.
--
-- Gen 1 has no stored shiny flag. Gen1Recomp's public Stats.isShiny predicate
-- defines a virtual shiny from DVs, so successful Finder rolls replace only a
-- newly-created natural wild Pokemon's DVs with a predicate-valid set.

local ShinyFinder = {}

ShinyFinder.EFFECT_ID = "shiny_finder"
ShinyFinder.ITEM_EFFECT_ID = "DS_SHINY_FINDER_EFFECT"
ShinyFinder.DURATION_STEPS = 250
ShinyFinder.CHANCE_NUMERATOR = 1
ShinyFinder.CHANCE_DENOMINATOR = 100
ShinyFinder.CHANCE_OPTION = "shiny_finder_chance"
ShinyFinder.STEPS_OPTION = "shiny_finder_steps"

local VALID_CHANCES = { [1] = true, [10] = true, [100] = true, [1000] = true }
local VALID_DURATIONS = {
  [50] = true, [100] = true, [250] = true,
  [500] = true, [1000] = true, [2500] = true,
}

local SHINY_ATTACK = { 2, 3, 6, 7, 10, 11, 14, 15 }
local SHINY_ATTACK_SET = {}
for _, value in ipairs(SHINY_ATTACK) do SHINY_ATTACK_SET[value] = true end

local function hpDV(dvs)
  return (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
    + (dvs.speed % 2) * 2 + (dvs.special % 2)
end

function ShinyFinder.resolveChanceDenominator(value)
  local parsed = tonumber(value)
  if parsed and VALID_CHANCES[parsed] then return parsed end
  return ShinyFinder.CHANCE_DENOMINATOR
end

function ShinyFinder.resolveDuration(value)
  local parsed = tonumber(value)
  if parsed and VALID_DURATIONS[parsed] then return parsed end
  return ShinyFinder.DURATION_STEPS
end

function ShinyFinder.makeShinyDVs(rng)
  assert(type(rng) == "function", "Shiny Finder RNG is required")
  local dvs = {
    attack = SHINY_ATTACK[rng(1, #SHINY_ATTACK)],
    defense = 10,
    speed = 10,
    special = 10,
  }
  dvs.hp = hpDV(dvs)
  return dvs
end

function ShinyFinder.isKnownShinyShape(dvs)
  return type(dvs) == "table"
    and dvs.defense == 10 and dvs.speed == 10 and dvs.special == 10
    and SHINY_ATTACK_SET[dvs.attack] == true
    and dvs.hp == hpDV(dvs)
end

function ShinyFinder.rollSucceeds(rng, numerator, denominator)
  numerator = numerator or ShinyFinder.CHANCE_NUMERATOR
  denominator = denominator or ShinyFinder.CHANCE_DENOMINATOR
  assert(type(rng) == "function" and type(numerator) == "number"
    and type(denominator) == "number" and denominator > 0
    and numerator > 0 and numerator <= denominator, "invalid shiny roll")
  return rng(1, denominator) <= numerator
end

local function sameNaturalEncounter(pending, ev)
  return pending and ev
    and pending.species == ev.species
    and pending.level == ev.level
    and (ev.kind == "wild" or ev.kind == "safari")
end

function ShinyFinder.install(mod, runtime)
  local Stats = require("src.pokemon.Stats") -- public/sandbox-supported helper
  local rng = function(lo, hi) return love.math.random(lo, hi) end
  local liveGame, logicTick, lastCountedTick = nil, 0, -1

  local function configuredDuration()
    return ShinyFinder.resolveDuration(mod.options:get(ShinyFinder.STEPS_OPTION))
  end

  local function configuredChanceDenominator()
    return ShinyFinder.resolveChanceDenominator(
      mod.options:get(ShinyFinder.CHANCE_OPTION))
  end

  mod.content.item_effects:register(ShinyFinder.ITEM_EFFECT_ID, {
    needsTarget = false,
    field = true,
    battle = false,
    use = function()
      if runtime.activeFieldEffect == ShinyFinder.EFFECT_ID then
        return "failed", { "The SHINY FINDER\nis already searching." }
      end
      local replace = false
      if runtime.activeFieldEffect then
        replace = runtime:requestFieldReplacement(ShinyFinder.EFFECT_ID)
        if not replace then
          return "failed", {
            "Another field effect\nis already active.\fUse SHINY FINDER\nagain to replace it.",
          }
        end
      end
      local duration = configuredDuration()
      local ok = runtime:activateFieldEffect(
        ShinyFinder.EFFECT_ID, duration, replace)
      if not ok then
        return "failed", { "The SHINY FINDER\nfailed to start." }
      end
      return "consumed", {
        ("SHINY FINDER is\nsearching!\fIt will run for\n%d steps.")
          :format(duration),
      }, { useJingle = true }
    end,
  })

  -- Mark only encounter draws created by the random encounter system. Static
  -- battles, gifts, trades and trainers never pass this marker seam.
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local encounter = next(encDef, ctx)
    if encounter then
      runtime.pendingNaturalEncounter = {
        species = encounter.species,
        level = encounter.level,
      }
    end
    return encounter
  end)

  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates)
    local encounter = next(rod, mapId, candidates)
    if encounter then
      runtime.pendingNaturalEncounter = {
        species = encounter.species,
        level = encounter.level,
      }
    end
    return encounter
  end)

  mod.events:on("battle.started", function(ev)
    local pending = runtime.pendingNaturalEncounter
    runtime.pendingNaturalEncounter = false
    if not runtime:isActive(ShinyFinder.EFFECT_ID) then return end
    if not sameNaturalEncounter(pending, ev) then return end
    local battle = ev and ev.battle
    local mon = battle and battle.enemy and battle.enemy.mon
    if not (mon and mon.species and mon.level) then return end

    runtime.debugRolls = runtime.debugRolls + 1
    local denominator = configuredChanceDenominator()
    if not ShinyFinder.rollSucceeds(rng, ShinyFinder.CHANCE_NUMERATOR, denominator) then
      return
    end

    local dvs = ShinyFinder.makeShinyDVs(rng)
    -- Fail closed if the pinned engine ever changes its shiny predicate.
    if not Stats.isShiny(dvs) then return end

    local def = battle.data and battle.data.pokemon
      and battle.data.pokemon[mon.species]
    if not def then return end
    local wasAtFull = mon.stats and mon.hp == mon.stats.hp
    mon.dvs = dvs
    mon.stats = Stats.calc(def, mon.level, dvs, mon.statExp)
    if wasAtFull or mon.hp == nil then
      mon.hp = mon.stats.hp
    else
      mon.hp = math.max(1, math.min(mon.hp, mon.stats.hp))
    end
    runtime.debugSuccesses = runtime.debugSuccesses + 1
  end)

  -- input.step gives us the live public game argument. The hook runs just
  -- before Input:step; movement.collision runs later in that same logic tick,
  -- when wasPressed/isDown represent the actual movement intent.
  mod.hooks:wrap("input.step", function(next, game, dt)
    liveGame = game
    logicTick = logicTick + 1
    local result = next(game, dt)
    if runtime.pendingExpirationNotice then
      local _, busy = mod.world:availableFieldActions()
      if busy == nil then
        runtime.pendingExpirationNotice = nil
        game.stack:push(mod.ui.TextBox.new(game,
          "The SHINY FINDER\nstopped searching."))
      end
    end
    return result
  end)

  -- movement.collision is also queried by a few read-only world checks, so a
  -- legal collision result alone is not enough. Require the current player
  -- origin, a real held/pressed direction and at most one count per logic tick.
  -- Wall bumps are false, warps do not use this path, and scriptMove does not
  -- synthesize a player's directional input.
  mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    if not (result and runtime.activeFieldEffect and liveGame and liveGame.input) then
      return result
    end
    local current = mod.world:current()
    local input = liveGame.input
    local manual = ctx.dir and (input:isDown(ctx.dir) or input:wasPressed(ctx.dir))
    if current and manual and lastCountedTick ~= logicTick
        and current.x == ctx.fromX and current.y == ctx.fromY then
      lastCountedTick = logicTick
      local expired = runtime:onEligibleStep()
      if expired then runtime.pendingExpirationNotice = expired end
    end
    return result
  end)

  -- Runtime-only effects deliberately do not survive loading/restarting a run.
  mod.events:on("game.ready", function()
    runtime:resetRuntime()
    liveGame, logicTick, lastCountedTick = nil, 0, -1
  end)
end

return ShinyFinder
