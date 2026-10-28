local PCTransfer=dofile("lib/pc_transfer.lua")
local TravelSafety=dofile("lib/travel_safety.lua")

local function fakeMod(openResult)
  local hooks,effect={},nil
  local current={mapId="ROUTE_1",x=7,y=9,facing="left"}
  local world={busy=nil,currentValue=current}
  function world:current() return self.currentValue end
  function world:availableFieldActions() return {},self.busy end

  local textBoxes={}
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
        eq(id,PCTransfer.ITEM_EFFECT_ID); effect=def
      end},
    },
    hooks={wrap=function(_,name,fn) hooks[name]=fn end},
    ui={TextBox={new=function(_,text,onDone)
      local box={text=text,onDone=onDone}
      textBoxes[#textBoxes+1]=box
      return box
    end}},
  }
  local opens=0
  local opener=function(game)
    opens=opens+1
    return openResult
  end
  return mod,hooks,function() return effect end,textBoxes,
    function() return opens end,current,opener
end

local function game()
  return {
    save={
      inventory={[PCTransfer.ITEM_ID]=1},
      money=4321,
      party={{species="PIKACHU",hp=17,status="PSN"}},
      flags={KEEP_ME=true},
    },
    stack={
      pushed={},
      push=function(self,state) self.pushed[#self.pushed+1]=state end,
    },
  }
end

test("PC Transfer registers field-only effect and closes bag flow",function()
  local mod,hooks,getEffect,boxes,opens,current,opener=fakeMod(true)
  PCTransfer.install(mod,TravelSafety,{openStorage=opener})
  local effect=getEffect()
  check(effect.field and not effect.battle)
  local g=game()
  local list={closed=false,startClosed=false}
  function list:close() self.closed=true end
  list.closeStartMenu=function() list.startClosed=true end

  hooks["item.use"](
    function() error("PC Transfer should intercept field use") end,
    g,nil,PCTransfer.ITEM_ID,nil,list)
  check(list.closed and list.startClosed)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1,
    "closing the bag must not consume the unit")
  eq(#boxes,0,"connecting text waits until the field is ready")

  hooks["input.step"](function() return "tick" end,g,0)
  eq(#boxes,1)
  check(boxes[1].text:find("Connecting",1,true)~=nil)
  eq(opens(),0)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1,
    "connecting text must not consume before storage opens")

  boxes[1].onDone()
  eq(opens(),1)
  eq(g.save.inventory[PCTransfer.ITEM_ID],nil,
    "successful storage open consumes exactly one unit")
  eq(current.mapId,"ROUTE_1")
  eq(current.x,7); eq(current.y,9); eq(current.facing,"left")
  eq(g.save.party[1].hp,17); eq(g.save.party[1].status,"PSN")
  eq(g.save.money,4321)
  check(g.save.flags.KEEP_ME)
end)

test("PC Transfer keeps item when native storage fails to open",function()
  local mod,hooks,_,boxes,opens,_,opener=fakeMod(false)
  PCTransfer.install(mod,TravelSafety,{openStorage=opener})
  local g=game()
  local list={close=function() end,closeStartMenu=function() end}
  hooks["item.use"](function() end,g,nil,PCTransfer.ITEM_ID,nil,list)
  hooks["input.step"](function() end,g,0)
  eq(#boxes,1)
  boxes[1].onDone()
  eq(opens(),1)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1)
  eq(#boxes,2,"failure explains that storage could not connect")
end)

test("PC Transfer refuses Safari link and persistent busy states",function()
  local mod,hooks,_,boxes,opens,_,opener=fakeMod(true)
  PCTransfer.install(mod,TravelSafety,{openStorage=opener})
  local g=game()
  local list={close=function() end,closeStartMenu=function() end}

  g.save.safari={steps=100}
  mod.world.currentValue={mapId="SAFARI_ZONE_CENTER"}
  hooks["item.use"](
    function() error("Safari use must not dispatch") end,
    g,nil,PCTransfer.ITEM_ID,nil,list)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1)
  eq(opens(),0)
  check(#boxes>=1)

  g.save.safari=nil
  mod.world.currentValue={mapId="TRADE_CENTER"}
  hooks["item.use"](function() error("link use must not dispatch") end,
    g,nil,PCTransfer.ITEM_ID,nil,list)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1)
  eq(opens(),0)

  mod.world.currentValue={mapId="ROUTE_1"}
  mod.world.busy="world is busy"
  hooks["item.use"](function() end,g,nil,PCTransfer.ITEM_ID,nil,list)
  hooks["input.step"](function() end,g,0)
  hooks["input.step"](function() end,g,0)
  hooks["input.step"](function() end,g,0)
  eq(g.save.inventory[PCTransfer.ITEM_ID],1)
  eq(opens(),0)
end)

test("PC Transfer uses native Pokemon storage rather than the broad PC root",function()
  local f=assert(io.open("lib/pc_transfer.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find('require, "src.ui.BoxMenu"',1,true)~=nil,
    "PC Transfer must open Gen1Recomp's native Bill's storage menu")
  check(not src:find("PlayerPC",1,true),
    "PC Transfer must not expose item storage")
  check(not src:find("openPC(",1,true),
    "PC Transfer must not open the broad PC root")
  check(not src:find("warpTo",1,true),
    "portable storage should not warp away and back")
end)
