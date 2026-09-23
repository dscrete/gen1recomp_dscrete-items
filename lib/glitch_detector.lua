local GlitchDetector = {}

GlitchDetector.EFFECT_ID = "glitch_detector"
GlitchDetector.ITEM_EFFECT_ID = "DS_GLITCH_DETECTOR_EFFECT"
GlitchDetector.FLASH_OPTION = "glitch_detector_flash_rate"
GlitchDetector.SPOTS_OPTION = "glitch_detector_spots"
GlitchDetector.STEPS_OPTION = "glitch_detector_steps"
GlitchDetector.STATE_KEY = "glitch_detector"

local DURATIONS = { [50]=true,[100]=true,[250]=true,[500]=true,[1000]=true,[2500]=true }
local SPOT_COUNTS = { [1]=true,[2]=true,[3]=true,[5]=true }
local FLASH = {
  subtle={ period=4.0, window=0.22 },
  normal={ period=2.4, window=0.30 },
  frequent={ period=1.2, window=0.45 },
}
local LEGENDARIES = { ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true }
local DEFAULT_BUCKETS = { 51,102,127,153,178,204,229,242,253,256 }

function GlitchDetector.resolveFlash(v)
  local row=FLASH[tostring(v or "")] or FLASH.subtle
  return { period=row.period, window=row.window }
end

function GlitchDetector.resolveSpotCount(v)
  local n=tonumber(v)
  return (n and SPOT_COUNTS[n]) and n or 1
end

function GlitchDetector.resolveDuration(v)
  local n=tonumber(v); return (n and DURATIONS[n]) and n or 250
end

function GlitchDetector.encodeTiles(tiles)
  local out={}
  for _,t in ipairs(tiles or {}) do out[#out+1]=("%d,%d"):format(t.x,t.y) end
  return table.concat(out,";")
end

function GlitchDetector.decodeTiles(s)
  local out={}
  for pair in tostring(s or ""):gmatch("[^;]+") do
    local x,y=pair:match("^(-?%d+),(-?%d+)$")
    if x and y then out[#out+1]={x=tonumber(x),y=tonumber(y)} end
  end
  return out
end

function GlitchDetector.encodeState(mapId,tiles)
  if not mapId then return nil end
  return tostring(mapId).."|"..GlitchDetector.encodeTiles(tiles)
end

function GlitchDetector.decodeState(s)
  if type(s)~="string" or s=="" then return nil,{} end
  local mapId,encoded=s:match("^([^|]+)|?(.*)$")
  if not mapId or mapId=="" then return nil,{} end
  return mapId,GlitchDetector.decodeTiles(encoded)
end

local function key(x,y) return tostring(x)..","..tostring(y) end

function GlitchDetector.isAnomalyTile(tiles,x,y)
  for _,t in ipairs(tiles or {}) do if t.x==x and t.y==y then return true end end
  return false
end

-- Candidate cells are deliberately restricted by an engine-backed eligibility
-- predicate. For Gen 1 this is map:isGrassCell(), so a visible anomaly can no
-- longer land on an ordinary path simply because that path is walkable.
function GlitchDetector.candidates(overview,originX,originY,eligible)
  local out={}
  if type(overview)~="table" or type(overview.rows)~="table" then return out end
  local blocked={}
  for _,m in ipairs(overview.markers or {}) do blocked[key(m.x,m.y)]=true end
  for y,row in ipairs(overview.rows) do
    for x=1,#row do
      local cx,cy=x-1,y-1
      local d=math.abs(cx-(originX or 0))+math.abs(cy-(originY or 0))
      if d>=2 and d<=8 and not blocked[key(cx,cy)]
          and (not eligible or eligible(cx,cy)) then
        out[#out+1]={x=cx,y=cy}
      end
    end
  end
  return out
end

function GlitchDetector.pickTiles(candidates,count,rng)
  local pool={}; for i,v in ipairs(candidates or {}) do pool[i]=v end
  local out={}; count=math.min(tonumber(count) or 1,#pool)
  rng=rng or function(n) return love.math.random(1,n) end
  for _=1,count do
    local i=rng(#pool)
    out[#out+1]=table.remove(pool,i)
  end
  return out
end

function GlitchDetector.kantoPool(pokemon)
  local out={}
  for id,def in pairs(pokemon or {}) do
    local dex=tonumber(def and (def.dex or def.dexNo or def.pokedex or def.number))
    local name=tostring(id)
    if dex and dex>=1 and dex<=151 and not LEGENDARIES[name] then out[#out+1]=id end
  end
  table.sort(out,function(a,b) return tostring(a)<tostring(b) end)
  return out
end

-- Pick one native slot while deliberately ignoring only the map's encounter
-- frequency. The anomaly forces the battle but retains an ordinary local level
-- distribution. Species is replaced afterward by the anomaly pool.
function GlitchDetector.nativeEncounter(encDef,rng)
  if type(encDef)~="table" then return nil end
  local slotDef=encDef.grass
  if not (slotDef and type(slotDef.slots)=="table" and #slotDef.slots>0) then return nil end
  rng=rng or function(a,b) return love.math.random(a,b) end
  local pick=rng(0,255)
  local thresholds=slotDef.buckets or DEFAULT_BUCKETS
  for i,threshold in ipairs(thresholds) do
    if pick<threshold then
      local slot=slotDef.slots[i]
      if slot then return { species=slot.species, level=slot.level } end
      return nil
    end
  end
  local slot=slotDef.slots[#slotDef.slots]
  return slot and { species=slot.species, level=slot.level } or nil
end

function GlitchDetector.install(mod,runtime,fx)
  local currentMap,currentTiles=GlitchDetector.decodeState(
    runtime:getReusableState(GlitchDetector.STATE_KEY,nil))

  local function persist(mapId,tiles)
    currentMap=mapId; currentTiles=tiles or {}
    runtime:setReusableState(GlitchDetector.STATE_KEY,GlitchDetector.encodeState(mapId,currentTiles))
  end

  local function encounterDef(mapId)
    local registry=mod.content and mod.content.encounters
    if not (registry and type(registry.get)=="function") then return nil end
    local ok,def=pcall(registry.get,registry,mapId)
    return ok and def or nil
  end

  local function liveGrassPredicate(mapId)
    local api=mod.world
    if not (api and type(api.overworld)=="function") then return nil end
    local ok,ow=pcall(api.overworld,api)
    local map=ok and ow and ow.map
    if not (map and map.id==mapId and type(map.isGrassCell)=="function") then return nil end
    return function(x,y)
      return map:isGrassCell(x,y)
        and (type(map.isWalkableCell)~="function" or map:isWalkableCell(x,y))
    end
  end

  local function findTiles(spotCount)
    local pos=mod.world:current()
    if not pos or not pos.mapId then return nil,"no overworld" end
    local eligible=liveGrassPredicate(pos.mapId)
    if not eligible then return nil,"grass unavailable" end
    local overview=mod.world:mapOverview()
    local candidates=GlitchDetector.candidates(overview,pos.x,pos.y,eligible)
    if #candidates==0 then return nil,"no nearby grass" end
    return GlitchDetector.pickTiles(candidates,spotCount),nil,pos.mapId
  end

  local function beginEffect(opts)
    opts=opts or {}
    local pos=mod.world:current()
    if not pos or not pos.mapId then return false,"no overworld" end
    if not GlitchDetector.nativeEncounter(encounterDef(pos.mapId),function() return 0 end) then
      return false,"no wild signal"
    end
    local duration=GlitchDetector.resolveDuration(opts.duration or mod.options:get(GlitchDetector.STEPS_OPTION))
    local spots=GlitchDetector.resolveSpotCount(opts.spots or mod.options:get(GlitchDetector.SPOTS_OPTION))

    -- Validate placement before touching the shared field-effect slot. A failed
    -- grass search must not erase some other active scent/resonator during the
    -- second-use replacement flow.
    local selected,seedWhy,mapId=findTiles(spots)
    if not selected or #selected==0 then return false,seedWhy end

    local ok,why=runtime:activateFieldEffect(GlitchDetector.EFFECT_ID,duration,opts.replace==true)
    if not ok then return false,why end
    persist(mapId,selected)
    return true,nil,duration,#currentTiles
  end

  local function ensureTiles()
    if not runtime:isActive(GlitchDetector.EFFECT_ID) then return {} end
    return currentTiles
  end

  local function triggerAnomaly(game)
    if not runtime:isActive(GlitchDetector.EFFECT_ID) then return false end
    local pos=mod.world:current()
    if not pos or pos.mapId~=currentMap
        or not GlitchDetector.isAnomalyTile(currentTiles,pos.x,pos.y) then return false end

    local native=GlitchDetector.nativeEncounter(encounterDef(pos.mapId))
    if not native or not native.level then return false end
    local pool=GlitchDetector.kantoPool(game and game.data and game.data.pokemon)
    if #pool==0 then return false end
    local species=pool[love.math.random(1,#pool)]

    local starter=mod.world and mod.world.startWildBattle
    if type(starter)~="function" then return false end
    local ok=starter(mod.world,species,native.level)
    if not ok then return false end

    -- All visible spots represent alternate entrances to ONE anomaly event.
    -- Triggering any one immediately ends the field effect and removes every
    -- remaining mark; there is no automatic reseed after the battle.
    runtime:clearFieldEffect()
    persist(nil,{})
    return true
  end

  GlitchDetector.tiles=function() return ensureTiles() end
  GlitchDetector.hasAnomalies=function(mapId)
    return runtime:isActive(GlitchDetector.EFFECT_ID) and currentMap==mapId and #currentTiles>0
  end
  -- Public/exported activation seam for future authored effects (a curse,
  -- story script, NPC incident, etc.). It invokes the same save-safe anomaly
  -- behavior without requiring the bag item itself.
  GlitchDetector.activate=function(opts) return beginEffect(opts) end

  if fx then
    fx.setAnomalyProvider(function() return ensureTiles() end)
    if fx.setAnomalyFlashProvider then
      fx.setAnomalyFlashProvider(function()
        return GlitchDetector.resolveFlash(mod.options:get(GlitchDetector.FLASH_OPTION))
      end)
    end
  end

  mod.content.item_effects:register(GlitchDetector.ITEM_EFFECT_ID,{
    needsTarget=false,field=true,battle=false,
    use=function()
      local pos=mod.world:current()
      if not pos or not pos.mapId then return "failed",{"No stable field\nsignal here."} end
      if runtime.activeFieldEffect==GlitchDetector.EFFECT_ID then
        return "failed",{"The detector is already\nreading anomalies."}
      end
      local replace=false
      if runtime.activeFieldEffect then
        replace=runtime:requestFieldReplacement(GlitchDetector.EFFECT_ID)
        if not replace then return "failed",{"Another field effect\nis already active.\fUse GLITCH DET. again\nto replace it."} end
      end
      local ok,why,d,spots=beginEffect({replace=replace})
      if not ok then
        if why=="no nearby grass" or why=="grass unavailable" then
          return "failed",{"No nearby grass can\nhold the anomaly."}
        elseif why=="no wild signal" then
          return "failed",{"No wild signal can\nstabilize here."}
        end
        return "failed",{"The detector won't\nstabilize."}
      end
      return "consumed",{("Static crawls across\nthe detector.\f%d anomaly spot%s\nfor up to %d steps.")
        :format(spots,spots==1 and "" or "s",d)},{useJingle=true}
    end,
  })

  -- The anomaly spot owns the encounter. Suppress the ordinary random roll on
  -- its exact grass cell; input.step below immediately starts the guaranteed
  -- anomaly battle instead.
  mod.hooks:wrap("encounter.roll",function(next,encDef,ctx)
    if runtime:isActive(GlitchDetector.EFFECT_ID) then
      local pos=mod.world:current()
      if pos and pos.mapId==currentMap
          and GlitchDetector.isAnomalyTile(currentTiles,pos.x,pos.y) then
        return nil
      end
    end
    return next(encDef,ctx)
  end)

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    if runtime:isActive(GlitchDetector.EFFECT_ID) and #currentTiles>0 then
      triggerAnomaly(game)
    elseif not runtime:isActive(GlitchDetector.EFFECT_ID) and (currentMap or #currentTiles>0) then
      persist(nil,{})
    end
    if runtime.pendingExpirationNotice==GlitchDetector.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then
        runtime.pendingExpirationNotice=nil
        persist(nil,{})
        game.stack:push(mod.ui.TextBox.new(game,"The interference\nfaded away."))
      end
    end
    return r
  end)

  return GlitchDetector
end

return GlitchDetector
