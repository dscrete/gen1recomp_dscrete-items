local Shiny = dofile("lib/shiny_finder.lua")

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

test("Shiny Finder produces valid Gen 1 virtual-shiny DVs", function()
  for i = 1, 8 do
    local dvs = Shiny.makeShinyDVs(sequence({ i }))
    check(Shiny.isKnownShinyShape(dvs))
  end
end)

test("Shiny Finder chance presets resolve safely", function()
  for _, value in ipairs({ "1", "10", "100", "1000" }) do
    check(Shiny.resolveChanceDenominator(value) == tonumber(value))
  end
  check(Shiny.resolveChanceDenominator("not-a-preset") == 100)
end)

test("Shiny Finder duration presets resolve safely", function()
  for _, value in ipairs({ "50", "100", "250", "500", "1000", "2500" }) do
    check(Shiny.resolveDuration(value) == tonumber(value))
  end
  check(Shiny.resolveDuration("not-a-preset") == 250)
end)

test("Shiny Finder chance boundary is deterministic", function()
  check(Shiny.rollSucceeds(sequence({ 1 })))
  check(not Shiny.rollSucceeds(sequence({ 2 })))
  check(not Shiny.rollSucceeds(sequence({ 100 })))
end)

test("Shiny Finder supports guaranteed and rarer configured odds", function()
  check(Shiny.rollSucceeds(sequence({ 1 }), 1, 1))
  check(not Shiny.rollSucceeds(sequence({ 10 }), 1, 10))
  check(not Shiny.rollSucceeds(sequence({ 1000 }), 1, 1000))
end)

test("seeded Shiny Finder simulation stays near one percent", function()
  math.randomseed(0x5A1F1)
  local trials, successes = 100000, 0
  for _ = 1, trials do
    if Shiny.rollSucceeds(math.random) then successes = successes + 1 end
  end
  local rate = successes / trials
  check(math.abs(rate - 0.01) <= 0.0015,
    ("observed rate %.5f outside tolerance"):format(rate))
end)
