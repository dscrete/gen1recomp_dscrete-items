-- Lightweight overworld-only visual effects for DScrete gadgets/items.
-- Uses the public screen.render_visible hook to decorate the live overworld's
-- draw pass without pushing a blocking UI state.

local OverworldFx = {}

local function now()
  return (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
end

-- Gen 1 world cells are 16x16 pixels. The overworld camera stores its top-left
-- in those same world-pixel coordinates, so overlays transform from saved world
-- cells through the live camera rather than following player movement.
local CELL_PX = 16

function OverworldFx.worldCellToScreen(ow, cellX, cellY)
  local cam = ow and ow.camera
  if not cam then return nil,nil end
  return (tonumber(cellX) or 0) * CELL_PX - math.floor(cam.x or 0),
         (tonumber(cellY) or 0) * CELL_PX - math.floor(cam.y or 0)
end

function OverworldFx.install(mod)
  local state = { anomalyProvider = nil }

  -- Kept as a no-op compatibility surface for older callers. Passive detector
  -- feedback is audio-only now; overworld text was too zoom-dependent.
  function OverworldFx.flashMessage(_text,_seconds) end

  function OverworldFx.setAnomalyProvider(fn)
    state.anomalyProvider = type(fn) == "function" and fn or nil
  end

  local function drawAnomalyMark(sx,sy,phase)
    -- Each anomaly occupies only the upper-left 8x8 tile inside its 16x16
    -- encounter cell. A faint 2-pixel tell is always present, while the rest
    -- pulses/flickers from wall-clock time, so standing still still reveals it.
    local x,y=math.floor(sx),math.floor(sy)
    love.graphics.setScissor(math.max(0,x),math.max(0,y),
      math.max(0,math.min(8,160-math.max(0,x))),
      math.max(0,math.min(8,144-math.max(0,y))))

    love.graphics.setColor(1,1,1,0.45)
    love.graphics.rectangle("fill",x+1,y+1,2,1)
    love.graphics.rectangle("fill",x+5,y+6,2,1)

    -- About 0.35 s of stronger corruption every ~1.4 s, with per-tile phase.
    if ((now()+phase) % 1.4) < 0.35 then
      love.graphics.setColor(1,1,1,0.9)
      love.graphics.rectangle("fill",x,y+2,7,1)
      love.graphics.rectangle("fill",x+2,y+5,6,1)
      love.graphics.setColor(0,0,0,0.95)
      love.graphics.rectangle("fill",x+1,y+3,5,1)
      love.graphics.rectangle("fill",x+4,y+7,4,1)
    end

    love.graphics.setScissor()
    love.graphics.setColor(1,1,1,1)
  end

  local function drawAnomalies(ow)
    local provider=state.anomalyProvider
    if not provider or not ow or not ow.camera then return end
    local tiles=provider()
    if type(tiles)~="table" or #tiles==0 then return end
    for i,tile in ipairs(tiles) do
      local sx,sy=OverworldFx.worldCellToScreen(ow,tile.x,tile.y)
      if sx and sx>-8 and sx<160 and sy>-8 and sy<144 then
        drawAnomalyMark(sx,sy,i*0.31)
      end
    end
  end

  mod.hooks:wrap("screen.render_visible",function(next,screen)
    local visible=next(screen)
    if visible~=false and screen and screen.isOverworld and not screen._dscreteFxWrapped then
      local original=screen.draw
      if type(original)=="function" then
        screen.draw=function(self,...)
          local result=original(self,...)
          drawAnomalies(self)
          return result
        end
        screen._dscreteFxWrapped=true
      end
    end
    return visible
  end)

  return OverworldFx
end

return OverworldFx
