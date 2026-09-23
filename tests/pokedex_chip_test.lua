local PokedexChip=dofile("lib/pokedex_chip.lua")
local Weights=dofile("lib/encounter_weights.lua")

test("Pokedex Chip level range uses species slots and injected-species fallback",function()
  local tableDef={buckets={128,256},slots={
    {species="PIDGEY",level=4},{species="RATTATA",level=7},
  }}
  local lo,hi=PokedexChip.levelRange(Weights,tableDef,"PIDGEY")
  eq(lo,4); eq(hi,4)
  local injectedLo,injectedHi=PokedexChip.levelRange(Weights,tableDef,"PIKACHU")
  eq(injectedLo,4); eq(injectedHi,7)
end)

test("Pokedex Chip fishing distributions preserve duplicate candidate weight",function()
  local dist,count=PokedexChip.fishingDistribution({
    {species="GOLDEEN",level=10},
    {species="POLIWAG",level=10},
    {species="GOLDEEN",level=15},
  })
  eq(count,3)
  eq(dist.GOLDEEN,2)
  eq(dist.POLIWAG,1)
end)

test("Pokedex Chip is wired to the native dex entry instead of only GADGETS",function()
  local f=assert(io.open("lib/pokedex_chip.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find('require,"src.ui.DexEntryMenu"',1,true)~=nil,
    "chip should identify the native DexEntryMenu")
  check(src:find('wasPressed("select")',1,true)~=nil,
    "SELECT should open encounter data from a dex entry")
  check(src:find("NO CURRENT HABITAT",1,true)~=nil,
    "seen species with no current encounter source needs a clear empty state")
  check(src:find("PrototypeResonator.raiseLevel",1,true)~=nil,
    "live level ranges should reflect an active Prototype Resonator")
end)
