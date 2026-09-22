-- Lightweight overworld-only visual effects for DScrete gadgets/items.
-- The anomaly overlay is inserted into the overworld's WORLD pass, before
-- Renderer:endWorldPass(), so it inherits the terrain camera/zoom transform.

local OverworldFx = {}

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

local CELL_PX = 16

function OverworldFx.worldCellToScreen(ow, cellX, cellY)
  local cam = ow and ow.camera
  if not cam then return nil,nil end
  return (tonumber(cellX) or 0) * CELL_PX - math.floor(cam.x or 0),
         (tonumber(cellY) or 0) * CELL_PX - math.floor(cam.y or 0)
end

function OverworldFx.install(mod)
  local state = { anomalyProvider = nil, flashProvider = nil }

  function OverworldFx.flashMessage(_text,_seconds) end

  function OverworldFx.setAnomalyProvider(fn)
    state.anomalyProvider = type(fn) == "function" and fn or nil
  end

  function OverworldFx.setAnomalyFlashProvider(fn)
    state.flashProvider = type(fn) == "function" and fn or nil
  end

  local function flashConfig()
    local cfg=state.flashProvider and state.flashProvider() or nil
    local period=tonumber(cfg and cfg.period) or 2.4
    local window=tonumber(cfg and cfg.window) or 0.30
    period=math.max(0.2,period)
    window=math.max(0.04,math.min(period,window))
    return period,window
  end

  local function drawAnomalyMark(sx,sy,phase)
    local period,window=flashConfig()
    if ((now()+phase) % period) >= window then return end

    -- One short-lived 8x8 corruption fragment centred inside the 16x16 walk
    -- cell. There is deliberately no permanent tell now: because stepping on
    -- the mark guarantees an encounter, the player should have to notice the
    -- occasional visual fault rather than follow an always-visible marker.
    local x,y=math.floor(sx+4),math.floor(sy+4)
    love.graphics.setColor(1,1,1,0.95)
    love.graphics.rectangle("fill",x,y+1,7,1)
    love.graphics.rectangle("fill",x+2,y+4,6,1)
    love.graphics.rectangle("fill",x+1,y+7,4,1)
    love.graphics.setColor(0,0,0,0.95)
    love.graphics.rectangle("fill",x+1,y+2,5,1)
    love.graphics.rectangle("fill",x+4,y+5,4,1)
  end

  local function drawAnomalies(ow)
    local provider=state.anomalyProvider
    if not provider or not ow or not ow.camera then return end
    local tiles=provider()
    if type(tiles)~="table" or #tiles==0 then return end

    love.graphics.push("all")
    for i,tile in ipairs(tiles) do
      local sx,sy=OverworldFx.worldCellToScreen(ow,tile.x,tile.y)
      if sx and sy then drawAnomalyMark(sx,sy,i*0.29) end
    end
    love.graphics.pop()
  end

  mod.hooks:wrap("screen.render_visible",function(next,screen)
    local visible=next(screen)
    if visible~=false and screen and screen.isOverworld and not screen._dscreteWorldFxWrapped then
      local originalWorld=screen.drawWorld
      if type(originalWorld)=="function" then
        screen.drawWorld=function(self,...)
          local result=originalWorld(self,...)
          drawAnomalies(self)
          return result
        end
        screen._dscreteWorldFxWrapped=true
      end
    end
    return visible
  end)

  return OverworldFx
end

return OverworldFx
