-- Fossil Catalyst: offered during the Cinnabar fossil handover. One Catalyst
-- overclocks the completed revival to a badge-tier target level and follows
-- ordinary LEVEL evolutions reached by that reconstructed level. The hook
-- wraps the real give_pokemon script command, so ordinary gift storage,
-- nickname, Pokedex and other mods' pokemon.before_give handling remain in
-- the native path.

local FossilCatalyst = {}

FossilCatalyst.ITEM_ID = "DS_FOSSIL_CATALYST"
FossilCatalyst.ITEM_EFFECT_ID = "DS_FOSSIL_CATALYST_EFFECT"
FossilCatalyst.FOSSIL_MAP = "CINNABAR_LAB_FOSSIL_ROOM"
FossilCatalyst.TARGET_LEVELS = { 35, 40, 45, 50 }
FossilCatalyst.BADGES = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local function truth(v) return v ~= nil and v ~= false and v ~= 0 end

-- Keep the same broad progression bands used by Trainer Beacon:
-- 0-1 / 2-3 / 4-5 / 6-8 badges.
function FossilCatalyst.badgeTier(save)
  local inv = save and save.inventory or {}
  local count = 0
  for _, id in ipairs(FossilCatalyst.BADGES) do
    if truth(inv[id]) then count = count + 1 end
  end
  if count <= 1 then return 1, count end
  if count <= 3 then return 2, count end
  if count <= 5 then return 3, count end
  return 4, count
end

function FossilCatalyst.targetLevel(save)
  local tier = FossilCatalyst.badgeTier(save)
  return FossilCatalyst.TARGET_LEVELS[tier] or 35, tier
end

-- Overclocked reconstruction only infers ordinary level evolutions. Stone,
-- trade and custom special methods are deliberately not guessed from level.
function FossilCatalyst.evolveForLevel(data, species, level)
  local pokemon = data and data.pokemon or {}
  local current, seen = species, {}
  for _ = 1, 8 do
    if seen[current] then break end
    seen[current] = true
    local def = pokemon[current]
    local nextSpecies
    for _, evo in ipairs(def and def.evolutions or {}) do
      if evo.method == "LEVEL" and tonumber(evo.level or 0) <= level
          and pokemon[evo.species] then
        nextSpecies = evo.species
        break
      end
    end
    if not nextSpecies then break end
    current = nextSpecies
  end
  return current
end

local function mapId(ctx)
  local ow = ctx and ctx.overworld
  return ow and ow.map and ow.map.id or nil
end

-- Build a plan only for the actual pending Cinnabar fossil gift. Species are
-- not hard-coded: anything using the normal labFossilMon revival state can
-- participate. A modded revival already above the tier target is never
-- lowered; the Catalyst can still matter if that level reaches a LEVEL evo.
function FossilCatalyst.plan(ctx, args)
  local save = ctx and ctx.save
  local data = ctx and ctx.game and ctx.game.data
  local flags = save and save.flags or {}
  local species = args and args[1]
  local originalLevel = tonumber(args and args[2])
  if mapId(ctx) ~= FossilCatalyst.FOSSIL_MAP
      or not flags.EVENT_GAVE_FOSSIL_TO_LAB
      or type(species) ~= "string"
      or save.labFossilMon ~= species
      or not originalLevel
      or not (data and data.pokemon and data.pokemon[species]) then
    return nil
  end

  local tierLevel, tier = FossilCatalyst.targetLevel(save)
  local level = math.max(originalLevel, tierLevel)
  level = math.max(1, math.min(100, math.floor(level)))
  local finalSpecies = FossilCatalyst.evolveForLevel(data, species, level)
  if finalSpecies == species and level == originalLevel then return nil end
  return {
    species = finalSpecies,
    originalSpecies = species,
    level = level,
    originalLevel = originalLevel,
    tier = tier,
  }
end

local function itemCount(save)
  return tonumber(save and save.inventory and save.inventory[FossilCatalyst.ITEM_ID]) or 0
end

function FossilCatalyst.promptText(plan)
  return ("FOSSIL CATALYST can\noverclock revival!\fTARGET: LV.%d\nLevel evolution\nmay occur.\fUse one CATALYST?")
    :format(plan.level)
end

function FossilCatalyst.install(mod)
  local takeItem = mod.content.commands:get("take_item")
  if type(takeItem) == "table" then takeItem = takeItem.fn end
  assert(type(takeItem) == "function", "Fossil Catalyst needs public take_item command")

  -- Manual bag use is intentionally not the activation path: the Catalyst is
  -- offered at the moment a completed fossil is handed over, where success or
  -- storage failure is known transactionally.
  mod.content.item_effects:register(FossilCatalyst.ITEM_EFFECT_ID, {
    needsTarget = false,
    field = true,
    battle = false,
    use = function()
      return "failed", { "Use the FOSSIL CAT.\nwhen collecting a\nrevived fossil." }
    end,
  })

  mod.hooks:wrap("script.command", function(next, ctx, name, args)
    if name ~= "give_pokemon" or itemCount(ctx and ctx.save) <= 0 then
      return next(ctx, name, args)
    end
    local plan = FossilCatalyst.plan(ctx, args)
    if not plan or not (ctx.runner and type(ctx.runner.yield) == "function"
        and type(ctx.runner.resume) == "function") then
      return next(ctx, name, args)
    end

    local accepted = false
    ctx.game.stack:push(mod.ui.TextBox.new(ctx.game, FossilCatalyst.promptText(plan), nil, {
      choice = function(yes)
        accepted = yes and true or false
        ctx.runner:resume()
      end,
    }))
    ctx.runner:yield()

    if not accepted then return next(ctx, name, args) end

    local rewritten = {}
    for i, value in ipairs(args or {}) do rewritten[i] = value end
    rewritten[1] = plan.species
    rewritten[2] = plan.level

    -- give_pokemon may itself yield through received/nickname/storage UI.
    -- Only after it returns with carry/lastCheck=true do we spend the item;
    -- party+box-full refusal therefore leaves the Catalyst intact.
    local result = next(ctx, name, rewritten)
    if ctx.lastCheck then takeItem(ctx, FossilCatalyst.ITEM_ID, 1) end
    return result
  end)

  return FossilCatalyst
end

return FossilCatalyst
