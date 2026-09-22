-- Lightweight overworld-only visual effects for DScrete gadgets/items.
-- Uses the public screen.render_visible hook to decorate the live overworld's
-- draw pass without pushing a blocking UI state.

local OverworldFx = {}

local function now()
  return (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
end

-- Gen 1 world cells are 16x16 pixels. The overworld camera stores its top-left
-- in those same world-pixel coordinates, so overlays must transform from world
-- pixels rather than assuming the player is always screen-centred.
local CELL_PX = 16

function OverworldFx.worldCellToScreen(ow, cellX, cellY)
  local cam = ow and ow.camera
  if not cam then return nil,nil end
  return (tonumber(cellX) or 0) * CELL_PX - math.floor(cam.x or 0),
         (tonumber(cellY) or 0) * CELL_PX - math.floor(cam.y or 0)
end

function OverworldFx.install(mod)
  local state = {
    message = nil,
    messageUntil = 0,
    anomalyProvider = nil,
  }

  function OverworldFx.flashMessage(text, seconds)
    state.message = tostring(text or "")
    state.messageUntil = now() + (tonumber(seconds) or 0.65)
  end

  function OverworldFx.setAnomalyProvider(fn)
    state.anomalyProvider = type(fn) == "function" and fn or nil
  end

  local function drawMessage(ow)
    if not state.message or state.message == "" or now() >= state.messageUntil then return end
    if not ow or not ow.player then return end
    local Font = require("src.render.Font")
    local sx,sy=OverworldFx.worldCellToScreen(ow,ow.player.cellX,ow.player.cellY)
    if not sx then return end
    local width=#state.message*8
    -- Small floating label centred above the player's 16x16 world cell.
    local x=math.floor(sx+8-width/2)
    local y=math.floor(sy-10)
    x=math.max(0,math.min(160-width,x))
    y=math.max(0,math.min(136,y))
    Font.draw(state.message,x,y)
  end

  local function drawAnomalies(ow)
    local provider = state.anomalyProvider
    if not provider or not ow or not ow.player or not ow.camera then return end
    local tiles = provider()
    if type(tiles) ~= "table" or #tiles == 0 then return end
    local t = now()
    for i, tile in ipairs(tiles) do
      -- Each anomaly is tied to one encounter cell. Draw only an 8x8 fragment
      -- inside that 16x16 cell so it reads as a local tile corruption rather
      -- than a screen-space graphic. Different phases keep the flicker sparse.
      if math.floor(t * 6 + i * 3) % 13 == 0 then
        local sx,sy=OverworldFx.worldCellToScreen(ow,tile.x,tile.y)
        if sx and sx > -16 and sx < 160 and sy > -16 and sy < 144 then
          local x,y=math.floor(sx+4),math.floor(sy+4)
          love.graphics.setScissor(math.max(0,sx),math.max(0,sy),
            math.min(16,160-math.max(0,sx)),math.min(16,144-math.max(0,sy)))
          love.graphics.setColor(1,1,1,0.8)
          love.graphics.rectangle("fill",x,y,8,2)
          love.graphics.rectangle("fill",x+2,y+4,6,1)
          love.graphics.setColor(0,0,0,0.9)
          love.graphics.rectangle("fill",x,y+2,5,2)
          love.graphics.rectangle("fill",x+3,y+6,5,2)
          love.graphics.setScissor()
          love.graphics.setColor(1,1,1,1)
        end
      end
    end
  end

  mod.hooks:wrap("screen.render_visible", function(next, screen)
    local visible = next(screen)
    if visible ~= false and screen and screen.isOverworld and not screen._dscreteFxWrapped then
      local original = screen.draw
      if type(original) == "function" then
        screen.draw = function(self, ...)
          local result = original(self, ...)
          drawAnomalies(self)
          drawMessage(self)
          return result
        end
        screen._dscreteFxWrapped = true
      end
    end
    return visible
  end)

  return OverworldFx
end

return OverworldFx
