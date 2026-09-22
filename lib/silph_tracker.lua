-- Silph Tracker: permanent gadget that reports coarse signal bands for every
-- species currently present on the player's map. Unseen species remain UNKNOWN.

local SilphTracker = {}
SilphTracker.KEY = "silph_tracker"

local BAND_RANK = { ["NO SIGNAL"]=0, FAINT=1, WEAK=2, STRONG=3, ["VERY STRONG"]=4 }

local function seenSpecies(game, species)
  local dex = game and game.save and game.save.pokedex
  if not dex then return false end
  return (dex.seen and dex.seen[species] == true)
    or (dex.owned and dex.owned[species] == true)
end

local function displayName(game, species)
  if not seenSpecies(game, species) then return "UNKNOWN" end
  local def = game and game.data and game.data.pokemon and game.data.pokemon[species]
  return (def and def.name) or tostring(species)
end

function SilphTracker.install(mod, runtime, Weights, ElusiveScent)
  local function scentFactor()
    if not runtime:isActive(ElusiveScent.EFFECT_ID) then return nil end
    return ElusiveScent.resolveStrength(mod.options:get(ElusiveScent.STRENGTH_OPTION))
  end

  local function applyScent(dist)
    local factor = scentFactor()
    if not factor then return dist end
    local rare = Weights.rarestSpecies(dist)
    return Weights.boostDistribution(dist, rare, factor)
  end

  local function preview(mapId, terrain)
    if mod.world and type(mod.world.effectiveEncounters) == "function" then
      local ok, info = pcall(mod.world.effectiveEncounters, mod.world, mapId, terrain)
      if ok and info and type(info.dist) == "table" then
        return applyScent(info.dist)
      end
    end
    local registry = mod.content and mod.content.encounters
    local encDef
    if registry and type(registry.get) == "function" then
      local ok, value = pcall(registry.get, registry, mapId)
      if ok then encDef = value end
    end
    return applyScent(Weights.distribution(encDef, terrain))
  end

  function SilphTracker.scan(game)
    local current = mod.world:current()
    if not current or not current.mapId then return {}, "NO LOCAL SIGNAL" end

    local combined = {}
    for _, terrain in ipairs({ "grass", "water" }) do
      local dist = preview(current.mapId, terrain)
      local total = Weights.total(dist)
      if total > 0 then
        for species, weight in pairs(dist) do
          local share = weight / total
          local band = Weights.signalBand(weight, total)
          local old = combined[species]
          if not old or BAND_RANK[band] > BAND_RANK[old.band]
              or (BAND_RANK[band] == BAND_RANK[old.band] and share > old.share) then
            combined[species] = { species=species, band=band, share=share }
          end
        end
      end
    end

    local out = {}
    for _, row in pairs(combined) do
      row.name = displayName(game, row.species)
      out[#out + 1] = row
    end
    table.sort(out, function(a, b)
      if a.share ~= b.share then return a.share > b.share end
      if a.name ~= b.name then return a.name < b.name end
      return tostring(a.species) < tostring(b.species)
    end)
    return out, (#out == 0) and "NO LOCAL SIGNAL" or nil
  end

  function SilphTracker.menuRows(game)
    local rows, empty = SilphTracker.scan(game)
    local out = {}
    if #rows == 0 then
      out[#out + 1] = { label=empty or "NO LOCAL SIGNAL", value="noop" }
    else
      for i, row in ipairs(rows) do
        out[#out + 1] = {
          label=("%s - %s"):format(row.name, row.band),
          value="signal_" .. tostring(i),
        }
      end
    end
    out[#out + 1] = { label="CLOSE", value="close" }
    return out
  end

  function SilphTracker.open(game)
    local menu
    menu = mod.ui.ListMenu.new(game, "SILPH TRACKER", SilphTracker.menuRows(game), {
      pageJump=true,
      onChoose=function(row)
        if row and row.value == "close" and menu then menu:close() end
      end,
      onCancel=function()
        if menu then menu:close() end
      end,
    })
    game.stack:push(menu)
  end

  -- Retained for debugging/external consumers; the player-facing UI uses open().
  function SilphTracker.text(game)
    local rows, empty = SilphTracker.scan(game)
    if #rows == 0 then return "SILPH TRACKER\n" .. (empty or "NO LOCAL SIGNAL") end
    local lines = { "SILPH TRACKER" }
    for _, row in ipairs(rows) do
      lines[#lines + 1] = ("%s - %s"):format(row.name, row.band)
    end
    return table.concat(lines, "\n")
  end

  return SilphTracker
end

return SilphTracker
