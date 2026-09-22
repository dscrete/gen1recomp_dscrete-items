-- Lightweight overworld-only visual effects for DScrete gadgets/items.
-- Uses the public screen.render_visible hook to decorate the live overworld's
-- draw pass without pushing a blocking UI state.

local OverworldFx = {}

local function now()
  return (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
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

  local function drawMessage()
    if not state.message or state.message == "" or now() >= state.messageUntil then return end
    local Font = require("src.render.Font")
    local width = #state.message * 8
    local x = math.floor((160 - width) / 2)
    -- Roughly above the player while the overworld camera is centered.
    Font.draw(state.message, math.max(0, x), 44)
  end

  local function drawAnomalies(ow)
    local provider = state.anomalyProvider
    if not provider or not ow or not ow.player then return end
    local tiles = provider()
    if type(tiles) ~= "table" or #tiles == 0 then return end
    local px, py = ow.player.cellX or 0, ow.player.cellY or 0
    local t = now()
    for i, tile in ipairs(tiles) do
      -- Each tile gets a different phase, so the map only glitches occasionally.
      if math.floor(t * 6 + i * 3) % 13 == 0 then
        local sx = 80 + ((tonumber(tile.x) or 0) - px) * 16
        local sy = 72 + ((tonumber(tile.y) or 0) - py) * 16
        if sx > -16 and sx < 160 and sy > -16 and sy < 144 then
          love.graphics.setColor(1, 1, 1, 0.75)
          love.graphics.rectangle("fill", sx - 8, sy - 7, 16, 2)
          love.graphics.rectangle("fill", sx - 5, sy + 1, 12, 2)
          love.graphics.setColor(0, 0, 0, 0.9)
          love.graphics.rectangle("fill", sx - 8, sy - 3, 10, 2)
          love.graphics.rectangle("fill", sx, sy + 5, 8, 2)
          love.graphics.setColor(1, 1, 1, 1)
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
          drawMessage()
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
