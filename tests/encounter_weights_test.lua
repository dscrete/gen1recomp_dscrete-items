local Weights = dofile("lib/encounter_weights.lua")
local Elusive = dofile("lib/elusive_scent.lua")

local def = {
  grass = {
    rate = 25,
    buckets = { 128, 192, 224, 240, 248, 252, 254, 255, 256 },
    slots = {
      { species="RATTATA", level=3 },
      { species="PIDGEY", level=3 },
      { species="CATERPIE", level=4 },
      { species="WEEDLE", level=4 },
      { species="PIKACHU", level=5 },
      { species="PIKACHU", level=6 },
      { species="CLEFAIRY", level=7 },
      { species="JIGGLYPUFF", level=7 },
      { species="MEOWTH", level=7 },
    },
  },
}

test("Elusive Scent strength presets resolve", function()
  eq(Elusive.resolveStrength("mild"), 2)
  eq(Elusive.resolveStrength("strong"), 4)
  eq(Elusive.resolveStrength("extreme"), 8)
  eq(Elusive.resolveStrength("bad"), 2)
end)

test("Elusive Scent duration presets mirror Prism Scent", function()
  for _, value in ipairs({ "50", "100", "250", "500", "1000", "2500" }) do
    eq(Elusive.resolveDuration(value), tonumber(value))
  end
  eq(Elusive.resolveDuration("bad"), 250)
end)

test("rarest species uses combined species weight and keeps ties", function()
  local dist = Weights.distribution(def, "grass")
  local rare, minimum = Weights.rarestSpecies(dist)
  eq(minimum, 1)
  check(rare.JIGGLYPUFF)
  check(rare.MEOWTH)
  check(not rare.PIKACHU, "repeated Pikachu slots must combine before rarity")
end)

test("Elusive Scent boosts only tied rare species and keeps species set", function()
  local before = Weights.distribution(def, "grass")
  local boosted = Weights.boostEncounterDef(def, "grass", 4)
  local after = Weights.distribution(boosted, "grass")
  for species in pairs(before) do check(after[species] ~= nil, species .. " disappeared") end
  for species in pairs(after) do check(before[species] ~= nil, species .. " was introduced") end
  check(after.JIGGLYPUFF > before.JIGGLYPUFF)
  check(after.MEOWTH > before.MEOWTH)
  eq(boosted.grass.rate, def.grass.rate, "encounter frequency must not change")
  for i, slot in ipairs(def.grass.slots) do
    eq(boosted.grass.slots[i].level, slot.level, "levels must not change")
  end
end)

test("signal bands are deterministic", function()
  eq(Weights.signalBand(0, 100), "NO SIGNAL")
  eq(Weights.signalBand(1, 100), "FAINT")
  eq(Weights.signalBand(5, 100), "WEAK")
  eq(Weights.signalBand(15, 100), "STRONG")
  eq(Weights.signalBand(30, 100), "VERY STRONG")
end)
