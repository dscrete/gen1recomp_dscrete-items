-- Shared encounter-table helpers for DScrete encounter modifiers and readers.
-- Pure Lua so weighting rules can be tested without a Gen1Recomp checkout.

local EncounterWeights = {}

local DEFAULT_BUCKETS = { 51, 102, 128, 153, 179, 204, 230, 242, 252, 256 }

local function copySlot(slot)
  if type(slot) ~= "table" then return slot end
  local out = {}
  for k, v in pairs(slot) do out[k] = v end
  return out
end

function EncounterWeights.terrainTable(encDef, terrain)
  if type(encDef) ~= "table" then return nil end
  if terrain == "water" then return encDef.water end
  -- Gen 1 caves use the grass encounter table while ctx.terrain is indoor.
  return encDef.grass
end

function EncounterWeights.slotWeights(tableDef)
  local out = {}
  if type(tableDef) ~= "table" or type(tableDef.slots) ~= "table" then return out end
  local buckets = tableDef.buckets or DEFAULT_BUCKETS
  local previous = 0
  for i, slot in ipairs(tableDef.slots) do
    local threshold = tonumber(buckets[i]) or previous
    local weight = math.max(0, threshold - previous)
    previous = threshold
    out[i] = { species = slot.species, level = slot.level, weight = weight }
  end
  return out
end

function EncounterWeights.distributionFromTable(tableDef)
  local dist = {}
  for _, row in ipairs(EncounterWeights.slotWeights(tableDef)) do
    if row.species and row.weight > 0 then
      dist[row.species] = (dist[row.species] or 0) + row.weight
    end
  end
  return dist
end

function EncounterWeights.distribution(encDef, terrain)
  return EncounterWeights.distributionFromTable(
    EncounterWeights.terrainTable(encDef, terrain))
end

function EncounterWeights.rarestSpecies(dist)
  local rare, minimum = {}, nil
  for species, weight in pairs(dist or {}) do
    weight = tonumber(weight) or 0
    if weight > 0 and (minimum == nil or weight < minimum) then
      rare, minimum = { [species] = true }, weight
    elseif weight > 0 and weight == minimum then
      rare[species] = true
    end
  end
  return rare, minimum
end

function EncounterWeights.total(dist)
  local n = 0
  for _, weight in pairs(dist or {}) do n = n + (tonumber(weight) or 0) end
  return n
end

-- Elusive Scent is a rarity-compression effect, not a "boost only the rarest"
-- effect. The commonest species is the baseline (1x). Every species below that
-- weight receives a progressively larger multiplier, with lower weights gaining
-- more. The strength value is the upper multiplier approached by extremely rare
-- species: mild=2, strong=4, extreme=8.
--
-- The square makes the curve gentle around common/uncommon species and stronger
-- near the rare end. This preserves the area's ordering while narrowing the gap.
function EncounterWeights.rarityMultiplier(weight, maximum, strength)
  weight, maximum, strength = tonumber(weight) or 0, tonumber(maximum) or 0,
    tonumber(strength) or 1
  if weight <= 0 or maximum <= 0 or strength <= 1 then return 1 end
  local ratio = math.max(0, math.min(1, weight / maximum))
  local rarity = 1 - ratio
  return 1 + (strength - 1) * rarity * rarity
end

function EncounterWeights.compressDistribution(dist, strength)
  local maximum = 0
  for _, weight in pairs(dist or {}) do
    weight = tonumber(weight) or 0
    if weight > maximum then maximum = weight end
  end
  local out = {}
  for species, weight in pairs(dist or {}) do
    weight = tonumber(weight) or 0
    out[species] = weight * EncounterWeights.rarityMultiplier(weight, maximum, strength)
  end
  return out
end

-- Retained as a small generic helper for later targeted modifiers.
function EncounterWeights.boostDistribution(dist, selected, factor)
  factor = tonumber(factor) or 1
  local out = {}
  for species, weight in pairs(dist or {}) do
    out[species] = (tonumber(weight) or 0) * (selected and selected[species] and factor or 1)
  end
  return out
end

function EncounterWeights.boostEncounterDef(encDef, terrain, strength)
  if type(encDef) ~= "table" then return encDef, {} end
  local source = EncounterWeights.terrainTable(encDef, terrain)
  if not source then return encDef, {} end
  local dist = EncounterWeights.distributionFromTable(source)
  local compressed = EncounterWeights.compressDistribution(dist, strength)
  if EncounterWeights.total(compressed) <= 0 or (tonumber(strength) or 1) <= 1 then
    return encDef, compressed
  end

  local copy = {}
  for k, v in pairs(encDef) do copy[k] = v end
  local target = {}
  for k, v in pairs(source) do target[k] = v end
  target.slots = {}
  for i, slot in ipairs(source.slots or {}) do target.slots[i] = copySlot(slot) end

  local rows = EncounterWeights.slotWeights(source)
  local scaled, total = {}, 0
  for i, row in ipairs(rows) do
    local baseSpeciesWeight = dist[row.species] or 0
    local wantedSpeciesWeight = compressed[row.species] or baseSpeciesWeight
    local multiplier = baseSpeciesWeight > 0 and (wantedSpeciesWeight / baseSpeciesWeight) or 1
    local weight = row.weight * multiplier
    scaled[i] = weight
    total = total + weight
  end
  if total <= 0 then return encDef, compressed end

  target.buckets = {}
  local cumulative = 0
  for i, weight in ipairs(scaled) do
    cumulative = cumulative + weight
    local threshold = (i == #scaled) and 256
      or math.floor((cumulative * 256 / total) + 0.5)
    if i > 1 and threshold < target.buckets[i - 1] then
      threshold = target.buckets[i - 1]
    end
    if threshold > 256 then threshold = 256 end
    target.buckets[i] = threshold
  end

  if terrain == "water" then copy.water = target else copy.grass = target end
  return copy, compressed
end

function EncounterWeights.signalBand(weight, total)
  weight, total = tonumber(weight) or 0, tonumber(total) or 0
  if weight <= 0 or total <= 0 then return "NO SIGNAL" end
  local share = weight / total
  if share >= 0.30 then return "VERY STRONG" end
  if share >= 0.15 then return "STRONG" end
  if share >= 0.05 then return "WEAK" end
  return "FAINT"
end

return EncounterWeights
