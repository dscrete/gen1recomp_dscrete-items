local TreasureDetector = {}

TreasureDetector.KEY = "treasure_detector"
TreasureDetector.ENABLED_KEY = TreasureDetector.KEY
TreasureDetector.VOLUME_OPTION = "treasure_detector_volume"
TreasureDetector.SOUND_FALLBACK = "Switch"

local BANDS = {
  { max=0, name="DIRECTLY HERE", rank=5 },
  { max=1, name="VERY STRONG", rank=4 },
  { max=3, name="STRONG", rank=3 },
  { max=6, name="SIGNAL", rank=2 },
  { max=10, name="FAINT", rank=1 },
}

-- Metal-detector cadence: farther signals are sparse, while proximity makes
-- both the pitch/rhythm and the repeat interval progressively more urgent.
local PATTERNS = {
  [1]={ tones={390}, spacing=0.08, repeatDelay=3.20 },
  [2]={ tones={500}, spacing=0.08, repeatDelay=2.00 },
  [3]={ tones={620,760}, spacing=0.12, repeatDelay=1.05 },
  [4]={ tones={820,940}, spacing=0.09, repeatDelay=0.50 },
  [5]={ tones={1050,1320}, spacing=0.07, repeatDelay=0.22 },
}

-- Detector-specific gain sits on top of the game's SFX volume. QUIET is close
-- to the old detector level; louder presets deliberately let this navigation
-- cue cut through music while master SFX volume still scales it down to zero.
local VOLUME_MULTIPLIERS = {
  quiet=1.00,
  normal=1.50,
  loud=2.25,
  max=3.25,
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
  if not p then return {tones={},spacing=0.30,repeatDelay=math.huge} end
  local tones={}; for i,v in ipairs(p.tones) do tones[i]=v end
  return { tones=tones, spacing=p.spacing, repeatDelay=p.repeatDelay }
end

function TreasureDetector.resolveVolumeMultiplier(value)
  return VOLUME_MULTIPLIERS[tostring(value or "")] or VOLUME_MULTIPLIERS.loud
end

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

local toneCache={}

local function sfxVolume(game,multiplier)
  local options=game and game.save and game.save.options
  local v=tonumber(options and options.sfxVol)
  if v==nil then v=7 end
  v=math.max(0,math.min(7,v))
  local base=0.42*(v/7)
  return math.max(0,math.min(1,base*(tonumber(multiplier) or 1)))
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
    local sample=(phase<0.5 and 1 or -1)*0.50*envelope
    data:setSample(i,1,sample)
    data:setSample(i,2,sample)
  end

  local made,src=pcall(love.audio.newSource,data,"static")
  if not made or not src then return nil end
  toneCache[hz]=src
  return src
end

function TreasureDetector.install(mod,runtime,_fx)
  local activeRank=0
  local pendingTones,pendingIndex,pendingSpacing={},1,0.30
  local nextToneAt,nextPatternAt=0,0
  local lastSoundStatus="NEVER"
  local lastTriggerBand="NONE"

  local function enabled()
    return runtime:getReusableState(TreasureDetector.ENABLED_KEY,true)~=false
  end
  local function setEnabled(v)
    runtime:setReusableState(TreasureDetector.ENABLED_KEY,v and true or false)
  end
  local function configuredVolumeMultiplier()
    return TreasureDetector.resolveVolumeMultiplier(mod.options:get(TreasureDetector.VOLUME_OPTION))
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
    local volume=sfxVolume(game,configuredVolumeMultiplier())
    local src=buildTone(hz)
    if src then
      pcall(src.stop,src)
      pcall(src.setVolume,src,volume)
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
        if type(fallback.setVolume)=="function" then
          pcall(fallback.setVolume,fallback,volume)
        end
        lastSoundStatus=TreasureDetector.SOUND_FALLBACK
        return true
      end
    end

    lastSoundStatus="UNAVAILABLE"
    return false
  end

  local function clearSchedule()
    pendingTones={}
    pendingIndex=1
    nextToneAt=0
    nextPatternAt=0
  end

  local function queuePattern(band,t)
    local p=TreasureDetector.patternForRank(band.rank)
    pendingTones=p.tones
    pendingIndex=1
    pendingSpacing=p.spacing
    nextToneAt=t or now()
    nextPatternAt=0
    lastTriggerBand=band.name
  end

  local function fieldAvailable()
    if not (mod.world and type(mod.world.availableFieldActions)=="function") then return true end
    local ok,_,busy=pcall(mod.world.availableFieldActions,mod.world)
    return ok and busy==nil
  end

  local function serviceBeeps(game)
    if not runtime:isUnlocked(TreasureDetector.KEY) or not enabled() or not fieldAvailable() then
      activeRank=0
      clearSchedule()
      return
    end

    -- Re-read every frame, not only on movement. This stops the detector as
    -- soon as a hidden item is collected and lets it keep pulsing while idle.
    local band=reading()
    local t=now()
    if band.rank<=0 then
      activeRank=0
      clearSchedule()
      return
    end

    if band.rank~=activeRank then
      activeRank=band.rank
      queuePattern(band,t)
    elseif pendingIndex>#pendingTones and (nextPatternAt==0 or t>=nextPatternAt) then
      queuePattern(band,t)
    end

    if pendingIndex>#pendingTones or t<nextToneAt then return end
    local hz=pendingTones[pendingIndex]
    if not playOne(game,hz) then
      clearSchedule()
      activeRank=0
      return
    end

    pendingIndex=pendingIndex+1
    if pendingIndex<=#pendingTones then
      nextToneAt=t+pendingSpacing
    else
      local p=TreasureDetector.patternForRank(activeRank)
      nextPatternAt=t+p.repeatDelay
    end
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
          activeRank=0
          clearSchedule()
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
