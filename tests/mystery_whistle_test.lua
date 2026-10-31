local Mystery=dofile("lib/mystery_lure.lua")
local Whistle=dofile("lib/species_whistle.lua")
local Weights=dofile("lib/encounter_weights.lua")

test("Mystery Lure share presets resolve", function()
  eq(Mystery.resolveShare("low"),0.05)
  eq(Mystery.resolveShare("medium"),0.10)
  eq(Mystery.resolveShare("high"),0.20)
  eq(Mystery.resolveShare("bad"),0.05)
end)

test("Mystery Lure draws seen habitat candidates only from normal wild tables", function()
  local Eligibility=dofile("lib/encounter_eligibility.lua")
  local data={pokemon={
    CATERPIE={dex=10}, PIKACHU={dex=25}, ARTICUNO={dex=144},
    CHIKORITA={dex=152}, RIOLU={dex=447}, MEWTWO={dex=150},
  },encounters={
    VIRIDIAN_FOREST={grass={rate=25,slots={
      {species="CATERPIE",level=4},{species="ARTICUNO",level=5},
      {species="CHIKORITA",level=5},{species="RIOLU",level=5},
    }}},
    ROUTE_1={grass={rate=25,slots={{species="PIKACHU",level=5}}}},
  }}
  local save={pokedex={seen={CATERPIE=true,PIKACHU=true,ARTICUNO=true,CHIKORITA=true}}}
  local eligible=Eligibility.collect(nil,data)
  local forest=Mystery.candidates(data,save,"VIRIDIAN_FOREST","grass",true,eligible)
  eq(#forest,1); eq(forest[1],"CATERPIE")
  local unseen=Mystery.candidates(data,save,"VIRIDIAN_FOREST","grass",false,eligible)
  eq(#unseen,2); eq(unseen[1],"CATERPIE"); eq(unseen[2],"RIOLU")
end)

test("Mystery habitat classification is stable", function()
  eq(Mystery.habitat("VIRIDIAN_FOREST","grass"),"forest")
  eq(Mystery.habitat("ROCK_TUNNEL_1F","indoor"),"cave")
  eq(Mystery.habitat("ROUTE_12","water"),"water")
  eq(Mystery.habitat("ROUTE_1","grass"),"field")
end)

test("Species Whistle presets resolve", function()
  eq(Whistle.resolveStrength("mild"),2)
  eq(Whistle.resolveStrength("strong"),4)
  eq(Whistle.resolveStrength("extreme"),8)
  eq(Whistle.resolveDuration("25"),25)
  eq(Whistle.resolveDuration("1000"),1000)
  eq(Whistle.resolveDuration("bad"),100)
  eq(Whistle.resolveNonlocalRate("0.5"),0.005)
  eq(Whistle.resolveNonlocalRate("1"),0.01)
  eq(Whistle.resolveNonlocalRate("2"),0.02)
end)

test("Whistle protection policy includes modern legendaries and starters", function()
  local Eligibility=dofile("lib/encounter_eligibility.lua")
  check(Eligibility.isProtected("MEWTWO"))
  check(Eligibility.isProtected("KORAIDON"))
  check(Eligibility.isProtected("CHIKORITA"))
  check(Eligibility.isProtected("GRENINJA"))
  check(not Eligibility.isProtected("PIKACHU"))
end)

test("targeted encounter boost preserves species and levels", function()
  local def={grass={rate=25,buckets={128,192,256},slots={
    {species="PIDGEY",level=3},{species="RATTATA",level=4},{species="PIKACHU",level=5},
  }}}
  local before=Weights.distribution(def,"grass")
  local boosted,present=Weights.boostSpeciesEncounterDef(def,"grass","PIKACHU",4)
  check(present)
  local after=Weights.distribution(boosted,"grass")
  check(after.PIKACHU>before.PIKACHU)
  eq(boosted.grass.rate,def.grass.rate)
  for i,slot in ipairs(def.grass.slots) do eq(boosted.grass.slots[i].level,slot.level) end
end)

test("reserved species share can introduce a nonlocal target", function()
  local out=Weights.reserveSpecies({PIDGEY=80,RATTATA=20},"ABRA",0.10)
  eq(Weights.total(out),100)
  eq(out.ABRA,10)
  eq(out.PIDGEY,72)
  eq(out.RATTATA,18)
end)
