-- Emergency Teleporter: one-use travel to the exterior landing associated
-- with the last valid Pokemon Center heal point. It is travel only: no heal,
-- status cure, money loss, blackout semantics or DScrete-effect reset.

local EmergencyTeleporter = {}

EmergencyTeleporter.ITEM_ID = "DS_TELEPORTER"
EmergencyTeleporter.ITEM_EFFECT_ID = "DS_TELEPORTER_EFFECT"

function EmergencyTeleporter.destination(data, save)
  local heal = save and save.lastHeal
  if type(heal) ~= "table" then return nil end
  local field = data and data.field or {}
  local maps = data and data.maps or {}
  local out = type(heal.outdoor) == "table" and heal.outdoor or nil

  -- Older/imported saves can carry an outdoor heal id directly. Accept it
  -- only when the engine's canonical fly table identifies an exterior landing.
  if not out and field.flyWarps and field.flyWarps[heal.map] then
    out = { id = heal.map, x = heal.x, y = heal.y }
  end
  if not (out and type(out.id) == "string" and maps[out.id]) then return nil end

  local fly = field.flyWarps and field.flyWarps[out.id]
  local x = fly and fly.x or out.x
  local y = fly and fly.y or out.y
  if type(x) ~= "number" or type(y) ~= "number"
      or x < 0 or y < 0 or x == math.huge or y == math.huge
      or x % 1 ~= 0 or y % 1 ~= 0 then return nil end
  return { map = out.id, x = x, y = y, facing = "down" }
end

function EmergencyTeleporter.closeItemFlow(list)
  if not list then return end
  if type(list.close) == "function" then list:close() end
  if type(list.closeStartMenu) == "function" then list.closeStartMenu() end
end

function EmergencyTeleporter.install(mod, TravelSafety)
  local pending = nil
  local takeItem = mod.content.commands:get("take_item")
  if type(takeItem) == "table" then takeItem = takeItem.fn end
  assert(type(takeItem) == "function", "missing public take_item command")

  local function fail(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function spend(game)
    local inv = game.save and game.save.inventory or {}
    local count = tonumber(inv[EmergencyTeleporter.ITEM_ID]) or 0
    if count < 1 then return false end
    local ok = pcall(takeItem, {save=game.save}, EmergencyTeleporter.ITEM_ID, 1)
    return ok and (tonumber(inv[EmergencyTeleporter.ITEM_ID]) or 0) == count - 1
  end

  mod.hooks:wrap("item.use",
    function(next, game, battle, id, itemTarget, list, moveIndex, picker)
      if id ~= EmergencyTeleporter.ITEM_ID then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if battle then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end

      local current = mod.world:current()
      if not current then
        fail(game, "The TELEPORTER cannot\noperate here.")
        return nil
      end
      local blocked = TravelSafety.mapBlocked(current.mapId, game.save)
      if blocked then
        fail(game, "The TELEPORTER cannot\noperate here.")
        return nil
      end
      local dest = EmergencyTeleporter.destination(game.data, game.save)
      if not dest then
        fail(game, "No valid POKEMON\nCENTER signal exists.")
        return nil
      end
      if (tonumber(game.save.inventory
          and game.save.inventory[EmergencyTeleporter.ITEM_ID]) or 0) <= 0 then
        return nil
      end

      EmergencyTeleporter.closeItemFlow(list)
      pending = { game = game, dest = dest, wait = 0 }
      return nil
    end)

  mod.content.item_effects:register(EmergencyTeleporter.ITEM_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function()
      -- Normal field use is intercepted above so consumption happens only
      -- after the public warp request has been accepted.
      return "failed", { "The TELEPORTER has\nno stable signal." }
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    local p = pending
    if not p or p.game ~= game then return result end

    if p.kind == "arriving" then return result end
    local current = mod.world:current()
    if not current or TravelSafety.mapBlocked(current.mapId, game.save) then
      pending = nil
      fail(game, "The TELEPORTER signal\nwas interrupted.")
      return result
    end

    local ready = TravelSafety.fieldReady(mod.world)
    if not ready then
      -- Allow the just-closed Bag/Start stack to unwind. A state that remains
      -- busy is conservatively refused rather than interrupted.
      p.wait = p.wait + 1
      if p.wait < 3 then return result end
      pending = nil
      fail(game, "The TELEPORTER cannot\nlock on right now.")
      return result
    end

    local dest = EmergencyTeleporter.destination(game.data, game.save)
    if not dest then
      pending = nil
      fail(game, "The CENTER signal\nwas lost.")
      return result
    end
    if (tonumber(game.save.inventory
        and game.save.inventory[EmergencyTeleporter.ITEM_ID]) or 0) <= 0 then
      pending = nil
      return result
    end

    local origin = {
      mapId=current.mapId, x=current.x, y=current.y,
      facing=current.facing or "down",
    }
    p.kind = "arriving"
    local function onArrival()
      if pending ~= p then return end
      pending = nil
      local now = mod.world:current()
      if now and now.mapId == dest.map
          and now.x == dest.x and now.y == dest.y and spend(game) then
        return
      end
      -- A warp request is only an accepted transition, not proof that the
      -- player arrived. Restore a recorded departure where possible.
      if now and origin.mapId and type(origin.x) == "number"
          and type(origin.y) == "number" then
        mod.world:warpTo(origin.mapId, origin.x, origin.y,
          origin.facing, {arrive="teleport"})
      end
      fail(game, "The TELEPORTER arrival\nfailed. No charge was made.")
    end
    local ok = mod.world:warpTo(
      dest.map, dest.x, dest.y, dest.facing,
      { arrive = "teleport", onDone = onArrival })
    if not ok then
      pending = nil
      fail(game, "The TELEPORTER failed\nto establish a route.")
    end
    return result
  end)

  EmergencyTeleporter.pending = function() return pending end
  return EmergencyTeleporter
end

return EmergencyTeleporter
