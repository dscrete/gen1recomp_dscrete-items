local MoveRecorder=dofile("lib/move_recorder.lua")
local FossilCatalyst=dofile("lib/fossil_catalyst.lua")

local function moveData()
  return {
    moves={
      TACKLE={name="TACKLE",pp=35}, GROWL={name="GROWL",pp=40},
      THUNDERSHOCK={name="THUNDERSHOCK",pp=30}, SWIFT={name="SWIFT",pp=20},
      BODY_SLAM={name="BODY SLAM",pp=15}, ANCIENT={name="ANCIENT",pp=10},
    },
    pokemon={
      PIKACHU={name="PIKACHU",level1Moves={"THUNDERSHOCK","GROWL"},learnset={{level=26,move="SWIFT"}},
        evolutions={{method="ITEM",item="THUNDER_STONE",species="RAICHU"}}},
      RAICHU={name="RAICHU",level1Moves={"THUNDERSHOCK"},learnset={{level=35,move="BODY_SLAM"}},evolutions={}},
      FOOMON={name="FOOMON",level1Moves={"TACKLE"},learnset={{level=12,move="ANCIENT"}},
        evolutions={{method="TRADE",species="BARMON"}}},
      BARMON={name="BARMON",level1Moves={"TACKLE"},learnset={},evolutions={}},
    },
  }
end

test("Move Recorder follows merged ancestry across non-level evolutions",function()
  local data=moveData()
  local line=MoveRecorder.lineageSpecies(data,"RAICHU")
  eq(#line,2)
  eq(line[1],"PIKACHU")
  eq(line[2],"RAICHU")
  local modLine=MoveRecorder.lineageSpecies(data,"BARMON")
  eq(modLine[1],"FOOMON")
  eq(modLine[2],"BARMON")
end)

test("Move Recorder offers missed natural moves at or below current level",function()
  local data=moveData()
  local mon={species="RAICHU",level=30,moves={{id="THUNDERSHOCK",pp=30}}}
  local rows=MoveRecorder.missedMoves(data,mon)
  local ids={}
  for _,row in ipairs(rows) do ids[row.id]=row end
  check(ids.GROWL,"pre-evolution starting move should be recallable")
  check(ids.SWIFT,"missed pre-evolution level move should be recallable after evolving early")
  check(not ids.THUNDERSHOCK,"known moves must be hidden")
  check(not ids.BODY_SLAM,"moves above current level must be hidden")
end)

test("Move Recorder selector exposes only party Pokemon with something to recall",function()
  local data=moveData()
  local game={data=data,save={party={
    {species="RAICHU",level=30,moves={{id="THUNDERSHOCK"}}},
    {species="BARMON",level=20,moves={{id="TACKLE"},{id="ANCIENT"}}},
  }}}
  local rows=MoveRecorder.eligibleParty(game)
  eq(#rows,1)
  eq(rows[1].slot,1)
  check(#rows[1].moves>=2)
end)

local function badgeSave(count)
  local save={inventory={},flags={EVENT_GAVE_FOSSIL_TO_LAB=true},labFossilMon="ANCIENT_A"}
  for i=1,count do save.inventory[FossilCatalyst.BADGES[i]]=1 end
  return save
end

test("Fossil Catalyst uses 35 40 45 50 across Trainer Beacon badge bands",function()
  local expected={{0,35,1},{1,35,1},{2,40,2},{3,40,2},{4,45,3},{5,45,3},{6,50,4},{8,50,4}}
  for _,row in ipairs(expected) do
    local save=badgeSave(row[1])
    local level,tier=FossilCatalyst.targetLevel(save)
    eq(level,row[2],"target at "..row[1].." badges")
    eq(tier,row[3],"tier at "..row[1].." badges")
  end
end)

test("Fossil Catalyst recursively follows only ordinary level evolutions",function()
  local data={pokemon={
    ANCIENT_A={evolutions={{method="LEVEL",level=36,species="ANCIENT_B"}}},
    ANCIENT_B={evolutions={{method="LEVEL",level=48,species="ANCIENT_C"}}},
    ANCIENT_C={evolutions={}},
    STONE_A={evolutions={{method="ITEM",item="MOON_STONE",species="STONE_B"}}},
    STONE_B={evolutions={}},
  }}
  eq(FossilCatalyst.evolveForLevel(data,"ANCIENT_A",35),"ANCIENT_A")
  eq(FossilCatalyst.evolveForLevel(data,"ANCIENT_A",40),"ANCIENT_B")
  eq(FossilCatalyst.evolveForLevel(data,"ANCIENT_A",50),"ANCIENT_C")
  eq(FossilCatalyst.evolveForLevel(data,"STONE_A",50),"STONE_A")
end)

local function fossilData()
  return {pokemon={
    ANCIENT_A={name="ANCIENT A",evolutions={{method="LEVEL",level=36,species="ANCIENT_B"}}},
    ANCIENT_B={name="ANCIENT B",evolutions={{method="LEVEL",level=48,species="ANCIENT_C"}}},
    ANCIENT_C={name="ANCIENT C",evolutions={}},
  }}
end

local function fossilCtx(count)
  local save=badgeSave(count or 0)
  return {
    save=save,
    game={data=fossilData()},
    overworld={map={id=FossilCatalyst.FOSSIL_MAP}},
  }
end

test("Fossil Catalyst plan is tied to the real pending lab fossil and never lowers a modded level",function()
  local ctx=fossilCtx(6)
  local plan=FossilCatalyst.plan(ctx,{"ANCIENT_A",30,false,true})
  eq(plan.level,50)
  eq(plan.species,"ANCIENT_C")
  local high=FossilCatalyst.plan(ctx,{"ANCIENT_A",60,false,true})
  eq(high.level,60)
  eq(high.species,"ANCIENT_C")
  ctx.overworld.map.id="CINNABAR_ISLAND"
  eq(FossilCatalyst.plan(ctx,{"ANCIENT_A",30,false,true}),nil,"wrong map must not qualify")
  ctx.overworld.map.id=FossilCatalyst.FOSSIL_MAP
  ctx.save.labFossilMon="SOMETHING_ELSE"
  eq(FossilCatalyst.plan(ctx,{"ANCIENT_A",30,false,true}),nil,"unrelated gifts must not qualify")
end)

local function fakeCatalystMod()
  local hook,effect
  local mod={}
  mod.content={
    commands={get=function(_,id)
      if id~="take_item" then return nil end
      return function(ctx,itemId,count)
        local inv=ctx.save.inventory
        inv[itemId]=math.max(0,(inv[itemId] or 0)-(count or 1))
        if inv[itemId]==0 then inv[itemId]=nil end
      end
    end},
    item_effects={register=function(_,_,def) effect=def end},
  }
  mod.hooks={wrap=function(_,name,fn) eq(name,"script.command"); hook=fn end}
  mod.ui={TextBox={new=function(_,text,_,opts) return {text=text,opts=opts} end}}
  return mod,function() return hook,effect end
end

local function runCatalystHook(giftSucceeds)
  local mod,get=fakeCatalystMod()
  FossilCatalyst.install(mod)
  local hook,effect=get()
  check(effect and effect.field and not effect.battle,"Catalyst bag fallback should be field-only")

  local ctx=fossilCtx(6)
  ctx.save.inventory[FossilCatalyst.ITEM_ID]=1
  local pushed={}
  ctx.game.stack={push=function(_,state) pushed[#pushed+1]=state end}
  local forwarded
  local co
  local runner={}
  function runner:yield() coroutine.yield() end
  function runner:resume()
    local ok,err=coroutine.resume(co)
    if not ok then error(err,0) end
  end
  ctx.runner=runner
  local function nextFn(nextCtx,name,args)
    eq(name,"give_pokemon")
    forwarded=args
    nextCtx.lastCheck=giftSucceeds
    return "done"
  end
  co=coroutine.create(function()
    hook(nextFn,ctx,"give_pokemon",{"ANCIENT_A",30,false,true})
  end)
  local ok,err=coroutine.resume(co)
  if not ok then error(err,0) end
  eq(coroutine.status(co),"suspended","Catalyst should wait for explicit choice")
  check(pushed[1] and pushed[1].opts and pushed[1].opts.choice,"Catalyst choice box missing")
  pushed[1].opts.choice(true)
  eq(coroutine.status(co),"dead")
  return ctx,forwarded
end

test("Fossil Catalyst rewrites the actual gift and consumes only after successful storage",function()
  local ctx,args=runCatalystHook(true)
  eq(args[1],"ANCIENT_C")
  eq(args[2],50)
  eq(ctx.save.inventory[FossilCatalyst.ITEM_ID],nil,"successful revival should spend one Catalyst")

  local refused,refusedArgs=runCatalystHook(false)
  eq(refusedArgs[1],"ANCIENT_C")
  eq(refusedArgs[2],50)
  eq(refused.save.inventory[FossilCatalyst.ITEM_ID],1,"party+box refusal must keep Catalyst")
end)

test("Pokemon tools stay data-driven rather than hard-coding vanilla species",function()
  local f=assert(io.open("lib/move_recorder.lua","r")); local recorder=f:read("*a"); f:close()
  local g=assert(io.open("lib/fossil_catalyst.lua","r")); local catalyst=g:read("*a"); g:close()
  for _,name in ipairs({"PIKACHU","RAICHU","OMANYTE","OMASTAR","KABUTO","KABUTOPS","AERODACTYL"}) do
    check(not recorder:find(name,1,true),"Move Recorder should not hardcode "..name)
    check(not catalyst:find(name,1,true),"Fossil Catalyst should not hardcode "..name)
  end
  check(recorder:find('return "learn"',1,true),"Move Recorder must delegate to native learn flow")
  check(catalyst:find('"script.command"',1,true),"Catalyst must integrate with the real fossil gift command")
end)
