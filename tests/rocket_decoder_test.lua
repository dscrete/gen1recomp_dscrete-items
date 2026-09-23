local RocketDecoder=dofile("lib/rocket_decoder.lua")
local Incidents=dofile("lib/rocket_incidents.lua")

test("Rocket Decoder state roundtrips delimiter-safe scalar values",function()
  local state={version="1",active="intercepted_shipment",summary="A|B=C%"}
  local encoded=RocketDecoder.encodeState(state)
  local decoded=RocketDecoder.decodeState(encoded)
  eq(decoded.version,"1")
  eq(decoded.active,"intercepted_shipment")
  eq(decoded.summary,"A|B=C%")
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
  check(src:find("HAND IT OVER",1,true)~=nil)
  check(src:find("WHAT'S INSIDE?",1,true)~=nil)
  check(src:find("BOSS SENT ME",1,true)~=nil)
  check(src:find("I HEARD RADIO",1,true)~=nil)
  check(src:find('setOperativeFlag("ronnie","fooled"',1,true)~=nil)
  check(src:find("ROCKET_SUCCESS",1,true)~=nil)
  check(src:find("RESOLVED_ALTERNATE",1,true)~=nil)
end)
