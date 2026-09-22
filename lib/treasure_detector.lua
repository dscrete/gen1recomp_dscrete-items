local TreasureDetector = {}

TreasureDetector.KEY = "treasure_detector"
TreasureDetector.ENABLED_KEY = TreasureDetector.KEY
TreasureDetector.SOUND_FALLBACK = "Switch"

local BANDS = {
  { max=0, name="DIRECTLY HERE", rank=5 },
  { max=1, name="VERY STRONG", rank=4 },
  { max=3, name="STRONG", rank=3 },
  { max=6, name="SIGNAL", rank=2 },
  { max=10, name="FAINT", rank=1 },
}

-- Distinct electronic signatures instead of reusing a common overworld SFX.
-- Frequency rises with proximity and the rhythm becomes denser. Rank 5 uses
-- an alternating high pair so standing directly on the item is unmistakable.
local PATTERNS = {
  [1]={ tones={390}, spacing=0.30 },
  [2]={ tones={500,500}, spacing=0.25 },
  [3]={ tones={620,760}, spacing=0.17 },
  [4]={ tones={780,930,780}, spacing=0.12 },
  [5]={ tones={1050,1320,1050,1320}, spacing=0.09 },
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

function TreasureDetector.patternForRank(rank)
  rank=math.floor(tonumber(rank) or 0)
  local p=PATTERNS[rank]
  if not p then return {tones={},spacing=0.30} end
  local tones={}; for i,v in ipairs(p.tones) do tones[i]=v end
  return { tones=tones, spacing=p.spacing }
end

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

local toneCache={}

local function sfxVolume(game)
  local options=game and game.save and game.save.options
  local v=tonumber(options and options.sfxVol)
  if v==nil then return 0.42 end
  v=math.max(0,math.min(7,v))
  return 0.42*(v/7)
end

local function buildTone(hz)
  if not (love and love.sound and love.sound.newSoundData
      and love.audio and love.audio.newSource) then return nil end
  hz=math.floor(tonumber(hz) or 500)
  local cached=toneCache[hz]
  if cached then return cached end

  local sampleRate=22050
  local duration=0.065
  local frames=math.max(1,math.floor(sampleRate*duration))
  local ok,data=pcall(love.sound.newSoundData,frames,sampleRate,16,2)
  if not ok or not data then return nil end

  for i=0,frames-1 do
    local t=i/sampleRate
    local phase=(t*hz)%1
    local attack=math.min(1,i/math.max(1,math.floor(sampleRate*0.004)))
    local release=math.min(1,(frames-i)/math.max(1,math.floor(sampleRate*0.018)))
    local envelope=math.min(attack,release)
    local sample=(phase<0.5 and 1 or -1)*0.32*envelope
    data:setSample(i,1,sample)
    data:setSample(i,2,sample)
  end

  local made,src=pcall(love.audio.newSource,data,"static")
  if not made or not src then return nil end
  toneCache[hz]=src
  return src
end

function TreasureDetector.install(mod,runtime,_fx)
  local lastMap,lastX,lastY,lastRank=nil,nil,nil,0
  local pendingTones,pendingIndex,pendingSpacing,nextBeepAt={},1,0.30,0
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

  local function playOne(game,hz)
    local src=buildTone(hz)
    if src then
      pcall(src.stop,src)
      pcall(src.setVolume,src,sfxVolume(game))
      local ok=pcall(src.play,src)
      if ok then
        lastSoundStatus=("TONE %dHZ"):format(hz)
        return true
      end
    end

    local ok,Sound=pcall(require,"src.core.Sound")
    if ok and Sound and game and game.data and type(Sound.play)=="function" then
      local played,fallback=pcall(Sound.play,game.data,TreasureDetector.SOUND_FALLBACK)
      if played and fallback then
        if type(fallback.setPitch)=="function" then
          pcall(fallback.setPitch,fallback,math.max(0.65,math.min(1.8,hz/620)))
        end
        lastSoundStatus=TreasureDetector.SOUND_FALLBACK
        return true
      end
    end

    lastSoundStatus="UNAVAILABLE"
    return false
  end

  local function queuePattern(band)
    local p=TreasureDetector.patternForRank(band.rank)
    pendingTones=p.tones
    pendingIndex=1
    pendingSpacing=p.spacing
    nextBeepAt=0
    lastTriggerBand=band.name
  end

  local function serviceBeeps(game)
    if pendingIndex>#pendingTones then return end
    local t=now()
    if t<nextBeepAt then return end
    local hz=pendingTones[pendingIndex]
    if not playOne(game,hz) then
      pendingIndex=#pendingTones+1
      return
    end
    pendingIndex=pendingIndex+1
    nextBeepAt=t+pendingSpacing
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
    if band.rank>lastRank and band.rank>0 then queuePattern(band) end
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
