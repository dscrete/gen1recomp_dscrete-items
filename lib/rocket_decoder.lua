-- Rocket Decoder: persistent, extensible authored incident framework.
-- Incidents themselves live in rocket_incidents.lua; this module owns the one
-- global active incident, scheduling, Decoder UI, runtime actors and lightweight
-- operative memory.

local RocketDecoder={}

RocketDecoder.KEY="rocket_decoder"
RocketDecoder.STATE_VERSION=1
RocketDecoder.DEFAULT_EXPIRY=2500
RocketDecoder.INITIAL_COOLDOWN=128
RocketDecoder.REPEAT_COOLDOWN=512
RocketDecoder.FORCE_AFTER_READY=256
RocketDecoder.ROLL_DENOMINATOR=64

local STATE_KEY=RocketDecoder.KEY
local INTERACT_COMMAND="dscrete_items:rocket_interact"
local ARCHIVE_MAX=6

local function esc(v)
  return tostring(v or ""):gsub("%%","%%25"):gsub("|","%%7C"):gsub("=","%%3D")
end
local function unesc(v)
  return tostring(v or ""):gsub("%%3D","="):gsub("%%7C","|"):gsub("%%25","%%")
end

function RocketDecoder.encodeState(state)
  local keys={}
  for k,v in pairs(state or {}) do
    if v~=nil and type(v)~="table" then keys[#keys+1]=k end
  end
  table.sort(keys)
  local out={}
  for _,k in ipairs(keys) do out[#out+1]=esc(k).."="..esc(state[k]) end
  return table.concat(out,"|")
end

function RocketDecoder.decodeState(raw)
  local out={}
  if type(raw)~="string" or raw=="" then return out end
  for part in raw:gmatch("[^|]+") do
    local k,v=part:match("^([^=]+)=(.*)$")
    if k then out[unesc(k)]=unesc(v) end
  end
  return out
end

local function n(v,default)
  local value=tonumber(v)
  if value==nil then return default or 0 end
  return value
end

local function truth(v) return v=="1" or v==1 or v==true or v=="true" end

local function contains(list,value)
  for _,candidate in ipairs(list or {}) do if candidate==value then return true end end
  return false
end

function RocketDecoder.findOpenCell(overview,x,y,occupied)
  if type(overview)~="table" or type(overview.rows)~="table" then return x,y end
  occupied=occupied or {}
  local function open(cx,cy)
    if cx<0 or cy<0 or cy>=(overview.height or #overview.rows) then return false end
    local row=overview.rows[cy+1]
    if type(row)~="string" or cx>=#row then return false end
    if row:sub(cx+1,cx+1)~="." then return false end
    return not occupied[cy*1000+cx]
  end
  for radius=0,5 do
    for dy=-radius,radius do
      for dx=-radius,radius do
        if math.abs(dx)+math.abs(dy)==radius and open(x+dx,y+dy) then
          return x+dx,y+dy
        end
      end
    end
  end
  return nil,nil
end

-- Gen1Recomp's save.visited is the fly-town bitset, not a record of every route
-- and dungeon the player has entered. Incident locations therefore declare
-- progression towns explicitly. Current-map membership is also accepted because
-- being physically inside the region is stronger evidence than any progression bit.
function RocketDecoder.locationEligible(loc,progress)
  if type(loc)~="table" then return false end
  progress=progress or {}
  local visited=progress.visited or progress
  local inventory=progress.inventory or {}
  local currentMap=progress.currentMap
  if currentMap and contains(loc.regionMaps,currentMap) then return true end

  local unlockVisited=loc.unlockVisited or {}
  if #unlockVisited>0 then
    local reached=false
    for _,mapId in ipairs(unlockVisited) do
      if visited and visited[mapId] then reached=true break end
    end
    if not reached then return false end
  end
  for _,itemId in ipairs(loc.requiredItems or {}) do
    local value=inventory and inventory[itemId]
    if value==nil or value==false or value==0 then return false end
  end
  return true
end

function RocketDecoder.eligibleIncidents(Incidents,progress,state)
  local fresh,repeatable={},{}
  for _,id in ipairs(Incidents.ORDER or {}) do
    local def=Incidents.ALL[id]
    local location
    for i,loc in ipairs(def and def.locations or {}) do
      if RocketDecoder.locationEligible(loc,progress) then location=i break end
    end
    if def and location then
      local row={id=id,location=location}
      if n(state and state["done_"..id],0)==0 then fresh[#fresh+1]=row
      elseif not state or state.last_id~=id then repeatable[#repeatable+1]=row end
    end
  end
  return (#fresh>0) and fresh or repeatable
end

function RocketDecoder.install(mod,runtime,Items,Incidents)
  local showTextValue=mod.content.commands:get("show_text")
  local giveItemValue=mod.content.commands:get("give_item")
  local startBattleValue=mod.content.commands:get("start_battle")
  local showText=type(showTextValue)=="table" and showTextValue.fn or showTextValue
  local giveItem=type(giveItemValue)=="table" and giveItemValue.fn or giveItemValue
  local startBattle=type(startBattleValue)=="table" and startBattleValue.fn or startBattleValue
  assert(type(showText)=="function" and type(giveItem)=="function" and type(startBattle)=="function",
    "Rocket Decoder requires public script commands")

  local state={}
  local UNREAD={}
  local lastRaw=UNREAD
  local actorIds={}
  local pendingNotice=nil
  local currentGame=nil

  local function loadState()
    local raw=runtime:getReusableState(STATE_KEY,nil)
    if raw==lastRaw then return end
    state=RocketDecoder.decodeState(raw)
    if n(state.version,0)~=RocketDecoder.STATE_VERSION then
      state={version=tostring(RocketDecoder.STATE_VERSION),cooldown=tostring(RocketDecoder.INITIAL_COOLDOWN)}
    end
    lastRaw=raw
  end

  local function persist()
    state.version=tostring(RocketDecoder.STATE_VERSION)
    local raw=RocketDecoder.encodeState(state)
    runtime:setReusableState(STATE_KEY,raw)
    lastRaw=raw
  end

  local function incident()
    loadState()
    return state.active and Incidents.ALL[state.active] or nil
  end

  local function location(def)
    return def and def.locations and def.locations[n(state.location,1)] or nil
  end

  local function clearActors()
    for _,id in ipairs(actorIds) do
      if id~=nil then pcall(mod.world.removeNpc,mod.world,id) end
    end
    actorIds={}
  end

  local function activePhase() return state.phase or "active" end

  local function spawnActors()
    clearActors()
    if not runtime:isUnlocked(RocketDecoder.KEY) then return end
    local def=incident()
    local loc=location(def)
    local pos=mod.world:current()
    if not def or not loc or not pos or pos.mapId~=loc.mapId then return end
    local overview=mod.world:mapOverview()
    local occupied={}
    occupied[(pos.y or 0)*1000+(pos.x or 0)]=true
    local phase=activePhase()
    for i,actor in ipairs(def.actors or {}) do
      if not actor.phases or actor.phases[phase] then
        local desiredX=(loc.anchor and loc.anchor.x or pos.x or 0)+(actor.dx or 0)
        local desiredY=(loc.anchor and loc.anchor.y or pos.y or 0)+(actor.dy or 0)
        local x,y=RocketDecoder.findOpenCell(overview,desiredX,desiredY,occupied)
        if x and y then
          occupied[y*1000+x]=true
          local spawned=mod.world:spawnNpc(loc.mapId,{
            index=230+i,
            name=actor.name,
            sprite=actor.sprite or "SPRITE_ROCKET",
            movement="STAY",
            range="NONE",
            text=actor.text,
            x=x,y=y,
          })
          local id=type(spawned)=="table" and (spawned.id or spawned.npcId) or spawned
          if id~=nil then actorIds[#actorIds+1]=id end
        end
      end
    end
  end

  local function archive(def,outcome,summary)
    for i=ARCHIVE_MAX,2,-1 do
      state["archive_"..i.."_id"]=state["archive_"..(i-1).."_id"]
      state["archive_"..i.."_outcome"]=state["archive_"..(i-1).."_outcome"]
      state["archive_"..i.."_location"]=state["archive_"..(i-1).."_location"]
      state["archive_"..i.."_summary"]=state["archive_"..(i-1).."_summary"]
    end
    state.archive_1_id=def.id
    state.archive_1_outcome=outcome
    local loc=location(def)
    state.archive_1_location=loc and loc.mapId or ""
    state.archive_1_summary=summary or ""
  end

  local function opKey(id,suffix) return "op_"..id.."_"..suffix end
  local function memory(id)
    loadState()
    local flags={}
    local prefix="op_"..id.."_flag_"
    for k,v in pairs(state) do
      if k:sub(1,#prefix)==prefix and truth(v) then flags[k:sub(#prefix+1)]=true end
    end
    return {
      met=n(state[opKey(id,"met")],0),
      player_wins=n(state[opKey(id,"player_wins")],0),
      rocket_wins=n(state[opKey(id,"rocket_wins")],0),
      alternate=n(state[opKey(id,"alternate")],0),
      last_outcome=state[opKey(id,"last_outcome")],
      flags=flags,
    }
  end

  local function finish(outcome,summary)
    local def=incident()
    if not def then return end
    local op=def.operative
    if truth(state.active_met) and op then
      state[opKey(op,"last_outcome")]=outcome
      if outcome=="RESOLVED_WIN" then
        state[opKey(op,"player_wins")]=tostring(n(state[opKey(op,"player_wins")],0)+1)
      elseif outcome=="ROCKET_SUCCESS" then
        state[opKey(op,"rocket_wins")]=tostring(n(state[opKey(op,"rocket_wins")],0)+1)
      elseif outcome=="RESOLVED_ALTERNATE" then
        state[opKey(op,"alternate")]=tostring(n(state[opKey(op,"alternate")],0)+1)
      end
    end
    archive(def,outcome,summary)
    state["done_"..def.id]=tostring(n(state["done_"..def.id],0)+1)
    state.last_id=def.id
    state.active=nil
    state.location=nil
    state.stage=nil
    state.phase=nil
    state.remaining=nil
    state.cargo=nil
    state.active_met=nil
    for k in pairs(state) do
      if k:match("^incident_flag_") then state[k]=nil end
    end
    state.cooldown=tostring(RocketDecoder.REPEAT_COOLDOWN)
    state.ready="0"
    persist()
    clearActors()
  end

  local function setPhase(value)
    state.phase=value
    persist()
    spawnActors()
  end

  local function setStage(stage)
    stage=math.max(n(state.stage,1),tonumber(stage) or 1)
    if stage~=n(state.stage,1) then
      state.stage=tostring(stage)
      persist()
      pendingNotice="ROCKET SIGNAL UPDATED."
    end
  end

  local function rollCargo(def)
    local pool={}
    for _,key in ipairs(def.prototypePool or {}) do
      local item=Items.byKey[key]
      if item and item.implemented and item.itemId then pool[#pool+1]=key end
    end
    if #pool==0 then return nil end
    return pool[love.math.random(1,#pool)]
  end

  local function startIncident(id,locIndex)
    local def=Incidents.ALL[id]
    local loc=def and def.locations and def.locations[locIndex]
    if not def or not loc then return false end
    state.active=id
    state.location=tostring(locIndex)
    state.stage="1"
    state.phase="active"
    state.remaining=tostring(def.expiry or RocketDecoder.DEFAULT_EXPIRY)
    state.cargo=rollCargo(def)
    state.active_met=nil
    for k in pairs(state) do if k:match("^incident_flag_") then state[k]=nil end end
    state.ready="0"
    persist()
    pendingNotice="ROCKET SIGNAL DETECTED."
    local pos=mod.world:current()
    if pos and contains(loc.regionMaps,pos.mapId) then setStage(2) end
    if pos and pos.mapId==loc.mapId then setStage(3); spawnActors() end
    return true
  end

  local function progressFor(game)
    local save=game and game.save or {}
    local current=mod.world:current()
    return {
      visited=save.visited or {},
      inventory=save.inventory or {},
      currentMap=current and current.mapId or nil,
    }
  end

  local function chooseIncident(game,forcedId)
    if forcedId then
      local def=Incidents.ALL[forcedId]
      if not def then return false end
      local idx=1
      local current=mod.world:current()
      for i,loc in ipairs(def.locations or {}) do
        if current and contains(loc.regionMaps,current.mapId) then idx=i break end
      end
      return startIncident(forcedId,idx)
    end
    local eligible=RocketDecoder.eligibleIncidents(Incidents,progressFor(game),state)
    if #eligible==0 then return false end
    local pick=eligible[love.math.random(1,#eligible)]
    return startIncident(pick.id,pick.location)
  end

  local function advanceForMap(mapId)
    if not runtime:isUnlocked(RocketDecoder.KEY) then clearActors(); return end
    local def=incident()
    local loc=location(def)
    if not def or not loc then return end
    if n(state.stage,1)<2 and contains(loc.regionMaps,mapId) then setStage(2) end
    if mapId==loc.mapId then
      if n(state.stage,1)<3 then setStage(3) end
      spawnActors()
    else
      clearActors()
    end
  end

  local function choose(ctx,title,rows)
    local picked,done=nil,false
    local menu
    local runner=ctx.runner
    local function finishChoice(value)
      if done then return end
      done=true; picked=value
      if menu then menu:close() end
      runner:resume()
    end
    menu=mod.ui.ListMenu.new(ctx.game,title,rows,{
      pageJump=true,
      onChoose=function(row) finishChoice(row and row.value) end,
      onCancel=function() finishChoice(nil) end,
    })
    ctx.game.stack:push(menu)
    runner:yield()
    return picked
  end

  local function makeEnv(ctx,def,role)
    local env={}
    function env:say(text) return showText(ctx,text) end
    function env:choose(title,rows) return choose(ctx,title,rows) end
    function env:memory(id) return memory(id) end
    function env:meet(id)
      if not truth(state.active_met) then
        state.active_met="1"
        state[opKey(id,"met")]=tostring(n(state[opKey(id,"met")],0)+1)
        persist()
      end
    end
    function env:setOperativeFlag(id,flag,value)
      state[opKey(id,"flag_"..flag)]=value and "1" or nil
      persist()
    end
    function env:setIncidentFlag(flag,value)
      state["incident_flag_"..flag]=value and "1" or nil
      persist()
    end
    function env:incidentFlag(flag) return truth(state["incident_flag_"..flag]) end
    function env:trainerBattle(party)
      startBattle(ctx,"trainer","OPP_ROCKET",party or 5)
      return ctx.lastBattleResult or (ctx.lastCheck and "win" or "loss")
    end
    function env:wildBattle(species,level)
      startBattle(ctx,"wild",species,level)
      return ctx.lastBattleResult or (ctx.lastCheck and "win" or "loss")
    end
    function env:giveCargo(cash)
      local item=state.cargo and Items.byKey[state.cargo]
      if not (item and item.itemId) then
        self:say("The Rocket equipment is\nempty.")
        return true
      end
      local result=giveItem(ctx,item.itemId,1)
      if result==math.huge then return false end
      cash=tonumber(cash) or 0
      if cash>0 then
        local cap=(ctx.game.data.constants or {}).moneyCap or 999999
        ctx.save.money=math.min(cap,(tonumber(ctx.save.money) or 0)+cash)
        self:say(("Recovered %d in\nRocket funds."):format(cash))
      end
      return true
    end
    function env:finish(outcome,summary) return finish(outcome,summary) end
    function env:setPhase(value) return setPhase(value) end
    function env:phase() return activePhase() end
    function env:setStage(value) return setStage(value) end
    return env
  end

  mod.content.commands:register(INTERACT_COMMAND,{
    foreground=true,
    fn=function(ctx,incidentId,role)
      loadState()
      local def=incident()
      if not def or def.id~=incidentId then
        showText(ctx,"The Rocket signal is\ngone.")
        return
      end
      local fn=def.interact and def.interact[role]
      if fn then fn(makeEnv(ctx,def,role)) end
    end,
  })

  -- One public map-script contribution per authored incident location. Runtime
  -- NPCs point at these text keys; the content functions remain in the
  -- incident catalogue instead of accumulating bespoke engine hooks.
  local scriptsByMap={}
  for _,id in ipairs(Incidents.ORDER or {}) do
    local def=Incidents.ALL[id]
    for _,loc in ipairs(def.locations or {}) do
      local talk=scriptsByMap[loc.mapId] or {}
      scriptsByMap[loc.mapId]=talk
      for _,actor in ipairs(def.actors or {}) do
        talk[actor.text]={{INTERACT_COMMAND,id,actor.role}}
      end
    end
  end
  for mapId,talk in pairs(scriptsByMap) do
    mod.content.map_scripts:register(mapId,{talk=talk})
  end

  local function activeTransmission()
    local def=incident()
    if not def then return "NO ACTIVE ROCKET\nTRANSMISSION." end
    local pages={}
    for i=1,math.min(n(state.stage,1),#(def.transmissions or {})) do
      pages[#pages+1]=def.transmissions[i]
    end
    pages[#pages+1]=("INCIDENT: %s\fTIME WINDOW: %d STEPS"):format(def.title,n(state.remaining,0))
    return table.concat(pages,"\f")
  end

  local function archiveRows()
    local rows={}
    for i=1,ARCHIVE_MAX do
      local id=state["archive_"..i.."_id"]
      local def=id and Incidents.ALL[id]
      if def then rows[#rows+1]={label=def.title,value=i} end
    end
    return rows
  end

  local function operativeRows()
    local rows={}
    for id,def in pairs(Incidents.OPERATIVES or {}) do
      if memory(id).met>0 then rows[#rows+1]={label=def.name,value=id} end
    end
    table.sort(rows,function(a,b) return a.label<b.label end)
    return rows
  end

  local function openArchive(game)
    local rows=archiveRows()
    if #rows==0 then
      game.stack:push(mod.ui.TextBox.new(game,"NO STORED\nTRANSMISSIONS."))
      return
    end
    local menu
    menu=mod.ui.ListMenu.new(game,"TRANSMISSIONS",rows,{
      onChoose=function(row)
        if not row then return end
        if menu then menu:close() end
        local i=row.value
        local id=state["archive_"..i.."_id"]
        local def=Incidents.ALL[id]
        local outcome=state["archive_"..i.."_outcome"] or "UNKNOWN"
        local place=(state["archive_"..i.."_location"] or ""):gsub("_"," ")
        local summary=state["archive_"..i.."_summary"] or ""
        game.stack:push(mod.ui.TextBox.new(game,
          ("%s\f%s\f%s\f%s"):format(def and def.title or id,place,outcome,summary)))
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  local function openOperatives(game)
    local rows=operativeRows()
    if #rows==0 then
      game.stack:push(mod.ui.TextBox.new(game,"NO OPERATIVE DATA."))
      return
    end
    local menu
    menu=mod.ui.ListMenu.new(game,"OPERATIVE DATA",rows,{
      onChoose=function(row)
        if not row then return end
        if menu then menu:close() end
        local id=row.value
        local def=Incidents.OPERATIVES[id]
        local mem=memory(id)
        game.stack:push(mod.ui.TextBox.new(game,
          ("%s\fENCOUNTERS: %d\nPLAYER WINS: %d\nROCKET WINS: %d\fALT. RESOLUTIONS: %d\f%s")
          :format(def.name,mem.met,mem.player_wins,mem.rocket_wins,mem.alternate,def.tagline)))
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  local function forceMenu(game)
    local rows={}
    for _,id in ipairs(Incidents.ORDER or {}) do
      rows[#rows+1]={label=Incidents.ALL[id].title,value=id}
    end
    local menu
    menu=mod.ui.ListMenu.new(game,"FORCE INCIDENT",rows,{
      onChoose=function(row)
        if menu then menu:close() end
        if row then
          if incident() then finish("EXPIRED","Developer replaced the active incident.") end
          chooseIncident(game,row.value)
        end
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  function RocketDecoder.open(game)
    loadState()
    local rows={
      {label=incident() and "ACTIVE SIGNAL" or "NO ACTIVE SIGNAL",value="active"},
      {label="TRANSMISSIONS",value="archive"},
      {label="OPERATIVE DATA",value="ops"},
    }
    if mod.developer then rows[#rows+1]={label="DEBUG: FORCE",value="force"} end
    rows[#rows+1]={label="CLOSE",value="close"}
    local menu
    menu=mod.ui.ListMenu.new(game,"ROCKET DECODER",rows,{
      onChoose=function(row)
        local value=row and row.value
        if value=="close" or not value then if menu then menu:close() end; return end
        if menu then menu:close() end
        if value=="active" then game.stack:push(mod.ui.TextBox.new(game,activeTransmission()))
        elseif value=="archive" then openArchive(game)
        elseif value=="ops" then openOperatives(game)
        elseif value=="force" then forceMenu(game) end
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  function RocketDecoder.status()
    loadState()
    return {
      active=state.active,stage=n(state.stage,0),phase=state.phase,
      remaining=n(state.remaining,0),cargo=state.cargo,
      cooldown=n(state.cooldown,0),ready=n(state.ready,0),
    }
  end

  function RocketDecoder.memory(id) return memory(id) end

  function RocketDecoder.forceIncident(id,game)
    loadState()
    if incident() then finish("EXPIRED","Developer replaced the active incident.") end
    return chooseIncident(game or currentGame,id)
  end

  mod.events:on("map.entered",function(ev)
    loadState()
    advanceForMap(ev and ev.mapId)
  end)

  mod.events:on("world.stepped",function()
    loadState()
    if not runtime:isUnlocked(RocketDecoder.KEY) then
      clearActors()
      return
    end
    if incident() then
      if activePhase()=="active" then
        state.remaining=tostring(math.max(0,n(state.remaining,0)-1))
        if n(state.remaining,0)<=0 then
          finish("EXPIRED","The transmission ended before the incident was resolved.")
          pendingNotice="ROCKET SIGNAL LOST."
          return
        end
        persist()
      end
      return
    end

    local cooldown=n(state.cooldown,RocketDecoder.INITIAL_COOLDOWN)
    if cooldown>0 then
      state.cooldown=tostring(cooldown-1)
      persist()
      return
    end
    local ready=n(state.ready,0)+1
    state.ready=tostring(ready)
    persist()
    if ready>=RocketDecoder.FORCE_AFTER_READY or love.math.random(1,RocketDecoder.ROLL_DENOMINATOR)==1 then
      chooseIncident(currentGame)
    end
  end)

  mod.hooks:wrap("input.step",function(next,game,dt)
    currentGame=game
    loadState()
    local result=next(game,dt)
    if pendingNotice then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then
        local text=pendingNotice
        pendingNotice=nil
        game.stack:push(mod.ui.TextBox.new(game,text))
      end
    end
    return result
  end)

  local function reload(game)
    currentGame=game or currentGame
    lastRaw=UNREAD
    loadState()
    local pos=mod.world:current()
    if pos then advanceForMap(pos.mapId) end
  end
  mod.events:on("game.ready",reload)
  mod.events:on("save.loaded",reload)
  mod.events:on("save.created",reload)

  return RocketDecoder
end

return RocketDecoder
