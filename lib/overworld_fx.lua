-- Lightweight overworld-only visual effects for DScrete gadgets/items.
-- The anomaly overlay is inserted into the overworld's WORLD pass, before
-- Renderer:endWorldPass().  That matters: drawing after screen.draw() lands on
-- the UI canvas, which makes an ostensibly world-anchored mark slide at any
-- survey zoom other than the one accidental scale where both canvases agree.

local OverworldFx = {}

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

-- Gen 1 walk cells are 16x16 world pixels.  While drawWorld() is active the
-- world canvas is also expressed in world pixels, with the live camera as its
-- top-left, so this is the same transform the terrain renderer uses.
local CELL_PX = 16

function OverworldFx.worldCellToScreen(ow, cellX, cellY)
  local cam = ow and ow.camera
  if not cam then return nil,nil end
  return (tonumber(cellX) or 0) * CELL_PX - math.floor(cam.x or 0),
         (tonumber(cellY) or 0) * CELL_PX - math.floor(cam.y or 0)
end

function OverworldFx.install(mod)
  local state = { anomalyProvider = nil }

  -- Retained as a compatibility no-op for older dev builds.  Treasure Detector
  -- passive feedback is audio-only after live zoom testing.
  function OverworldFx.flashMessage(_text,_seconds) end

  function OverworldFx.setAnomalyProvider(fn)
    state.anomalyProvider = type(fn) == "function" and fn or nil
  end

  local function drawAnomalyMark(sx,sy,phase)
    -- Centre one 8x8 corruption fragment inside the 16x16 encounter cell.
    -- The tiny tell is permanent and the larger pattern pulses from wall-clock
    -- time, so a stationary player can still discover it.
    local x,y=math.floor(sx+4),math.floor(sy+4)

    love.graphics.setColor(1,1,1,0.55)
    love.graphics.rectangle("fill",x+1,y+1,2,1)
    love.graphics.rectangle("fill",x+5,y+6,2,1)

    -- Roughly 0.45 seconds of visible corruption every 1.35 seconds.  A phase
    -- offset keeps the three cells from flashing in lockstep.
    if ((now()+phase) % 1.35) < 0.45 then
      love.graphics.setColor(1,1,1,0.95)
      love.graphics.rectangle("fill",x,y+1,7,1)
      love.graphics.rectangle("fill",x+2,y+4,6,1)
      love.graphics.rectangle("fill",x+1,y+7,4,1)
      love.graphics.setColor(0,0,0,0.95)
      love.graphics.rectangle("fill",x+1,y+2,5,1)
      love.graphics.rectangle("fill",x+4,y+5,4,1)
    end
  end

  local function drawAnomalies(ow)
    local provider=state.anomalyProvider
    if not provider or not ow or not ow.camera then return end
    local tiles=provider()
    if type(tiles)~="table" or #tiles==0 then return end

    -- Do not leak color/scissor/shader state into sprites or later world FX.
    love.graphics.push("all")
    for i,tile in ipairs(tiles) do
      local sx,sy=OverworldFx.worldCellToScreen(ow,tile.x,tile.y)
      -- No 160x144 bounds here: survey zoom deliberately makes the world
      -- canvas larger than the classic UI canvas.  LOVE clips to the current
      -- world canvas naturally.
      if sx and sy then drawAnomalyMark(sx,sy,i*0.29) end
    end
    love.graphics.pop()
  end

  mod.hooks:wrap("screen.render_visible",function(next,screen)
    local visible=next(screen)
    if visible~=false and screen and screen.isOverworld and not screen._dscreteWorldFxWrapped then
      -- OverworldState:draw() is:
      --   beginWorldPass -> drawWorld -> endWorldPass -> drawUI
      -- so wrapping drawWorld is the stable place for world-space decoration.
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
