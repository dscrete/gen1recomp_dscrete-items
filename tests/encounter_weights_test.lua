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

test("rarity compression leaves common baseline and boosts rarer species progressively", function()
  local before = Weights.distribution(def, "grass")
  local after = Weights.compressDistribution(before, 4)
  eq(after.RATTATA, before.RATTATA, "commonest species is the 1x baseline")
  check(after.PIDGEY > before.PIDGEY, "uncommon species should be boosted")
  check(after.PIKACHU > before.PIKACHU, "rare species should be boosted")
  check(after.JIGGLYPUFF > before.JIGGLYPUFF, "very rare species should be boosted")
  local uncommonMultiplier = after.PIDGEY / before.PIDGEY
  local rareMultiplier = after.PIKACHU / before.PIKACHU
  local veryRareMultiplier = after.JIGGLYPUFF / before.JIGGLYPUFF
  check(rareMultiplier > uncommonMultiplier, "rarer species need a larger multiplier")
  check(veryRareMultiplier > rareMultiplier, "very rare species need the largest multiplier")
end)

test("strong Elusive Scent raises Pikachu-like effective share", function()
  local before = Weights.distribution(def, "grass")
  local boosted = Weights.boostEncounterDef(def, "grass", 4)
  local after = Weights.distribution(boosted, "grass")
  local beforeShare = before.PIKACHU / Weights.total(before)
  local afterShare = after.PIKACHU / Weights.total(after)
  check(afterShare > beforeShare, "uncommon/rare species must not be diluted by the scent")
  for species in pairs(before) do check(after[species] ~= nil, species .. " disappeared") end
  for species in pairs(after) do check(before[species] ~= nil, species .. " was introduced") end
  eq(boosted.grass.rate, def.grass.rate, "encounter frequency must not change")
  for i, slot in ipairs(def.grass.slots) do
    eq(boosted.grass.slots[i].level, slot.level, "levels must not change")
  end
end)

test("strong and extreme compress rarity more than mild", function()
  local before = Weights.distribution(def, "grass")
  local mild = Weights.compressDistribution(before, 2)
  local strong = Weights.compressDistribution(before, 4)
  local extreme = Weights.compressDistribution(before, 8)
  local base = before.PIKACHU
  check(mild.PIKACHU / base < strong.PIKACHU / base)
  check(strong.PIKACHU / base < extreme.PIKACHU / base)
end)

test("signal bands are deterministic", function()
  eq(Weights.signalBand(0, 100), "NO SIGNAL")
  eq(Weights.signalBand(1, 100), "FAINT")
  eq(Weights.signalBand(5, 100), "WEAK")
  eq(Weights.signalBand(15, 100), "STRONG")
  eq(Weights.signalBand(30, 100), "VERY STRONG")
end)
