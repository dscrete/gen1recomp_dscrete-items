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

test("Pokedex Chip replacement preview matches post-selection fishing modifiers",function()
  local dist=PokedexChip.applyFishingReplacement(Weights,{GOLDEEN=1,POLIWAG=1},"GOLDEEN",0.30)
  local total=Weights.total(dist)
  local share=dist.GOLDEEN/total
  check(math.abs(share-0.65)<0.00001,"native 50% plus 30% replacement should end at 65%")
  local nonlocal=PokedexChip.applyFishingReplacement(Weights,{GOLDEEN=1,POLIWAG=1},"PIKACHU",0.02)
  local nonlocalTotal=Weights.total(nonlocal)
  check(math.abs(nonlocal.PIKACHU/nonlocalTotal-0.02)<0.00001,"nonlocal replacement share should be exact")
end)

test("Pokedex Chip resolves only known highlighted native Pokedex rows",function()
  local menu={index=2,items={
    {value="BULBASAUR"},
    {value="PIKACHU"},
    {value=nil},
  }}
  eq(PokedexChip.selectedListSpecies(menu),"PIKACHU")
  menu.index=3
  eq(PokedexChip.selectedListSpecies(menu),nil)
  menu.index=99
  eq(PokedexChip.selectedListSpecies(menu),nil)
end)

test("Pokedex Chip is wired to the native dex list and entry page",function()
  local f=assert(io.open("lib/pokedex_chip.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find('require,"src.ui.PokedexMenu"',1,true)~=nil,
    "chip should identify the native PokedexMenu list")
  check(src:find('require,"src.ui.DexEntryMenu"',1,true)~=nil,
    "chip should retain the native DexEntryMenu shortcut")
  check(src:find('wasPressed("select")',1,true)~=nil,
    "SELECT should open encounter data from native dex screens")
  check(src:find("selectedListSpecies",1,true)~=nil,
    "highlighted seen rows should route directly to AREA DATA")
  check(src:find("NO CURRENT HABITAT",1,true)~=nil,
    "seen species with no current encounter source needs a clear empty state")
  check(src:find("PrototypeResonator.raiseLevel",1,true)~=nil,
    "live level ranges should reflect an active Prototype Resonator")
  check(src:find("Font.drawCode(Theme.cursor",1,true)~=nil,
    "chip should use the native menu cursor glyph")
end)
