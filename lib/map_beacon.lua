-- Map Beacon: persistent one-point field anchor. SET, RELOCATE and RETURN
-- each spend one Beacon only after their action successfully commits.

local MapBeacon = {}

MapBeacon.ITEM_ID = "DS_MAP_BEACON"
MapBeacon.ITEM_EFFECT_ID = "DS_MAP_BEACON_EFFECT"
MapBeacon.STATE_KEY = "map_beacon"

local DIRS = { up=true, down=true, left=true, right=true }

local function itemCount(game)
  return tonumber(game and game.save and game.save.inventory
    and game.save.inventory[MapBeacon.ITEM_ID]) or 0
end

local function copyPoint(point)
  if type(point) ~= "table" then return nil end
  if type(point.mapId) ~= "string" or point.mapId == ""
      or type(point.x) ~= "number" or type(point.y) ~= "number"
      or point.x < 0 or point.y < 0
      or point.x == math.huge or point.y == math.huge
      or point.x % 1 ~= 0 or point.y % 1 ~= 0 then return nil end
  return {
    mapId=point.mapId, x=point.x, y=point.y,
    facing=DIRS[point.facing] and point.facing or "down",
  }
end

function MapBeacon.get(runtime)
  return copyPoint(runtime:getReusableState(MapBeacon.STATE_KEY, nil))
end

function MapBeacon.set(runtime, point)
  local clean = copyPoint(point)
  if not clean then return false end
  runtime:setReusableState(MapBeacon.STATE_KEY, {
    version=1, mapId=clean.mapId, x=clean.x, y=clean.y, facing=clean.facing,
  })
  return true
end

function MapBeacon.clear(runtime)
  runtime:setReusableState(MapBeacon.STATE_KEY, nil)
end

function MapBeacon.closeItemFlow(list)
  if not list then return end
  if type(list.close) == "function" then list:close() end
  if type(list.closeStartMenu) == "function" then list.closeStartMenu() end
end

function MapBeacon.install(mod, runtime, TravelSafety)
  local pending = nil
  local takeItem = mod.content.commands:get("take_item")
  if type(takeItem) == "table" then takeItem = takeItem.fn end
  assert(type(takeItem) == "function", "missing public take_item command")

  local function fail(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function currentPoint(game)
    local pos = mod.world:current()
    if not pos then return nil, "No stable field location." end
    local ok, reason = TravelSafety.validateBeaconCell(
      game, mod.world, pos.mapId, pos.x, pos.y)
    if not ok then return nil, reason end
    return {
      mapId=pos.mapId, x=pos.x, y=pos.y,
      facing=DIRS[pos.facing] and pos.facing or "down",
    }
  end

  local function samePoint(a, b)
    return a and b and a.mapId == b.mapId and a.x == b.x and a.y == b.y
      and a.facing == b.facing
  end

  local function spend(game)
    takeItem({save=game.save}, MapBeacon.ITEM_ID, 1)
  end

  local function confirm(game, message, yesLabel, onYes)
    game.stack:push(mod.ui.TextBox.new(game, message, function()
      local menu
      local function close()
        if menu and type(menu.close) == "function" then menu:close() end
      end
      menu = mod.ui.Menu.new(game, {
        { label=yesLabel, onSelect=function()
            close()
            onYes()
          end },
        { label="CANCEL", onSelect=close },
      }, {
        tx=8, ty=4, tw=12, maxVisible=2, noWrap=true,
        title="MAP BEACON", anchor="topright", onCancel=close,
      })
      game.stack:push(menu)
    end))
  end

  local function queueSet(game, list, replacing)
    local point, reason = currentPoint(game)
    if not point then
      fail(game, "Cannot place a Beacon\nhere: " .. tostring(reason))
      return
    end
    local name = TravelSafety.mapName(game.data, point.mapId)
    local old = MapBeacon.get(runtime)
    local message
    if replacing and old then
      local oldName = TravelSafety.mapName(game.data, old.mapId)
      message = ("Replace %s\nwith %s?"):format(oldName, name)
    else
      message = ("Set Beacon at\n%s?"):format(name)
    end
    confirm(game, message, replacing and "RELOCATE" or "SET BEACON", function()
      MapBeacon.closeItemFlow(list)
      pending = { kind="set", game=game, point=point, wait=0 }
    end)
  end

  local function queueReturn(game, list, point)
    local ok, reason = TravelSafety.validateBeaconCell(
      game, mod.world, point.mapId, point.x, point.y)
    if not ok then
      fail(game, "Saved Beacon is\nunsafe: " .. tostring(reason))
      return
    end
    local name = TravelSafety.mapName(game.data, point.mapId)
    confirm(game, ("Beacon signal:\n%s. Return?"):format(name),
      "RETURN", function()
        MapBeacon.closeItemFlow(list)
        pending = { kind="return", game=game, point=copyPoint(point), wait=0 }
      end)
  end

  local function openActions(game, list)
    local stored = MapBeacon.get(runtime)
    if not stored then
      queueSet(game, list, false)
      return
    end

    local menu
    local function close()
      if menu and type(menu.close) == "function" then menu:close() end
    end
    menu = mod.ui.Menu.new(game, {
      { label="RETURN", onSelect=function()
          close()
          queueReturn(game, list, stored)
        end },
      { label="RELOCATE", onSelect=function()
          close()
          queueSet(game, list, true)
        end },
      { label="CANCEL", onSelect=close },
    }, {
      tx=7, ty=3, tw=13, maxVisible=3, noWrap=true,
      title="MAP BEACON", anchor="topright", onCancel=close,
    })
    game.stack:push(menu)
  end

  mod.hooks:wrap("item.use",
    function(next, game, battle, id, itemTarget, list, moveIndex, picker)
      if id ~= MapBeacon.ITEM_ID then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if battle then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if itemCount(game) <= 0 then return nil end

      local current = mod.world:current()
      if not current
          or TravelSafety.mapBlocked(current.mapId, game.save, {blockStory=true}) then
        fail(game, "The MAP BEACON cannot\noperate here.")
        return nil
      end

      openActions(game, list)
      return nil
    end)

  mod.content.item_effects:register(MapBeacon.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function()
      -- Selection/confirmation and successful-only consumption are owned by
      -- item.use + the deferred safe-field commit below.
      return "failed", { "The MAP BEACON has\nno stable signal." }
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    local p = pending
    if not p or p.game ~= game then return result end

    if itemCount(game) <= 0 then pending=nil; return result end

    local current = mod.world:current()
    if not current
        or TravelSafety.mapBlocked(current.mapId, game.save, {blockStory=true}) then
      pending=nil
      fail(game, "The MAP BEACON cannot\noperate here.")
      return result
    end

    local ready = TravelSafety.fieldReady(mod.world)
    if not ready then
      p.wait = p.wait + 1
      if p.wait < 3 then return result end
      pending=nil
      fail(game, "The MAP BEACON cannot\nlock on right now.")
      return result
    end

    if p.kind == "set" then
      local now, reason = currentPoint(game)
      if not now or not samePoint(now, p.point) then
        pending=nil
        fail(game, "Beacon placement\nchanged before lock.")
        return result
      end
      if not MapBeacon.set(runtime, p.point) then
        pending=nil
        fail(game, "Beacon location could\nnot be recorded.")
        return result
      end
      spend(game)
      pending=nil
      fail(game, "Beacon location\nrecorded.")
      return result
    end

    if p.kind == "return" then
      local stored = MapBeacon.get(runtime)
      if not stored or not samePoint(stored, p.point) then
        pending=nil
        fail(game, "The saved Beacon\nchanged before return.")
        return result
      end
      local ok, reason = TravelSafety.validateBeaconCell(
        game, mod.world, stored.mapId, stored.x, stored.y)
      if not ok then
        pending=nil
        fail(game, "Saved Beacon is\nunsafe: " .. tostring(reason))
        return result
      end
      local warped = mod.world:warpTo(
        stored.mapId, stored.x, stored.y, stored.facing, {arrive="teleport"})
      if not warped then
        pending=nil
        fail(game, "The MAP BEACON failed\nto establish a route.")
        return result
      end
      spend(game)
      pending=nil
      return result
    end

    pending=nil
    return result
  end)

  MapBeacon.pending = function() return pending end
  return MapBeacon
end

return MapBeacon
