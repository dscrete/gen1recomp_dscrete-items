local Weights=dofile("lib/encounter_weights.lua")
local Resonator=dofile("lib/prototype_resonator.lua")
local SafariKit=dofile("lib/safari_kit.lua")

local TABLE={
  slots={
    {species="PIDGEY",level=3},{species="RATTATA",level=4},{species="PIDGEY",level=5},
  },
  buckets={102,204,256},
}

test("Prototype Resonator presets use area-relative caps",function()
  eq(Resonator.resolveCap("mild"),10)
  eq(Resonator.resolveCap("strong"),20)
  eq(Resonator.resolveCap("extreme"),35)
  eq(Resonator.resolveDuration("500"),500)
  eq(Resonator.resolveDuration("bogus"),250)
end)

test("Prototype Resonator preserves native level spread while shifting upward",function()
  eq(Resonator.raiseLevel(3,40,5,20),23)
  eq(Resonator.raiseLevel(4,40,5,20),24)
  eq(Resonator.raiseLevel(5,40,5,20),25)
  eq(Resonator.raiseLevel(5,12,5,20),12)
  eq(Resonator.raiseLevel(5,4,5,20),5,"it never lowers a native encounter")
end)

test("Prototype Resonator clamps extreme levels to 100",function()
  eq(Resonator.raiseLevel(90,100,90,35),100)
  eq(Resonator.raiseLevel(88,100,90,35),98)
end)

test("Prototype Resonator uses first conscious party member live",function()
  local save={party={
    {species="PIKACHU",level=40,hp=0},
    {species="EEVEE",level=27,hp=1},
    {species="MEOWTH",level=50,hp=10},
  }}
  local mon,level=Resonator.firstUsableLead(save)
  eq(mon.species,"EEVEE")
  eq(level,27)
  save.party[2].hp=0
  mon,level=Resonator.firstUsableLead(save)
  eq(mon.species,"MEOWTH")
  eq(level,50)
end)

test("Prototype Resonator derives native maximum from encounter slots",function()
  eq(Resonator.maxLevelFromTable(Weights,TABLE),5)
  eq(Resonator.maxLevelFromCandidates({{level=10},{level=15},{level=12}}),15)
end)

test("Prototype Resonator excludes Safari maps",function()
  check(Resonator.isSafari("SAFARI_ZONE_CENTER"))
  check(not Resonator.isSafari("ROUTE_2"))
end)

test("Safari Kit presets and map classifier are deterministic",function()
  eq(SafariKit.resolveBaitStrength("mild"),2)
  eq(SafariKit.resolveBaitStrength("strong"),4)
  eq(SafariKit.resolveBaitStrength("extreme"),8)
  eq(SafariKit.resolvePassSteps("250"),250)
  eq(SafariKit.resolvePassBalls("5"),5)
  check(SafariKit.isSafariInterior("SAFARI_ZONE_CENTER"))
  check(not SafariKit.isSafariInterior("SAFARI_ZONE_GATE"))
  check(not SafariKit.isSafari("ROUTE_15"))
end)

test("Safari Bait compresses rarity without changing species membership",function()
  local dist=Weights.distributionFromTable(TABLE)
  local boosted=Weights.compressDistribution(dist,SafariKit.resolveBaitStrength("strong"))
  eq(boosted.PIDGEY~=nil,true)
  eq(boosted.RATTATA~=nil,true)
  check(boosted.RATTATA/dist.RATTATA > boosted.PIDGEY/dist.PIDGEY,
    "the rarer species should receive the larger relative boost")
end)
