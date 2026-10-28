-- Cross-item persistence, inventory and failure-atomicity regression contracts.
local Items = dofile("lib/items.lua")
local Runtime = dofile("lib/runtime.lua")
local MapBeacon = dofile("lib/map_beacon.lua")
local BlankTM = dofile("lib/blank_tm.lua")
local MutationCapsule = dofile("lib/mutation_capsule.lua")
local DvTools = dofile("lib/dv_tools.lua")

local function store()
  local data = {}
  return {
    get=function(_,key,default) local v=data[key]; if v==nil then return default end; return v end,
    set=function(_,key,value) data[key]=value end,
    values=data,
  }
end

test("all 19 catalogue bag entries register a unique real item and effect", function()
  local seen, defs = {}, {}
  Items.registerBagItems({content={items={register=function(_,id,def)
    check(not seen[id], "duplicate registration "..id)
    seen[id]=true; defs[id]=def
  end}}})
  local count=0
  for _, item in ipairs(Items.all) do
    check(item.implemented, "unimplemented catalogue entry: "..item.key)
    if item.itemId then
      count=count+1
      check(defs[item.itemId], "unregistered bag item: "..item.key)
      eq(defs[item.itemId].id,item.itemId)
      eq(defs[item.itemId].effect,item.effect)
      check(defs[item.itemId].tossable, "bag consumable must be tossable")
    end
  end
  eq(count,19)
end)

test("map anchors refuse malformed persisted coordinates without changing save state", function()
  local s=store()
  local r=Runtime.new(s)
  for _,p in ipairs({
    {mapId="",x=1,y=1}, {mapId="ROUTE_1",x=-1,y=0},
    {mapId="ROUTE_1",x=1.5,y=1}, {mapId="ROUTE_1",x=1,y=math.huge},
  }) do check(not MapBeacon.set(r,p)) end
  eq(MapBeacon.get(r),nil)
  check(MapBeacon.set(r,{mapId="ROUTE_1",x=1,y=2,facing="left"}))
  local snapshot=MapBeacon.get(r)
  eq(snapshot.mapId,"ROUTE_1"); eq(snapshot.x,1); eq(snapshot.y,2)
  eq(snapshot.facing,"left")
  local reloaded=Runtime.new(s)
  eq(MapBeacon.get(reloaded).x,1)
  reloaded:setReusableState("map_beacon",{mapId="ROUTE_1",x=-99,y=2})
  eq(MapBeacon.get(reloaded),nil)
end)

test("blank TM detects missing and extra recorded stack copies without deleting any move", function()
  local s=store(); local r=Runtime.new(s)
  r:setReusableState("blank_tm",{recordings={"TACKLE","GROWL"}})
  local save={inventory={[BlankTM.ITEM_ID]=1,[BlankTM.RECORDED_ITEM_ID]=2}}
  check(BlankTM.isConsistent(save,r))
  save.inventory[BlankTM.RECORDED_ITEM_ID]=1
  check(not BlankTM.isConsistent(save,r))
  save.inventory[BlankTM.RECORDED_ITEM_ID]=3
  check(not BlankTM.isConsistent(save,r))
  save.inventory[BlankTM.RECORDED_ITEM_ID]=2
  check(BlankTM.isConsistent(save,r))
  eq(#BlankTM.recordings(r),2)
end)

test("blank TM refuses conversion on out-of-sync save without touching bag or records",function()
  local s=store(); local r=Runtime.new(s)
  local save={inventory={[BlankTM.ITEM_ID]=1,[BlankTM.RECORDED_ITEM_ID]=1}}
  local data={moves={TACKLE={name="TACKLE"}}}
  local calls=0
  local Bag={
    remove=function() calls=calls+1 end,
    add=function() calls=calls+1; return true end,
  }
  check(not BlankTM.convert(save,data,"TACKLE",r,Bag))
  eq(calls,0)
  eq(save.inventory[BlankTM.ITEM_ID],1)
  eq(save.inventory[BlankTM.RECORDED_ITEM_ID],1)
  eq(#BlankTM.recordings(r),0)
end)

test("failed or invalid Pokemon stat calculation does not partially mutate DV block", function()
  local data={pokemon={TESTMON={}}}
  local mon={species="TESTMON",level=5,hp=7,
    dvs={attack=1,defense=2,speed=3,special=4,hp=10},
    stats={hp=20,attack=9}}
  local oldDv,oldStats,oldHP=mon.dvs,mon.stats,mon.hp
  local change={attack=9,defense=9,speed=9,special=9}
  check(not DvTools.apply(data,mon,change,{calc=function() error("modded stat failure") end}))
  eq(mon.dvs,oldDv); eq(mon.stats,oldStats); eq(mon.hp,oldHP)
  check(not DvTools.apply(data,mon,change,{calc=function() return {hp=0} end}))
  eq(mon.dvs,oldDv); eq(mon.stats,oldStats); eq(mon.hp,oldHP)
end)

test("mutation offers survive runtime recreation, and full reset removes their preview",function()
  local s=store()
  local r=Runtime.new(s)
  local m={species="TESTMON",nickname="A",dvs={attack=1,defense=2,speed=3,special=4}}
  local rolls={1,0}; local i=0
  local offer,signature=MutationCapsule.offerFor(r,m,function()
    i=i+1; return rolls[i]
  end,DvTools)
  check(offer and signature)
  local again=Runtime.new(s)
  local kept,keptSignature=MutationCapsule.offerFor(again,m,function()
    error("save reload must not reroll",0)
  end,DvTools)
  eq(keptSignature,signature); eq(kept.stat,offer.stat); eq(kept.value,offer.value)
  again:resetPersistent({"mutation_capsule","map_beacon","blank_tm"})
  eq(MutationCapsule.storedOffer(again,m,DvTools),nil)
  eq(again:getReusableState("mutation_capsule",nil),nil)
end)

test("full reset removes unrelated persistent tool state and preserves correct schema",function()
  local s=store(); local r=Runtime.new(s)
  local keys={}
  for _,item in ipairs(Items.all) do
    keys[#keys+1]=item.key
    r:setReusableState(item.key,{active=true})
  end
  r:unlock("rocket_decoder")
  r:activateFieldEffect("prism_scent",10)
  r:resetPersistent(keys)
  eq(r.activeFieldEffect,nil)
  eq(s.values.active_field_effect,nil)
  check(not r:isUnlocked("rocket_decoder"))
  for _,key in ipairs(keys) do
    eq(r:getReusableState(key,nil),nil,"reset left "..key)
  end
  eq(s.values.schema_version,Runtime.SCHEMA_VERSION)
end)

test("recorded TM state rejects sparse and invalid serialized move entries",function()
  local s=store();local r=Runtime.new(s)
  r:setReusableState("blank_tm",{recordings={[1]="TACKLE",[3]="GROWL"}})
  local save={inventory={[BlankTM.RECORDED_ITEM_ID]=1}}
  check(not BlankTM.isConsistent(save,r))
  r:setReusableState("blank_tm",{recordings={[1]=false}})
  check(not BlankTM.isConsistent(save,r))
end)
