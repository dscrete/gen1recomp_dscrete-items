local RocketDecoder=dofile("lib/rocket_decoder.lua")
local Incidents=dofile("lib/rocket_incidents.lua")

test("Rocket Decoder state roundtrips delimiter-safe scalar values",function()
  local state={version="1",active="intercepted_shipment",summary="A|B=C%",op_milo_last_battle="win"}
  local encoded=RocketDecoder.encodeState(state)
  local decoded=RocketDecoder.decodeState(encoded)
  eq(decoded.version,"1")
  eq(decoded.active,"intercepted_shipment")
  eq(decoded.summary,"A|B=C%")
  eq(decoded.op_milo_last_battle,"win")
end)

test("Rocket Decoder progression gates use fly-town progress rather than route save.visited bits",function()
  local early={visited={VIRIDIAN_CITY=true},inventory={}}
  local rows=RocketDecoder.eligibleIncidents(Incidents,early,{})
  eq(#rows,1)
  eq(rows[1].id,"hidden_cache")

  local cerulean={visited={CERULEAN_CITY=true},inventory={}}
  rows=RocketDecoder.eligibleIncidents(Incidents,cerulean,{})
  eq(#rows,1)
  eq(rows[1].id,"intercepted_shipment")

  local late={visited={VERMILION_CITY=true},inventory={CASCADEBADGE=1,HM_CUT=1}}
  rows=RocketDecoder.eligibleIncidents(Incidents,late,{})
  eq(#rows,1)
  eq(rows[1].id,"illegal_experiment")
end)

test("Rocket Decoder current-region presence proves an incident location is reachable",function()
  local progress={visited={},inventory={},currentMap="ROUTE_5"}
  local rows=RocketDecoder.eligibleIncidents(Incidents,progress,{})
  eq(#rows,1)
  eq(rows[1].id,"intercepted_shipment")
end)

test("Rocket Decoder selects fresh reachable incidents before repeats",function()
  local progress={
    visited={VIRIDIAN_CITY=true,CERULEAN_CITY=true,VERMILION_CITY=true},
    inventory={CASCADEBADGE=1,HM_CUT=1},
  }
  local rows=RocketDecoder.eligibleIncidents(Incidents,progress,{last_id="hidden_cache",done_hidden_cache="1"})
  eq(#rows,2)
  local ids={}
  for _,row in ipairs(rows) do ids[row.id]=true end
  check(ids.intercepted_shipment)
  check(ids.illegal_experiment)
  check(not ids.hidden_cache)
end)

test("Rocket Decoder placement stays on open overview cells",function()
  local overview={width=7,height=5,rows={
    "       ",
    "  ...  ",
    "  ...  ",
    "  ...  ",
    "       ",
  }}
  local x,y=RocketDecoder.findOpenCell(overview,0,0,{})
  check(x~=nil and y~=nil)
  eq(overview.rows[y+1]:sub(x+1,x+1),".")
  local occupied={[y*1000+x]=true}
  local x2,y2=RocketDecoder.findOpenCell(overview,x,y,occupied)
  check(x2~=nil and not (x2==x and y2==y))
end)

test("Rocket battle tier follows badge progress without exact party-level rubberbanding",function()
  eq(RocketDecoder.badgeTier({inventory={}},Incidents.BADGES),1)
  eq(RocketDecoder.badgeTier({inventory={BOULDERBADGE=1}},Incidents.BADGES),1)
  eq(RocketDecoder.badgeTier({inventory={BOULDERBADGE=1,CASCADEBADGE=1}},Incidents.BADGES),2)
  eq(RocketDecoder.badgeTier({inventory={BOULDERBADGE=1,CASCADEBADGE=1,THUNDERBADGE=1,RAINBOWBADGE=1}},Incidents.BADGES),3)
  eq(RocketDecoder.badgeTier({inventory={BOULDERBADGE=1,CASCADEBADGE=1,THUNDERBADGE=1,RAINBOWBADGE=1,SOULBADGE=1,MARSHBADGE=1}},Incidents.BADGES),4)
end)

test("Named Rocket operatives have distinct four-tier authored parties",function()
  local seenTrainerIds={}
  for id,op in pairs(Incidents.OPERATIVES) do
    check(op.trainerId~=nil,id.." needs a trainer id")
    check(not seenTrainerIds[op.trainerId],"trainer ids must be unique")
    seenTrainerIds[op.trainerId]=true
    eq(#op.parties,4,id.." should have four progression tiers")
    check(#op.parties[1]>=2,id.." tier one should be a real party")
  end
  check(Incidents.OPERATIVES.ronnie.parties[1][1].species~=
        Incidents.OPERATIVES.milo.parties[1][1].species,
        "operatives should not all share the same party")
end)

test("Rocket incidents ship three distinct extensible templates and named operatives",function()
  eq(#Incidents.ORDER,3)
  check(Incidents.ALL.intercepted_shipment~=nil)
  check(Incidents.ALL.hidden_cache~=nil)
  check(Incidents.ALL.illegal_experiment~=nil)
  eq(Incidents.OPERATIVES.ronnie.name,"RONNIE")
  eq(Incidents.OPERATIVES.milo.name,"MILO")
  eq(Incidents.OPERATIVES.cass.name,"CASS")
  check(#Incidents.ALL.intercepted_shipment.transmissions>=3)
  check(Incidents.ALL.intercepted_shipment.interact.ronnie~=nil)
  check(Incidents.ALL.hidden_cache.interact.cache~=nil)
  check(Incidents.ALL.illegal_experiment.interact.device~=nil)
  eq(Incidents.ALL.illegal_experiment.actors[2].sprite,"SPRITE_SUPER_NERD")
  eq(Incidents.ALL.hidden_cache.minTrainerTier,1)
  eq(Incidents.ALL.intercepted_shipment.minTrainerTier,2)
  eq(Incidents.ALL.illegal_experiment.minTrainerTier,2)
end)

test("Shipment prototype reward is randomized from implemented-style DScrete item keys",function()
  local pool=Incidents.ALL.intercepted_shipment.prototypePool
  check(#pool>=5)
  local found={}
  for _,id in ipairs(pool) do found[id]=true end
  check(found.prism_scent and found.species_whistle and found.prototype_resonator)
  check(not found.rocket_decoder and not found.pokedex_chip,
    "permanent gadgets must not enter random prototype cargo")
end)

test("Rocket incident conversations keep multiple authored paths and persistent memory hooks",function()
  local f=assert(io.open("lib/rocket_incidents.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find('label="ASK"',1,true)~=nil)
  check(src:find('label="BLUFF"',1,true)~=nil)
  check(src:find('label="TALK"',1,true)~=nil)
  check(src:find('label="MACHINE"',1,true)~=nil)
  check(src:find("WHERE'S CACHE?",1,true)==nil,
    "placeholder interrogation copy must not return")
  check(src:find('mem.last_battle=="win"',1,true)~=nil,
    "Milo's cooperative path should depend on actual battle history")
  check(src:find('setOperativeFlag("ronnie","fooled"',1,true)~=nil)
  check(src:find("ROCKET_SUCCESS",1,true)~=nil)
  check(src:find("RESOLVED_ALTERNATE",1,true)~=nil)
end)

test("Rocket conversation choices use compact in-world Menu instead of opaque ListMenu",function()
  local f=assert(io.open("lib/rocket_decoder.lua","r"))
  local src=f:read("*a"); f:close()
  local start=assert(src:find("local function choose(ctx,title,rows,env)",1,true))
  local finish=assert(src:find("local function makeEnv",start,true))
  local choiceSrc=src:sub(start,finish-1)
  check(choiceSrc:find("mod.ui.Menu.new",1,true)~=nil)
  check(choiceSrc:find("mod.ui.ListMenu.new",1,true)==nil,
    "conversation replies should leave the overworld visible")
  check(src:find('battle_wins',1,true)~=nil)
  check(src:find('last_battle',1,true)~=nil)
end)
