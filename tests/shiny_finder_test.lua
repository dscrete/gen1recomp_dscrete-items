local Prism = dofile("lib/shiny_finder.lua")

local function sequence(values)
  local i = 0
  return function(lo, hi)
    i = i + 1
    local value = values[i]
    check(value ~= nil, "sequence exhausted")
    check(value >= lo and value <= hi, "sequence value outside requested range")
    return value
  end
end

test("Prism Scent produces valid Gen 1 virtual-shiny DVs", function()
  for i = 1, 8 do
    local dvs = Prism.makeShinyDVs(sequence({ i }))
    check(Prism.isKnownShinyShape(dvs))
  end
end)

test("Prism Scent chance presets resolve safely", function()
  for _, value in ipairs({ "1", "10", "100", "1000" }) do
    check(Prism.resolveChanceDenominator(value) == tonumber(value))
  end
  check(Prism.resolveChanceDenominator("not-a-preset") == 100)
end)

test("Prism Scent duration presets resolve safely", function()
  for _, value in ipairs({ "50", "100", "250", "500", "1000", "2500" }) do
    check(Prism.resolveDuration(value) == tonumber(value))
  end
  check(Prism.resolveDuration("not-a-preset") == 250)
end)

test("Prism Scent chance boundary is deterministic", function()
  check(Prism.rollSucceeds(sequence({ 1 })))
  check(not Prism.rollSucceeds(sequence({ 2 })))
  check(not Prism.rollSucceeds(sequence({ 100 })))
end)

test("Prism Scent supports guaranteed and rarer configured odds", function()
  check(Prism.rollSucceeds(sequence({ 1 }), 1, 1))
  check(not Prism.rollSucceeds(sequence({ 10 }), 1, 10))
  check(not Prism.rollSucceeds(sequence({ 1000 }), 1, 1000))
end)

test("Prism Scent marks visible-spawn records with reusable shiny DVs", function()
  local dvs = Prism.makeShinyDVs(sequence({ 1 }))
  local record = { species = "PIKACHU", level = 5 }
  check(Prism.markVisibleSpawn(record, dvs))
  check(record.isShiny)
  check(record.shiny)
  check(Prism.isKnownShinyShape(record.dscretePrismDVs))
  check(record.dscretePrismDVs ~= dvs, "compatibility marker must own a copy")
end)

test("seeded Prism Scent simulation stays near one percent", function()
  math.randomseed(0x5A1F1)
  local trials, successes = 100000, 0
  for _ = 1, trials do
    if Prism.rollSucceeds(math.random) then successes = successes + 1 end
  end
  local rate = successes / trials
  check(math.abs(rate - 0.01) <= 0.0015,
    ("observed rate %.5f outside tolerance"):format(rate))
end)
