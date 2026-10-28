-- PC Transfer Unit: one-use portable access to Gen1Recomp's native
-- Pokemon-storage UI. No warp or map mutation is involved; the live field
-- remains underneath the storage screens exactly where the player used it.

local PCTransfer = {}

PCTransfer.ITEM_ID = "DS_PC_TRANSFER"
PCTransfer.ITEM_EFFECT_ID = "DS_PC_TRANSFER_EFFECT"

function PCTransfer.closeItemFlow(list)
  if not list then return end
  if type(list.close) == "function" then list:close() end
  if type(list.closeStartMenu) == "function" then list.closeStartMenu() end
end

-- Gen 1's BoxMenu is Bill's actual Pokemon-storage interface:
-- WITHDRAW / DEPOSIT / RELEASE / CHANGE BOX (+ Yellow PRINT BOX).
-- It deliberately skips the broader PC root, so item storage is inaccessible.
function PCTransfer.openNativeStorage(game)
  local ok, BoxMenu = pcall(require, "src.ui.BoxMenu")
  if not ok or not (BoxMenu and type(BoxMenu.new) == "function") then
    return nil, "pokemon storage unavailable"
  end
  local made, menu = pcall(BoxMenu.new, game)
  if not made or not menu then return nil, "pokemon storage unavailable" end
  local pushed = pcall(function() game.stack:push(menu) end)
  if not pushed then return nil, "pokemon storage unavailable" end
  return true
end

function PCTransfer.install(mod, TravelSafety, opts)
  opts = opts or {}
  local openStorage = opts.openStorage or PCTransfer.openNativeStorage
  local pending = nil
  local takeItem = mod.content.commands:get("take_item")
  if type(takeItem) == "table" then takeItem = takeItem.fn end
  assert(type(takeItem) == "function", "missing public take_item command")

  local function itemCount(game)
    return tonumber(game and game.save and game.save.inventory
      and game.save.inventory[PCTransfer.ITEM_ID]) or 0
  end

  local function fail(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function contextValid(game)
    local current = mod.world:current()
    if not current then return false end
    if TravelSafety.mapBlocked(current.mapId, game.save) then return false end
    return true
  end

  local function connect(game)
    if not contextValid(game) or itemCount(game) <= 0 then return false end

    -- Constructing and pushing the native storage menu is the commit point.
    -- Only a successful open spends the unit.
    local opened = false
    local connecting
    connecting = mod.ui.TextBox.new(game,
      "Connecting to\nPOKEMON STORAGE...", function()
        if not contextValid(game) or itemCount(game) <= 0 then
          fail(game, "The storage link\nwas interrupted.")
          return
        end
        local ok = openStorage(game)
        if ok then
          takeItem({ save = game.save }, PCTransfer.ITEM_ID, 1)
          opened = true
        else
          fail(game, "Could not connect to\nPOKEMON STORAGE.")
        end
      end, { auto = { delay = 12 } })
    game.stack:push(connecting)
    return true, function() return opened end
  end

  mod.hooks:wrap("item.use",
    function(next, game, battle, id, itemTarget, list, moveIndex, picker)
      if id ~= PCTransfer.ITEM_ID then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if battle then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if not contextValid(game) then
        fail(game, "The PC TRANSFER cannot\noperate here.")
        return nil
      end
      if itemCount(game) <= 0 then return nil end

      PCTransfer.closeItemFlow(list)
      pending = { game = game, wait = 0 }
      return nil
    end)

  mod.content.item_effects:register(PCTransfer.ITEM_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function()
      -- The item.use hook owns the asynchronous menu transition so the unit
      -- is consumed only when native Pokemon storage actually opens.
      return "failed", { "The PC TRANSFER has\nno stable connection." }
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    local p = pending
    if not p or p.game ~= game then return result end

    if not contextValid(game) then
      pending = nil
      fail(game, "The PC TRANSFER cannot\noperate here.")
      return result
    end

    local ready = TravelSafety.fieldReady(mod.world)
    if not ready then
      -- The just-closed Bag/Start stack may need a frame or two to unwind.
      p.wait = p.wait + 1
      if p.wait < 3 then return result end
      pending = nil
      fail(game, "The PC TRANSFER cannot\nconnect right now.")
      return result
    end

    pending = nil
    connect(game)
    return result
  end)

  PCTransfer.pending = function() return pending end
  return PCTransfer
end

return PCTransfer
