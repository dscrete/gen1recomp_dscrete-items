local BlankTM=dofile("lib/blank_tm.lua")
local TravelSafety=dofile("lib/travel_safety.lua")
local EmergencyTeleporter=dofile("lib/emergency_teleporter.lua")

local function runtimeStore()
  local values={}
  return {
    getReusableState=function(_,k,d)
      local v=values[k]; if v==nil then return d end; return v
    end,
    setReusableState=function(_,k,v) values[k]=v end,
    values=values,
  }
end

local function tmData()
  return {
    constants={hmMoves={"CUT"}},
    moves={
      TACKLE={name="TACKLE",pp=35}, CUT={name="CUT",pp=30},
      MOD_PULSE={name="MOD PULSE",pp=15}, NATURAL={name="NATURAL",pp=20},
      MACHINE={name="MACHINE",pp=10},
    },
    items={HM_CUT={machine={kind="HM",move="CUT"}}},
    pokemon={
      SOURCE={name="SOURCE",level1Moves={},learnset={},tmhm={}},
      MACHINE_MON={name="MACHINE MON",level1Moves={},learnset={},tmhm={"MACHINE"}},
      START_MON={name="START MON",level1Moves={"NATURAL"},learnset={},tmhm={}},
      LEVEL_MON={name="LEVEL MON",level1Moves={},learnset={{level=80,move="NATURAL"}},tmhm={}},
      MODMON={name="MODMON",level1Moves={"MOD_PULSE"},learnset={},tmhm={}},
      NOPE={name="NOPE",level1Moves={},learnset={},tmhm={}},
    },
  }
end

test("Blank TM records only currently-known non-HM moves",function()
  local data=tmData()
  local mon={species="SOURCE",moves={{id="TACKLE"},{id="CUT"},{id="MOD_PULSE"}}}
  local rows=BlankTM.recordableMoves(data,mon)
  eq(#rows,2)
  eq(rows[1].id,"TACKLE")
  eq(rows[2].id,"MOD_PULSE")
  check(BlankTM.isHM(data,"CUT"))
  check(not BlankTM.isHM(data,"TACKLE"))
end)

test("Recorded TM compatibility uses merged machine or natural learn data",function()
  local data=tmData()
  check(BlankTM.canLearn(data,{species="MACHINE_MON",moves={}},"MACHINE"))
  check(BlankTM.canLearn(data,{species="START_MON",moves={}},"NATURAL"))
  check(BlankTM.canLearn(data,{species="LEVEL_MON",moves={}},"NATURAL"))
  check(BlankTM.canLearn(data,{species="MODMON",moves={}},"MOD_PULSE"))
  check(not BlankTM.canLearn(data,{species="NOPE",moves={}},"NATURAL"))
  check(not BlankTM.canLearn(
    data,{species="START_MON",moves={{id="NATURAL"}}},"NATURAL"))
end)

test("Blank TM conversion is transactional and copies the source move",function()
  local data=tmData()
  local runtime=runtimeStore()
  local save={inventory={[BlankTM.ITEM_ID]=1},bagOrder={BlankTM.ITEM_ID}}
  local source={species="SOURCE",moves={{id="TACKLE"}}}
  local fakeBag={}
  function fakeBag.remove(s,id,n)
    s.inventory[id]=(s.inventory[id] or 0)-(n or 1)
    if s.inventory[id]<=0 then s.inventory[id]=nil end
  end
  function fakeBag.add(s,id,n)
    s.inventory[id]=(s.inventory[id] or 0)+(n or 1)
    return true
  end
  check(BlankTM.convert(save,data,"TACKLE",runtime,fakeBag))
  eq(save.inventory[BlankTM.ITEM_ID],nil)
  eq(save.inventory[BlankTM.RECORDED_ITEM_ID],1)
  eq(source.moves[1].id,"TACKLE","recording must copy rather than forget")
  local rec=BlankTM.recordings(runtime)
  eq(#rec,1); eq(rec[1],"TACKLE")

  local failedSave={inventory={[BlankTM.ITEM_ID]=1}}
  local failedRuntime=runtimeStore()
  local failBag={
    remove=fakeBag.remove,
    add=function(s,id,n)
      if id==BlankTM.RECORDED_ITEM_ID then return false end
      s.inventory[id]=(s.inventory[id] or 0)+(n or 1)
      return true
    end,
  }
  check(not BlankTM.convert(
    failedSave,data,"TACKLE",failedRuntime,failBag))
  eq(failedSave.inventory[BlankTM.ITEM_ID],1)
  eq(failedSave.inventory[BlankTM.RECORDED_ITEM_ID],nil)
  eq(#BlankTM.recordings(failedRuntime),0)
end)

test("Recorded TM copies stay distinct and are never overwritten",function()
  local runtime=runtimeStore()
  runtime:setReusableState(
    BlankTM.STATE_KEY,{recordings={"TACKLE","MOD_PULSE"}})
  local rows=BlankTM.recordings(runtime)
  eq(#rows,2); eq(rows[1],"TACKLE"); eq(rows[2],"MOD_PULSE")
  check(BlankTM.removeRecording(runtime,1,"TACKLE"))
  local after=BlankTM.recordings(runtime)
  eq(#after,1); eq(after[1],"MOD_PULSE")
  local f=assert(io.open("lib/blank_tm.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find('return "learn", pick.moveId',1,true),
    "Recorded TM must delegate to native learn flow")
  check(not src:find("OVERWRITE",1,true),
    "Recorded TM must not expose an overwrite action")
end)

test("Emergency Teleporter derives the exterior canonical Center landing",function()
  local data={
    maps={PALLET_TOWN={},PALLET_POKECENTER={},CERULEAN_CITY={}},
    field={flyWarps={
      PALLET_TOWN={x=5,y=7},CERULEAN_CITY={x=12,y=20},
    }},
  }
  local save={lastHeal={
    map="PALLET_POKECENTER",x=3,y=4,
    outdoor={id="PALLET_TOWN",x=4,y=6},
  }}
  local dest=EmergencyTeleporter.destination(data,save)
  eq(dest.map,"PALLET_TOWN"); eq(dest.x,5); eq(dest.y,7)
  eq(dest.facing,"down")
  local fallback=EmergencyTeleporter.destination(
    {maps={PALLET_TOWN={}},field={flyWarps={}}},save)
  eq(fallback.x,4); eq(fallback.y,6)
  eq(EmergencyTeleporter.destination(data,{}),nil)
  eq(EmergencyTeleporter.destination(
    data,{lastHeal={map="UNKNOWN",x=1,y=1}}),nil)
end)

test("Travel safety rejects Safari link rooms and public busy state",function()
  check(TravelSafety.isSafari("SAFARI_ZONE_CENTER",{}))
  check(TravelSafety.isSafari("ROUTE_1",{safari={steps=100}}))
  check(TravelSafety.isLinkRoom("TRADE_CENTER"))
  check(TravelSafety.isLinkRoom("BATTLE_COLOSSEUM"))
  check(not TravelSafety.isLinkRoom("ROUTE_1"))
  local ok,reason=TravelSafety.fieldReady({
    availableFieldActions=function() return {},"world is busy" end,
  })
  check(not ok); eq(reason,"world is busy")
  check(TravelSafety.fieldReady({
    availableFieldActions=function() return {} end,
  }))
end)

local function fakeTeleporterMod(warpResult)
  local hooks,effect={},nil
  local world={mapId="ROUTE_1",busy=nil,warps={}}
  function world:current() return {mapId=self.mapId} end
  function world:availableFieldActions() return {},self.busy end
  function world:warpTo(map,x,y,facing,opts)
    self.warps[#self.warps+1]={
      map=map,x=x,y=y,facing=facing,opts=opts,
    }
    return warpResult
  end
  local mod={
    world=world,
    content={
      commands={get=function(_,id)
        eq(id,"take_item")
        return function(ctx,itemId,count)
          local inv=ctx.save.inventory
          inv[itemId]=(inv[itemId] or 0)-(count or 1)
          if inv[itemId]<=0 then inv[itemId]=nil end
        end
      end},
      item_effects={register=function(_,id,def)
        eq(id,EmergencyTeleporter.ITEM_EFFECT_ID); effect=def
      end},
    },
    hooks={wrap=function(_,name,fn) hooks[name]=fn end},
    ui={TextBox={new=function(_,text) return {text=text} end}},
  }
  return mod,hooks,function() return effect end
end

local function teleporterGame()
  return {
    data={
      maps={PALLET_TOWN={},ROUTE_1={}},
      field={flyWarps={PALLET_TOWN={x=5,y=7}}},
    },
    save={
      inventory={[EmergencyTeleporter.ITEM_ID]=1},
      money=1234,
      lastHeal={
        map="PALLET_POKECENTER",x=3,y=4,
        outdoor={id="PALLET_TOWN",x=4,y=6},
      },
      party={{hp=7,status="PSN"}},
    },
    stack={push=function() end},
  }
end

test("Emergency Teleporter spends only after accepted warp and preserves state",function()
  local mod,hooks,getEffect=fakeTeleporterMod(true)
  EmergencyTeleporter.install(mod,TravelSafety)
  local effect=getEffect()
  check(effect.field and not effect.battle)
  local game=teleporterGame()
  local list={closed=false,startClosed=false}
  function list:close() self.closed=true end
  list.closeStartMenu=function() list.startClosed=true end
  hooks["item.use"](
    function() error("teleporter should intercept field use") end,
    game,nil,EmergencyTeleporter.ITEM_ID,nil,list)
  check(list.closed and list.startClosed)
  eq(game.save.inventory[EmergencyTeleporter.ITEM_ID],1)
  hooks["input.step"](function() return "tick" end,game,0)
  eq(#mod.world.warps,1)
  eq(mod.world.warps[1].map,"PALLET_TOWN")
  eq(mod.world.warps[1].opts.arrive,"teleport")
  eq(game.save.inventory[EmergencyTeleporter.ITEM_ID],nil)
  eq(game.save.party[1].hp,7)
  eq(game.save.party[1].status,"PSN")
  eq(game.save.money,1234)
end)

test("Emergency Teleporter keeps the item on invalid or failed travel",function()
  local mod,hooks=fakeTeleporterMod(false)
  EmergencyTeleporter.install(mod,TravelSafety)
  local game=teleporterGame()
  local list={close=function() end,closeStartMenu=function() end}
  hooks["item.use"](function() end,game,nil,
    EmergencyTeleporter.ITEM_ID,nil,list)
  hooks["input.step"](function() end,game,0)
  eq(game.save.inventory[EmergencyTeleporter.ITEM_ID],1)

  local mod2,hooks2=fakeTeleporterMod(true)
  EmergencyTeleporter.install(mod2,TravelSafety)
  local safari=teleporterGame()
  safari.save.safari={steps=100}
  mod2.world.mapId="SAFARI_ZONE_CENTER"
  hooks2["item.use"](
    function() error("Safari use must not dispatch") end,
    safari,nil,EmergencyTeleporter.ITEM_ID,nil,list)
  eq(safari.save.inventory[EmergencyTeleporter.ITEM_ID],1)
  eq(#mod2.world.warps,0)
end)

test("Travel and TM tools avoid hard-coded content and healing side effects",function()
  local f=assert(io.open("lib/emergency_teleporter.lua","r"))
  local t=f:read("*a"); f:close()
  check(not t:find("Pokemon.heal",1,true))
  check(not t:find("money =",1,true))
  check(not t:find("PALLET_TOWN",1,true))
  local b=assert(io.open("lib/blank_tm.lua","r"))
  local s=b:read("*a"); b:close()
  for _,name in ipairs({"PIKACHU","MEW","MEWTWO","CHARIZARD"}) do
    check(not s:find(name,1,true),"Blank TM should not hardcode "..name)
  end
end)
