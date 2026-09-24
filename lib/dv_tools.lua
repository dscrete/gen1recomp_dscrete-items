-- Shared helpers for DScrete's permanent Gen-1 DV editing tools.
-- Gen 1 stores four primary DVs; HP DV is derived from their low bits.

local DvTools = {}

DvTools.PRIMARY = { "attack", "defense", "speed", "special" }
DvTools.LABEL = { attack="ATK", defense="DEF", speed="SPD", special="SPC" }
DvTools.SHINY_ATTACK = { 2, 3, 6, 7, 10, 11, 14, 15 }

function DvTools.clamp(value)
  value = math.floor(tonumber(value) or 0)
  return math.max(0, math.min(15, value))
end

function DvTools.hpDV(dvs)
  dvs = dvs or {}
  return (DvTools.clamp(dvs.attack) % 2) * 8
    + (DvTools.clamp(dvs.defense) % 2) * 4
    + (DvTools.clamp(dvs.speed) % 2) * 2
    + (DvTools.clamp(dvs.special) % 2)
end

function DvTools.copy(dvs)
  if type(dvs) ~= "table" then return nil end
  local out = {}
  for _, key in ipairs(DvTools.PRIMARY) do out[key] = DvTools.clamp(dvs[key]) end
  out.hp = DvTools.hpDV(out)
  return out
end

function DvTools.equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for _, key in ipairs(DvTools.PRIMARY) do
    if DvTools.clamp(a[key]) ~= DvTools.clamp(b[key]) then return false end
  end
  return DvTools.hpDV(a) == DvTools.hpDV(b)
end

-- Stable across party reordering and level/EXP changes. It is deliberately
-- based on the Pokemon identity fields available in Gen 1 plus its current DV
-- state, so cancelling a Mutation Capsule preview cannot be used to reroll the
-- same Pokemon just by closing/reopening the bag or gaining a level.
function DvTools.signature(mon)
  if type(mon) ~= "table" or type(mon.dvs) ~= "table" then return nil end
  local d = DvTools.copy(mon.dvs)
  return table.concat({
    tostring(mon.species or "?"),
    tostring(mon.nickname or ""),
    tostring(mon.otName or mon.ot or ""),
    tostring(mon.otId or mon.trainerId or ""),
    tostring(mon.catchRate or ""),
    tostring(mon.traded and 1 or 0),
    tostring(d.attack), tostring(d.defense), tostring(d.speed), tostring(d.special),
  }, "|")
end

-- Apply a complete DV block and immediately rebuild the stored party stats.
-- A Pokemon that was at full HP remains full; otherwise current HP is kept as
-- an absolute value and merely clamped to the new maximum. Fainted Pokemon stay
-- fainted rather than being accidentally revived by a genetics item.
function DvTools.apply(data, mon, dvs, Stats)
  if not (data and data.pokemon and mon and data.pokemon[mon.species]
      and Stats and type(Stats.calc) == "function") then return false end
  local normalized = DvTools.copy(dvs)
  if not normalized then return false end
  local oldStats = mon.stats
  local oldHP = tonumber(mon.hp)
  local wasFull = oldStats and oldHP ~= nil and oldHP == oldStats.hp
  mon.dvs = normalized
  mon.stats = Stats.calc(data.pokemon[mon.species], mon.level or 1,
    mon.dvs, mon.statExp)
  if oldHP == nil or wasFull then
    mon.hp = mon.stats.hp
  else
    mon.hp = math.max(0, math.min(oldHP, mon.stats.hp))
  end
  return true
end

return DvTools
