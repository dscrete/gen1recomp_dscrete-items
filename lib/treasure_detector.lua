local TreasureDetector = {}

TreasureDetector.KEY = "treasure_detector"
TreasureDetector.ENABLED_KEY = TreasureDetector.KEY

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

function TreasureDetector.install(mod,runtime,_fx)
  local lastMap,lastX,lastY,lastRank=nil,nil,nil,0

  local function enabled()
    return runtime:getReusableState(TreasureDetector.ENABLED_KEY,true)~=false
  end
  local function setEnabled(v)
    runtime:setReusableState(TreasureDetector.ENABLED_KEY,v and true or false)
  end

  local function reading()
    local pos=mod.world:current()
    if not pos or not pos.mapId then return TreasureDetector.bandForDistance(nil) end
    local overview=mod.world:mapOverview()
    return TreasureDetector.bandForDistance(TreasureDetector.nearestHidden(overview,pos.x,pos.y))
  end

  local function safeBeep(game)
    local ok,Sound=pcall(require,"src.core.Sound")
    if ok and Sound and game and game.data then
      local audio=game.data.audio
      local name="Sfx_SecondPartOfItemfinder"
      if audio and audio.sfx and audio.sfx[Sound.resolve(game.data,name)] then
        Sound.play(game.data,name)
      end
    end
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
    if band.rank>lastRank and band.rank>0 then safeBeep(game) end
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
    return r
  end)

  TreasureDetector.open=open
  TreasureDetector.enabled=enabled
  TreasureDetector.setEnabled=setEnabled
  TreasureDetector.reading=reading
  return TreasureDetector
end

return TreasureDetector
