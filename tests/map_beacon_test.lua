local MapBeacon=dofile("lib/map_beacon.lua")
local TravelSafety=dofile("lib/travel_safety.lua")

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

local function block(tile)
  local row={}
  for i=1,16 do row[i]=tile end
  return row
end

local function baseData()
  return {
    maps={
      ROUTE_1={id="ROUTE_1",label="ROUTE 1",tileset="OVERWORLD",
        width=1,height=1,blocks={0},warps={},objects={}},
      VIRIDIAN_FOREST={id="VIRIDIAN_FOREST",label="VIRIDIAN FOREST",
        tileset="FOREST",width=1,height=1,blocks={0},warps={},objects={}},
      SS_ANNE_1F={id="SS_ANNE_1F",label="S.S. ANNE",tileset="SHIP",
        width=1,height=1,blocks={0},warps={},objects={}},
      LORELEIS_ROOM={id="LORELEIS_ROOM",label="LORELEI",tileset="FACILITY",
        width=1,height=1,blocks={0},warps={},objects={}},
    },
    tilesets={
      OVERWORLD={blocks={block(1)},walkable={1},doorTiles={2},warpTiles={3}},
      FOREST={blocks={block(1)},walkable={1},doorTiles={2},warpTiles={3}},
      SHIP={blocks={block(1)},walkable={1},doorTiles={2},warpTiles={3}},
      FACILITY={blocks={block(1)},walkable={1},doorTiles={2},warpTiles={3}},
    },
    field={hiddenItems={}},
  }
end

test("Map Beacon destination validation accepts stable walkable cells",function()
  local data=baseData()
  local game={data=data,save={}}
  local world={
    current=function() return {mapId="ROUTE_1",x=0,y=0,facing="right"} end,
    mapOverview=function() return {
      mapId="ROUTE_1",markers={},rows={"..",".."},width=2,height=2,
    } end,
    overworld=function() return {npcAtCell=function() return nil end} end,
  }
  local ok,reason=TravelSafety.validateBeaconCell(game,world,"ROUTE_1",0,0)
  check(ok,reason)
  eq(TravelSafety.mapName(data,"ROUTE_1"),"ROUTE 1")
end)

test("Map Beacon rejects unsafe story maps and map markers",function()
  local data=baseData()
  local game={data=data,save={}}
  local world={
    current=function() return {mapId="ROUTE_1",x=0,y=0} end,
    mapOverview=function() return {
      mapId="ROUTE_1",markers={{kind="warp",x=0,y=0}},
    } end,
    overworld=function() return {npcAtCell=function() return nil end} end,
  }
  check(not TravelSafety.validateBeaconCell(game,world,"ROUTE_1",0,0))
  check(TravelSafety.isStoryBlocked("SS_ANNE_1F"))
  check(TravelSafety.isStoryBlocked("LORELEIS_ROOM"))
  check(not TravelSafety.isStoryBlocked("VIRIDIAN_FOREST"))
  local ok,reason=TravelSafety.validateBeaconCell(
    game,world,"SS_ANNE_1F",0,0)
  check(not ok); eq(reason,"story")
end)

test("Map Beacon rejects changed collision visible objects and live NPC occupancy",function()
  local data=baseData()
  data.maps.VIRIDIAN_FOREST.objects={
    {index=1,name="BLOCKER",x=0,y=0,sprite="SPRITE_BUG_CATCHER"},
  }
  local game={data=data,save={defeatedTrainers={}}}
  local world={
    current=function() return {mapId="ROUTE_1",x=1,y=1} end,
    mapOverview=function() return {mapId="ROUTE_1",markers={}} end,
    overworld=function() return {npcAtCell=function() return nil end} end,
  }
  local ok,reason=TravelSafety.validateBeaconCell(
    game,world,"VIRIDIAN_FOREST",0,0)
  check(not ok); eq(reason,"object tile")

  data.maps.VIRIDIAN_FOREST.objects={}
  data.tilesets.FOREST.blocks[1][5]=9
  ok,reason=TravelSafety.validateBeaconCell(
    game,world,"VIRIDIAN_FOREST",0,0)
  check(not ok); eq(reason,"not walkable")

  data.tilesets.FOREST.blocks[1][5]=1
  world.current=function() return {mapId="VIRIDIAN_FOREST",x=1,y=1} end
  world.mapOverview=function() return {
    mapId="VIRIDIAN_FOREST",markers={},
  } end
  world.overworld=function()
    return {npcAtCell=function(_,x,y)
      if x==0 and y==0 then return {id="walker"} end
    end}
  end
  ok,reason=TravelSafety.validateBeaconCell(
    game,world,"VIRIDIAN_FOREST",0,0)
  check(not ok); eq(reason,"occupied")
end)

test("Map Beacon persistent point is exact immutable data until explicitly replaced",function()
  local runtime=runtimeStore()
  check(MapBeacon.set(runtime,{
    mapId="ROUTE_1",x=1,y=0,facing="left",
  }))
  local p=MapBeacon.get(runtime)
  eq(p.mapId,"ROUTE_1"); eq(p.x,1); eq(p.y,0); eq(p.facing,"left")
  p.x=99
  eq(MapBeacon.get(runtime).x,1,"getter must return a copy")
  check(MapBeacon.set(runtime,{
    mapId="VIRIDIAN_FOREST",x=0,y=1,facing="up",
  }))
  eq(MapBeacon.get(runtime).mapId,"VIRIDIAN_FOREST")
end)

local function fakeMod(warpResult)
  local hooks,effect={},nil
  local pushed={}
  local current={mapId="ROUTE_1",x=0,y=0,facing="right"}
  local world={busy=nil,warps={},npc=nil}
  function world:current()
    return {mapId=current.mapId,x=current.x,y=current.y,facing=current.facing}
  end
  function world:availableFieldActions() return {},self.busy end
  function world:mapOverview()
    return {mapId=current.mapId,markers={},rows={"..",".."},width=2,height=2}
  end
  function world:overworld()
    local owner=self
    return {npcAtCell=function(_,x,y)
      if owner.npc and owner.npc.x==x and owner.npc.y==y then return owner.npc end
    end}
  end
  function world:warpTo(mapId,x,y,facing,opts)
    self.warps[#self.warps+1]={
      mapId=mapId,x=x,y=y,facing=facing,opts=opts,
    }
    return warpResult
  end

  local function makeMenu(_,items,opts)
    return {
      items=items,opts=opts,closed=false,
      close=function(self) self.closed=true end,
    }
  end
  local function makeText(_,text,onDone,opts)
    return {text=text,onDone=onDone,opts=opts}
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
        eq(id,MapBeacon.ITEM_EFFECT_ID); effect=def
      end},
    },
    hooks={wrap=function(_,name,fn) hooks[name]=fn end},
    ui={
      Menu={new=makeMenu},
      TextBox={new=makeText},
    },
  }
  local game={
    data=baseData(),
    save={
      inventory={[MapBeacon.ITEM_ID]=3},
      money=555,
      party={{hp=12,status="PSN"}},
      flags={KEEP=true},
    },
    stack={push=function(_,state) pushed[#pushed+1]=state end},
  }
  return mod,game,hooks,pushed,current,world,function() return effect end
end

local function confirmTop(pushed)
  local text=pushed[#pushed]
  check(type(text.onDone)=="function","expected confirmation text")
  text.onDone()
  local menu=pushed[#pushed]
  check(menu.items and menu.items[1],"expected confirmation menu")
  menu.items[1].onSelect()
end

test("Map Beacon first SET consumes on committed record and preserves field state",function()
  local mod,game,hooks,pushed,current,world,getEffect=fakeMod(true)
  local runtime=runtimeStore()
  MapBeacon.install(mod,runtime,TravelSafety)
  check(getEffect().field and not getEffect().battle)

  local list={closed=false,start=false}
  function list:close() self.closed=true end
  list.closeStartMenu=function() list.start=true end

  hooks["item.use"](function() error("Beacon should intercept") end,
    game,nil,MapBeacon.ITEM_ID,nil,list)
  check(pushed[#pushed].text:find("Set Beacon",1,true)~=nil)
  confirmTop(pushed)
  check(list.closed and list.start)
  eq(game.save.inventory[MapBeacon.ITEM_ID],3,
    "confirmation alone must not spend")
  hooks["input.step"](function() return "tick" end,game,0)

  local stored=MapBeacon.get(runtime)
  eq(stored.mapId,"ROUTE_1"); eq(stored.x,0); eq(stored.y,0)
  eq(stored.facing,"right")
  eq(game.save.inventory[MapBeacon.ITEM_ID],2)
  eq(game.save.party[1].hp,12); eq(game.save.party[1].status,"PSN")
  eq(game.save.money,555); check(game.save.flags.KEEP)
  eq(#world.warps,0)
end)

test("Map Beacon RETURN consumes after accepted warp and keeps anchor",function()
  local mod,game,hooks,pushed,current,world=fakeMod(true)
  local runtime=runtimeStore()
  MapBeacon.set(runtime,{mapId="VIRIDIAN_FOREST",x=1,y=1,facing="up"})
  MapBeacon.install(mod,runtime,TravelSafety)
  local list={close=function() end,closeStartMenu=function() end}

  hooks["item.use"](function() end,game,nil,MapBeacon.ITEM_ID,nil,list)
  local actions=pushed[#pushed]
  eq(actions.items[1].label,"RETURN")
  eq(actions.items[2].label,"RELOCATE")
  actions.items[1].onSelect()
  check(pushed[#pushed].text:find("VIRIDIAN FOREST",1,true)~=nil)
  confirmTop(pushed)
  eq(game.save.inventory[MapBeacon.ITEM_ID],3)
  hooks["input.step"](function() end,game,0)

  eq(#world.warps,1)
  eq(world.warps[1].mapId,"VIRIDIAN_FOREST")
  eq(world.warps[1].x,1); eq(world.warps[1].y,1)
  eq(world.warps[1].facing,"up")
  eq(world.warps[1].opts.arrive,"teleport")
  eq(game.save.inventory[MapBeacon.ITEM_ID],2)
  eq(MapBeacon.get(runtime).mapId,"VIRIDIAN_FOREST",
    "return must keep the saved anchor")
end)

test("Map Beacon failed return keeps item and anchor",function()
  local mod,game,hooks,pushed,current,world=fakeMod(false)
  local runtime=runtimeStore()
  MapBeacon.set(runtime,{mapId="VIRIDIAN_FOREST",x=1,y=1,facing="down"})
  MapBeacon.install(mod,runtime,TravelSafety)
  local list={close=function() end,closeStartMenu=function() end}

  hooks["item.use"](function() end,game,nil,MapBeacon.ITEM_ID,nil,list)
  pushed[#pushed].items[1].onSelect()
  confirmTop(pushed)
  hooks["input.step"](function() end,game,0)
  eq(#world.warps,1)
  eq(game.save.inventory[MapBeacon.ITEM_ID],3)
  eq(MapBeacon.get(runtime).mapId,"VIRIDIAN_FOREST")
end)

test("Map Beacon RELOCATE explicitly replaces one point and costs one Beacon",function()
  local mod,game,hooks,pushed,current=fakeMod(true)
  local runtime=runtimeStore()
  MapBeacon.set(runtime,{mapId="VIRIDIAN_FOREST",x=1,y=1,facing="down"})
  MapBeacon.install(mod,runtime,TravelSafety)
  local list={close=function() end,closeStartMenu=function() end}

  hooks["item.use"](function() end,game,nil,MapBeacon.ITEM_ID,nil,list)
  pushed[#pushed].items[2].onSelect()
  check(pushed[#pushed].text:find("Replace",1,true)~=nil)
  check(pushed[#pushed].text:find("VIRIDIAN FOREST",1,true)~=nil)
  confirmTop(pushed)
  hooks["input.step"](function() end,game,0)
  eq(MapBeacon.get(runtime).mapId,"ROUTE_1")
  eq(game.save.inventory[MapBeacon.ITEM_ID],2)
end)
