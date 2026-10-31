local Eligibility=dofile("lib/encounter_eligibility.lua")
local Mystery=dofile("lib/mystery_lure.lua")
local Whistle=dofile("lib/species_whistle.lua")
local Glitch=dofile("lib/glitch_detector.lua")

local function fixture()
  local pokemon={
    PIDGEY={dex=16,name="Pidgey"}, CATERPIE={dex=10,name="Caterpie"},
    ZUBAT={dex=41,name="Zubat"}, MAGIKARP={dex=129,name="Magikarp"},
    GOLDEEN={dex=118,name="Goldeen"}, RIOLU={dex=447,name="Riolu"},
    MAREEP={dex=179,name="Mareep"}, MODMON={dex=1100,name="Modmon"},
    BULBASAUR={dex=1,name="Bulbasaur"}, GRENINJA={dex=658,name="Greninja"},
    ARTICUNO={dex=144,name="Articuno"}, RAIKOU={dex=243,name="Raikou"},
    KORAIDON={dex=1007,name="Koraidon"}, MEW={dex=151,name="Mew"},
    ZACIAN_CROWNED_SWORD={dex=888,name="Zacian"},
    RIOLU_SPECIAL={dex=447,name="Riolu"},
  }
  local encounters={
    VIRIDIAN_FOREST={grass={rate=25,slots={
      {species="CATERPIE",level=5},{species="RIOLU",level=7},
      {species="BULBASAUR",level=4},{species="ARTICUNO",level=50},
    }}},
    ROCK_TUNNEL={grass={rate=25,slots={{species="ZUBAT",level=12}}}},
    ROUTE_1={grass={rate=25,buckets={128,200,220,240,255,256},slots={
      {species="PIDGEY",level=4},{species="MAREEP",level=4},
      {species="MODMON",level=5},{species="RAIKOU",level=40},
      {species="GRENINJA",level=5},{species="KORAIDON",level=60},
    }}},
    ROUTE_2={grass={rate=0,slots={{species="MEW",level=5}}}},
    ROUTE_3={grass={rate=25,buckets={0,256},slots={
      {species="ZACIAN_CROWNED_SWORD",level=50},{species="RIOLU_SPECIAL",level=8},
    }}},
    ROUTE_12={water={rate=10,slots={{species="GOLDEEN",level=15}}}},
    roamMons={kind="roamMons",entries={{species="RAIKOU",level=40}}},
    roamMaps={kind="roamMaps",entries={"ROUTE_1"}},
  }
  local data={pokemon=pokemon,encounters=encounters,field={
    fishing={OLD_ROD={always={species="MAGIKARP",level=5}},
      GOOD_ROD={pool={{species="GOLDEEN",level=10}}},
      SUPER_ROD={perMap="superRod"}},
    superRod={ROUTE_12={{species="MODMON",level=22}}},
  }}
  return data
end

test("standalone eligibility protects starters, legends, mythicals and forms by Dex or name",function()
  for _,id in ipairs({"BULBASAUR","GRENINJA","ARTICUNO","RAIKOU","MEW","KORAIDON",
      "ZACIAN_CROWNED_SWORD","MOLTRES_GALARIAN","MEWTWO_MEGA_X","OGERPON_WELLSPRING"}) do
    check(Eligibility.isProtected(id,fixture().pokemon),id.." should be protected")
  end
  check(not Eligibility.isProtected("PIDGEY",fixture().pokemon))
  check(not Eligibility.isProtected("MODMON",fixture().pokemon))
  check(not Eligibility.isProtected("RIOLU_SPECIAL",fixture().pokemon))
end)

test("eligibility reads only merged normal encounter slots and filters protected and zero-rate slots",function()
  local data=fixture()
  local eligible=Eligibility.collect(nil,data)
  for _,id in ipairs({"PIDGEY","CATERPIE","ZUBAT","RIOLU","MAREEP","MODMON",
      "MAGIKARP","GOLDEEN","RIOLU_SPECIAL"}) do
    check(eligible.all[id],id.." should be eligible")
  end
  for _,id in ipairs({"BULBASAUR","ARTICUNO","RAIKOU","GRENINJA","KORAIDON",
      "ZACIAN_CROWNED_SWORD","MEW"}) do
    check(not eligible.all[id],id.." should be excluded")
  end
  check(eligible.habitats.forest.CATERPIE)
  check(eligible.habitats.cave.ZUBAT)
  check(eligible.habitats.water.MAGIKARP)
  check(eligible.habitats.field.MODMON)
end)

test("merged mod registry is authoritative, without depending on an installed content mod",function()
  local data=fixture()
  data.encounters.ROUTE_1.grass.slots[2].species="MAREEP"
  local registry={get=function(_,mapId)
      if mapId=="ROUTE_1" then
        return {grass={rate=25,slots={{species="RIOLU",level=4}}}}
      end
    end,
    each=function(_)
      local used=false
      return function()
        if not used then used=true; return "ROUTE_1" end
      end
    end}
  local mod={content={encounters=registry}}
  local allowed=Eligibility.collect(mod,data)
  check(allowed.all.RIOLU)
  check(not allowed.all.MAREEP,"base ROM encounter should not override merged table")
  check(not allowed.all.PIDGEY)
  check(Eligibility.native(mod,data,"ROUTE_1","RIOLU"))
  check(not Eligibility.native(mod,data,"ROUTE_1","PIDGEY"))
end)

test("Whistle chooser includes seen ordinary-wild mod species, but no protected species",function()
  local data=fixture()
  local save={pokedex={seen={
    MODMON=true,RIOLU=true,PIDGEY=true,BULBASAUR=true,KORAIDON=true,RAIKOU=true,
  }}}
  local hooks,effects,events={},{},{}
  local mod={
    content={item_effects={register=function(_,id,def) effects[id]=def end}},
    hooks={wrap=function(_,id,fn) hooks[id]=fn end},
    events={on=function(_,id,fn) events[id]=fn end},
    options={get=function() return "off" end},
  }
  local runtime={getReusableState=function() return nil end}
  local API=Whistle.install(mod,runtime,nil,Eligibility)
  local rows=API.targetRows({data=data,save=save})
  local found={}
  for _,row in ipairs(rows) do found[row.value]=true end
  check(found.MODMON and found.RIOLU and found.PIDGEY)
  check(not found.BULBASAUR and not found.KORAIDON and not found.RAIKOU)
  check(not found.MAREEP,"unseen normal wild species should stay hidden")
  check(not found.MEW,"gift-only mythical species are not candidates")
end)

test("Glitch Detector never admits gift-only, roaming, starter or legendary species",function()
  local data=fixture()
  local eligible=Eligibility.collect(nil,data)
  local pool=Glitch.anomalyPool(data.pokemon,data.encounters.VIRIDIAN_FOREST,Mystery,
    "VIRIDIAN_FOREST",eligible)
  local found={}
  for _,name in ipairs(pool) do found[name]=true end
  check(found.MODMON and found.MAREEP,"species elsewhere in ordinary wild tables are allowed")
  check(not found.BULBASAUR and not found.RAIKOU and not found.KORAIDON)
  check(not found.CATERPIE and not found.RIOLU,"native/habitat species are excluded")
end)

test("pure eligibility needs no RHH, catalogue, Wilds or other mod API",function()
  local data=fixture()
  local a=Eligibility.collect(nil,data)
  check(a.all.MODMON)
  check(not a.all.KORAIDON)
  check(not a.all.BULBASAUR)
end)
