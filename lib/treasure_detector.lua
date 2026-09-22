local TreasureDetector = {}

TreasureDetector.KEY = "treasure_detector"
TreasureDetector.ENABLED_KEY = TreasureDetector.KEY
TreasureDetector.SOUND_PRIMARY = "Tink"
TreasureDetector.SOUND_FALLBACK = "Press_AB"

local BANDS = {
  { max=0, name="DIRECTLY HERE", rank=5 },
  { max=1, name="VERY STRONG", rank=4 },
  { max=3, name="STRONG", rank=3 },
  { max=6, name="SIGNAL", rank=2 },
  { max=10, name="FAINT", rank=1 },
}

function TreasureDetector.bandForDistance(distance)
  distance=tonumber(distance)
  if distance==nil then return {name="NO SIGNAL",rank=0} end
  for _,band in ipairs(BANDS) do if distance<=band.max then return band end end
  return {name="NO SIGNAL",rank=0}
end

function TreasureDetector.nearestHidden(overview,x,y)
  local best=nil
  for _,m in ipairs((overview and overview.markers) or {}) do
    if m.kind=="hidden" then
      local d=math.abs((tonumber(m.x) or 0)-(tonumber(x) or 0))
        +math.abs((tonumber(m.y) or 0)-(tonumber(y) or 0))
      if best==nil or d<best then best=d end
    end
  end
  return best
end

-- Audio-only strength language.  The strongest bands get a short cluster,
-- while pitch rises with rank.  Both are deliberately bounded so walking onto
-- an item never turns into a long blocking jingle.
function TreasureDetector.beepCount(rank)
  rank=tonumber(rank) or 0
  if rank>=5 then return 3 end
  if rank>=3 then return 2 end
  if rank>=1 then return 1 end
  return 0
end

function TreasureDetector.beepPitch(rank)
  rank=math.max(1,math.min(5,tonumber(rank) or 1))
  return 0.78+(rank-1)*0.14
end

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

function TreasureDetector.install(mod,runtime,_fx)
  local lastMap,lastX,lastY,lastRank=nil,nil,nil,0
  local pendingBeeps,pendingRank,nextBeepAt=0,0,0
  local lastSoundStatus="NEVER"
  local lastTriggerBand="NONE"

  local function enabled()
    return runtime:getReusableState(TreasureDetector.ENABLED_KEY,true)~=false
  end
  local function setEnabled(v)
    runtime:setReusableState(TreasureDetector.ENABLED_KEY,v and true or false)
  end

  local function distance()
    local pos=mod.world:current()
    if not pos or not pos.mapId then return nil end
    local overview=mod.world:mapOverview()
    return TreasureDetector.nearestHidden(overview,pos.x,pos.y)
  end

  local function reading()
    local d=distance()
    return TreasureDetector.bandForDistance(d),d
  end

  local function playOne(game,rank)
    local ok,Sound=pcall(require,"src.core.Sound")
    if not (ok and Sound and game and game.data and type(Sound.play)=="function") then
      lastSoundStatus="NO SOUND API"
      return false
    end

    -- The previous build asked for the Gen 2 label
    -- Sfx_SecondPartOfItemfinder.  Red/Blue/Yellow do not expose that label,
    -- so the defensive existence check correctly (but silently) skipped it.
    -- Tink is a real Gen 1 field SFX; Press_AB is the guaranteed shared fallback.
    for _,name in ipairs({TreasureDetector.SOUND_PRIMARY,TreasureDetector.SOUND_FALLBACK}) do
      local played,src=pcall(Sound.play,game.data,name)
      if played and src then
        if type(src.setPitch)=="function" then
          pcall(src.setPitch,src,TreasureDetector.beepPitch(rank))
        end
        lastSoundStatus=name
        return true
      end
    end
    lastSoundStatus="UNAVAILABLE"
    return false
  end

  local function queueBeeps(band)
    pendingRank=band.rank
    pendingBeeps=TreasureDetector.beepCount(band.rank)
    nextBeepAt=0
    lastTriggerBand=band.name
  end

  local function serviceBeeps(game)
    if pendingBeeps<=0 then return end
    local t=now()
    if t<nextBeepAt then return end
    if not playOne(game,pendingRank) then
      pendingBeeps=0
      return
    end
    pendingBeeps=pendingBeeps-1
    nextBeepAt=t+0.18
  end

  local function passiveStep(game)
    if not runtime:isUnlocked(TreasureDetector.KEY) or not enabled() then return end
    local pos=mod.world:current()
    if not pos or not pos.mapId or pos.x==nil or pos.y==nil then return end
    if pos.mapId==lastMap and pos.x==lastX and pos.y==lastY then return end
    local mapChanged=pos.mapId~=lastMap
    if mapChanged then lastRank=0 end
    lastMap,lastX,lastY=pos.mapId,pos.x,pos.y
    local band=reading()
    if band.rank>lastRank and band.rank>0 then queueBeeps(band) end
    lastRank=band.rank
  end

  local function open(game)
    local band=reading()
    local rows={
      {label="READING: "..band.name,value="noop"},
      {label=enabled() and "PASSIVE: ON" or "PASSIVE: OFF",value="toggle"},
      {label="CLOSE",value="close"},
    }
    local menu
    menu=mod.ui.ListMenu.new(game,"TREASURE DET.",rows,{
      onChoose=function(row)
        if not row then return end
        if row.value=="toggle" then
          setEnabled(not enabled())
          if menu then menu:close() end
          open(game)
        elseif row.value=="close" then if menu then menu:close() end end
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    passiveStep(game)
    serviceBeeps(game)
    return r
  end)

  TreasureDetector.open=open
  TreasureDetector.enabled=enabled
  TreasureDetector.setEnabled=setEnabled
  TreasureDetector.reading=reading
  TreasureDetector.lastSoundStatus=function() return lastSoundStatus end
  TreasureDetector.lastTriggerBand=function() return lastTriggerBand end
  return TreasureDetector
end

return TreasureDetector
