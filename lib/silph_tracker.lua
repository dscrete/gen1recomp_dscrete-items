-- Silph Tracker: permanent gadget that reports coarse signal bands for every
-- species currently present on the player's map. Unseen species remain UNKNOWN.

local SilphTracker = {}
SilphTracker.KEY = "silph_tracker"

local BAND_RANK = { ["NO SIGNAL"]=0, FAINT=1, WEAK=2, STRONG=3, ["VERY STRONG"]=4 }
local TRACKER_VISIBLE_ROWS = 5
local TRACKER_TOP_Y = 32
local TRACKER_ROW_STEP = 16
local TRACKER_NAME_X = 16
local TRACKER_SIGNAL_X = 64
local TRACKER_CURSOR_X = 8
local TRACKER_CLOSE_Y = 128

local function seenSpecies(game, species)
  local dex = game and game.save and game.save.pokedex
  if not dex then return false end
  return (dex.seen and dex.seen[species] == true)
    or (dex.owned and dex.owned[species] == true)
end

local function displayName(game, species)
  if not seenSpecies(game, species) then return "UNKNOWN" end
  local def = game and game.data and game.data.pokemon and game.data.pokemon[species]
  return (def and def.name) or tostring(species)
end

local function newTrackerScreen(game, rows, emptyText)
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")

  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  function Screen.new()
    return setmetatable({
      game = game,
      rows = rows,
      emptyText = emptyText or "NO LOCAL SIGNAL",
      index = (#rows > 0) and 1 or 0,
      scroll = 1,
      closeSelected = (#rows == 0),
    }, Screen)
  end

  function Screen:close()
    if self.game.stack and self.game.stack:top() == self then
      self.game.stack:pop()
    end
  end

  function Screen:ensureVisible()
    if self.index <= 0 then return end
    if self.index < self.scroll then self.scroll = self.index end
    if self.index >= self.scroll + TRACKER_VISIBLE_ROWS then
      self.scroll = self.index - TRACKER_VISIBLE_ROWS + 1
    end
    local maxScroll = math.max(1, #self.rows - TRACKER_VISIBLE_ROWS + 1)
    if self.scroll > maxScroll then self.scroll = maxScroll end
  end

  function Screen:update(_dt)
    local input = self.game and self.game.input
    if not input then return end

    if input:wasPressed("b") or input:wasPressed("start") then
      self:close()
      return
    end

    if input:wasPressed("a") then
      if self.closeSelected or #self.rows == 0 then self:close() end
      return
    end

    if #self.rows == 0 then return end

    if input:wasPressed("up") then
      if self.closeSelected then
        self.closeSelected = false
        self.index = #self.rows
      elseif self.index > 1 then
        self.index = self.index - 1
      else
        self.closeSelected = true
      end
      self:ensureVisible()
    elseif input:wasPressed("down") then
      if self.closeSelected then
        self.closeSelected = false
        self.index = 1
      elseif self.index < #self.rows then
        self.index = self.index + 1
      else
        self.closeSelected = true
      end
      self:ensureVisible()
    elseif input:wasPressed("left") then
      self.closeSelected = false
      self.index = math.max(1, self.index - TRACKER_VISIBLE_ROWS)
      self:ensureVisible()
    elseif input:wasPressed("right") then
      self.closeSelected = false
      self.index = math.min(#self.rows, self.index + TRACKER_VISIBLE_ROWS)
      self:ensureVisible()
    end
  end

  function Screen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)

    Font.draw("SILPH TRACKER", 16, 8)

    if #self.rows == 0 then
      Font.draw(self.emptyText, 16, TRACKER_TOP_Y)
    else
      local last = math.min(#self.rows, self.scroll + TRACKER_VISIBLE_ROWS - 1)
      local slot = 0
      for i = self.scroll, last do
        local row = self.rows[i]
        local y = TRACKER_TOP_Y + slot * TRACKER_ROW_STEP
        Font.draw(row.name, TRACKER_NAME_X, y)
        Font.draw(row.band, TRACKER_SIGNAL_X, y + 8)
        if not self.closeSelected and i == self.index then
          Font.drawCode(Theme.cursor, TRACKER_CURSOR_X, y)
        end
        slot = slot + 1
      end
      if last < #self.rows then
        Font.drawCode(Theme.moreArrow, 144, 120)
      end
    end

    Font.draw("CLOSE", TRACKER_NAME_X, TRACKER_CLOSE_Y)
    if self.closeSelected then
      Font.drawCode(Theme.cursor, TRACKER_CURSOR_X, TRACKER_CLOSE_Y)
    end

    love.graphics.setColor(1, 1, 1, 1)
  end

  return Screen.new()
end

function SilphTracker.install(mod, runtime, Weights, ElusiveScent)
  local function scentStrength()
    if not runtime:isActive(ElusiveScent.EFFECT_ID) then return nil end
    return ElusiveScent.resolveStrength(mod.options:get(ElusiveScent.STRENGTH_OPTION))
  end

  local function applyScent(dist)
    local strength = scentStrength()
    if not strength then return dist end
    return Weights.compressDistribution(dist, strength)
  end

  local function preview(mapId, terrain)
    if mod.world and type(mod.world.effectiveEncounters) == "function" then
      local ok, info = pcall(mod.world.effectiveEncounters, mod.world, mapId, terrain)
      if ok and info and type(info.dist) == "table" then
        return applyScent(info.dist)
      end
    end
    local registry = mod.content and mod.content.encounters
    local encDef
    if registry and type(registry.get) == "function" then
      local ok, value = pcall(registry.get, registry, mapId)
      if ok then encDef = value end
    end
    return applyScent(Weights.distribution(encDef, terrain))
  end

  function SilphTracker.scan(game)
    local current = mod.world:current()
    if not current or not current.mapId then return {}, "NO LOCAL SIGNAL" end

    local combined = {}
    for _, terrain in ipairs({ "grass", "water" }) do
      local dist = preview(current.mapId, terrain)
      local total = Weights.total(dist)
      if total > 0 then
        for species, weight in pairs(dist) do
          local share = weight / total
          local band = Weights.signalBand(weight, total)
          local old = combined[species]
          if not old or BAND_RANK[band] > BAND_RANK[old.band]
              or (BAND_RANK[band] == BAND_RANK[old.band] and share > old.share) then
            combined[species] = { species=species, band=band, share=share }
          end
        end
      end
    end

    local out = {}
    for _, row in pairs(combined) do
      row.name = displayName(game, row.species)
      out[#out + 1] = row
    end
    table.sort(out, function(a, b)
      if a.share ~= b.share then return a.share > b.share end
      if a.name ~= b.name then return a.name < b.name end
      return tostring(a.species) < tostring(b.species)
    end)
    return out, (#out == 0) and "NO LOCAL SIGNAL" or nil
  end

  function SilphTracker.open(game)
    local rows, empty = SilphTracker.scan(game)
    game.stack:push(newTrackerScreen(game, rows, empty))
  end

  -- Retained for debugging/external consumers; the player-facing UI uses open().
  function SilphTracker.text(game)
    local rows, empty = SilphTracker.scan(game)
    if #rows == 0 then return "SILPH TRACKER\n" .. (empty or "NO LOCAL SIGNAL") end
    local lines = { "SILPH TRACKER" }
    for _, row in ipairs(rows) do
      lines[#lines + 1] = ("%s - %s"):format(row.name, row.band)
    end
    return table.concat(lines, "\n")
  end

  return SilphTracker
end

return SilphTracker
