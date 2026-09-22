-- Elusive Scent: temporarily reweights the rarest species already present in
-- the current encounter table. It never adds species, changes encounter rate,
-- or changes levels.

local ElusiveScent = {}

ElusiveScent.EFFECT_ID = "elusive_scent"
ElusiveScent.ITEM_EFFECT_ID = "DS_ELUSIVE_SCENT_EFFECT"
ElusiveScent.STRENGTH_OPTION = "elusive_scent_strength"
ElusiveScent.STEPS_OPTION = "elusive_scent_steps"
ElusiveScent.DURATION_STEPS = 250

local STRENGTHS = { mild = 2, strong = 4, extreme = 8 }
local VALID_DURATIONS = { [50]=true, [100]=true, [250]=true, [500]=true, [1000]=true, [2500]=true }
local WILDS_ID = "overworld_wild_spawns"

function ElusiveScent.resolveStrength(value)
  return STRENGTHS[tostring(value or "")] or STRENGTHS.mild
end

function ElusiveScent.resolveDuration(value)
  local parsed = tonumber(value)
  if parsed and VALID_DURATIONS[parsed] then return parsed end
  return ElusiveScent.DURATION_STEPS
end

function ElusiveScent.install(mod, runtime, Weights)
  local wildsWrapped = false

  local function configuredDuration()
    return ElusiveScent.resolveDuration(mod.options:get(ElusiveScent.STEPS_OPTION))
  end
  local function configuredFactor()
    return ElusiveScent.resolveStrength(mod.options:get(ElusiveScent.STRENGTH_OPTION))
  end
  local function eligibleTerrain(terrain)
    return terrain == "grass" or terrain == "indoor" or terrain == "water"
  end
  local function mergedEncounterDef(mapId)
    local registry = mod.content and mod.content.encounters
    if registry and type(registry.get) == "function" then
      local ok, value = pcall(registry.get, registry, mapId)
      if ok and type(value) == "table" then return value end
    end
    return nil
  end
  local function pickSlot(tableDef)
    local rows = Weights.slotWeights(tableDef)
    if #rows == 0 then return nil end
    local pick = love.math.random(0, 255)
    local buckets = tableDef.buckets
    if buckets then
      for i, threshold in ipairs(buckets) do
        if pick < threshold then
          local slot = tableDef.slots[i]
          return slot and { species=slot.species, level=slot.level } or nil
        end
      end
    end
    local cumulative = 0
    for _, row in ipairs(rows) do
      cumulative = cumulative + row.weight
      if pick < cumulative then return { species=row.species, level=row.level } end
    end
    local last = rows[#rows]
    return last and { species=last.species, level=last.level } or nil
  end

  mod.content.item_effects:register(ElusiveScent.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function()
      if runtime.activeFieldEffect == ElusiveScent.EFFECT_ID then
        return "failed", { "ELUSIVE SCENT is\nalready in the air." }
      end
      local replace = false
      if runtime.activeFieldEffect then
        replace = runtime:requestFieldReplacement(ElusiveScent.EFFECT_ID)
        if not replace then
          return "failed", { "Another field effect\nis already active.\fUse ELUSIVE SCENT\nagain to replace it." }
        end
      end
      local duration = configuredDuration()
      local ok = runtime:activateFieldEffect(ElusiveScent.EFFECT_ID, duration, replace)
      if not ok then return "failed", { "The ELUSIVE SCENT\nfailed to spread." } end
      return "consumed", {
        ("ELUSIVE SCENT drifts\nthrough the area!\fRare local POKéMON\nare easier to find.\fIt will last for\n%d steps."):format(duration),
      }, { useJingle=true }
    end,
  })

  -- The shared timed-field movement hook is installed by Prism Scent and
  -- decrements whichever single field effect is active. This hook only changes
  -- the species distribution handed to the rest of the normal roll chain.
  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    if not runtime:isActive(ElusiveScent.EFFECT_ID)
        or not (ctx and eligibleTerrain(ctx.terrain)) then
      return next(encDef, ctx)
    end
    local boosted = Weights.boostEncounterDef(encDef, ctx.terrain, configuredFactor())
    return next(boosted, ctx)
  end)

  local function installWildsCompatibility()
    if wildsWrapped or type(mod.find) ~= "function" then return wildsWrapped end
    local found = mod.find(WILDS_ID)
    local logic = found and found.exports and found.exports.logic
    if not (logic and type(logic.trySpawn) == "function") then return false end
    if logic._dscreteElusiveScentWrapped then wildsWrapped = true return true end
    local original = logic.trySpawn
    logic.trySpawn = function(self, game, opts)
      opts = opts or {}
      if runtime:isActive(ElusiveScent.EFFECT_ID) and not opts.species
          and not opts.testSpawn and not opts.readinessProbe then
        local current = mod.world:current()
        local mapId = (current and current.mapId) or self.activeMapId
        local terrain = self.surfaceInfo and self.surfaceInfo.encounterKind or "grass"
        if terrain == "indoor" then terrain = "grass" end
        local encDef = mergedEncounterDef(mapId)
        local boosted = encDef and Weights.boostEncounterDef(encDef, terrain, configuredFactor()) or nil
        local tableDef = boosted and Weights.terrainTable(boosted, terrain)
        local picked = tableDef and pickSlot(tableDef)
        if picked then
          local forwarded = {}
          for k, v in pairs(opts) do forwarded[k] = v end
          forwarded.species, forwarded.level = picked.species, picked.level
          opts = forwarded
        end
      end
      return original(self, game, opts)
    end
    logic._dscreteElusiveScentWrapped = true
    wildsWrapped = true
    return true
  end

  -- Prism's shared step hook records the expired effect id; only consume the
  -- notice when it belongs to Elusive Scent.
  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if runtime.pendingExpirationNotice == ElusiveScent.EFFECT_ID then
      local _, busy = mod.world:availableFieldActions()
      if busy == nil then
        runtime.pendingExpirationNotice = nil
        game.stack:push(mod.ui.TextBox.new(game, "The ELUSIVE SCENT\nfaded away."))
      end
    end
    return result
  end)

  mod.events:on("mods.loaded", installWildsCompatibility)
  mod.events:on("game.ready", installWildsCompatibility)
end

return ElusiveScent
