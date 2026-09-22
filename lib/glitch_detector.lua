local GlitchDetector = {}

GlitchDetector.EFFECT_ID = "glitch_detector"
GlitchDetector.ITEM_EFFECT_ID = "DS_GLITCH_DETECTOR_EFFECT"
GlitchDetector.RATE_OPTION = "glitch_detector_rate"
GlitchDetector.STEPS_OPTION = "glitch_detector_steps"
GlitchDetector.TILES_KEY = "glitch_detector_tiles"
GlitchDetector.MAP_KEY = "glitch_detector_map"

local RATES = { mild=0.20, strong=0.40, extreme=0.60 }
local DURATIONS = { [50]=true,[100]=true,[250]=true,[500]=true,[1000]=true,[2500]=true }
local LEGENDARIES = { ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true }

function GlitchDetector.resolveRate(v) return RATES[tostring(v or "")] or 0.40 end
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

local function key(x,y) return tostring(x)..","..tostring(y) end

function GlitchDetector.isAnomalyTile(tiles,x,y)
  for _,t in ipairs(tiles or {}) do if t.x==x and t.y==y then return true end end
  return false
end

function GlitchDetector.candidates(overview,originX,originY)
  local out={}
  if type(overview)~="table" or type(overview.rows)~="table" then return out end
  local blocked={}
  for _,m in ipairs(overview.markers or {}) do blocked[key(m.x,m.y)]=true end
  for y,row in ipairs(overview.rows) do
    for x=1,#row do
      local c=row:sub(x,x)
      local cx,cy=x-1,y-1
      local d=math.abs(cx-(originX or 0))+math.abs(cy-(originY or 0))
      if (c=="." or c=="~") and d>=2 and d<=10 and not blocked[key(cx,cy)] then
        out[#out+1]={x=cx,y=cy}
      end
    end
  end
  return out
end

function GlitchDetector.pickTiles(candidates,count,rng)
  local pool={}; for i,v in ipairs(candidates or {}) do pool[i]=v end
  local out={}; count=math.min(tonumber(count) or 3,#pool)
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

function GlitchDetector.install(mod,runtime,fx)
  local currentTiles={}
  local currentMap=nil

  local function persist(mapId,tiles)
    currentMap=mapId; currentTiles=tiles or {}
    runtime:setReusableState(GlitchDetector.MAP_KEY,mapId)
    runtime:setReusableState(GlitchDetector.TILES_KEY,GlitchDetector.encodeTiles(currentTiles))
  end

  local function restore()
    currentMap=runtime:getReusableState(GlitchDetector.MAP_KEY,nil)
    currentTiles=GlitchDetector.decodeTiles(runtime:getReusableState(GlitchDetector.TILES_KEY,""))
  end
  restore()

  local function ensureTiles()
    if not runtime:isActive(GlitchDetector.EFFECT_ID) then return {} end
    local pos=mod.world:current()
    if not pos or not pos.mapId then return {} end
    if currentMap==pos.mapId and #currentTiles>0 then return currentTiles end
    local overview=mod.world:mapOverview()
    local candidates=GlitchDetector.candidates(overview,pos.x,pos.y)
    persist(pos.mapId,GlitchDetector.pickTiles(candidates,3))
    return currentTiles
  end

  GlitchDetector.tiles=function() return ensureTiles() end
  GlitchDetector.hasAnomalies=function(mapId)
    return runtime:isActive(GlitchDetector.EFFECT_ID) and currentMap==mapId and #currentTiles>0
  end

  if fx then fx.setAnomalyProvider(function() return ensureTiles() end) end

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
      local d=GlitchDetector.resolveDuration(mod.options:get(GlitchDetector.STEPS_OPTION))
      local ok=runtime:activateFieldEffect(GlitchDetector.EFFECT_ID,d,replace)
      if not ok then return "failed",{"The detector won't\nstabilize."} end
      persist(nil,{})
      ensureTiles()
      return "consumed",{("Static crawls across\nthe detector.\fAnomalies active for\n%d steps."):format(d)},{useJingle=true}
    end,
  })

  mod.hooks:wrap("encounter.roll",function(next,encDef,ctx)
    local enc=next(encDef,ctx)
    if not enc or not runtime:isActive(GlitchDetector.EFFECT_ID) then return enc end
    local pos=mod.world:current()
    if not pos or pos.mapId~=currentMap or not GlitchDetector.isAnomalyTile(ensureTiles(),pos.x,pos.y) then return enc end
    if love.math.random()>=GlitchDetector.resolveRate(mod.options:get(GlitchDetector.RATE_OPTION)) then return enc end
    local game=(ctx and ctx.game) or (mod.world and mod.world.game)
    local pool=GlitchDetector.kantoPool(game and game.data and game.data.pokemon)
    if #pool>0 then enc.species=pool[love.math.random(1,#pool)] end
    return enc
  end)

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    if runtime:isActive(GlitchDetector.EFFECT_ID) then
      ensureTiles()
    elseif currentMap or #currentTiles>0 then
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
