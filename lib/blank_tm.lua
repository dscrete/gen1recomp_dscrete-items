-- Blank TM: copy one currently-known non-HM move into a persistent
-- RECORDED TM. Recorded copies are immutable; teaching uses merged machine
-- or natural learn data and delegates the final transaction to native learn UI.

local BlankTM = {}

BlankTM.ITEM_ID = "DS_BLANK_TM"
BlankTM.ITEM_EFFECT_ID = "DS_BLANK_TM_EFFECT"
BlankTM.RECORDED_ITEM_ID = "DS_RECORDED_TM"
BlankTM.RECORDED_EFFECT_ID = "DS_RECORDED_TM_EFFECT"
BlankTM.STATE_KEY = "blank_tm"

local function contains(list, value)
  for _, v in ipairs(list or {}) do
    if v == value then return true end
  end
  return false
end

local function knows(mon, moveId)
  for _, mv in ipairs(mon and mon.moves or {}) do
    if mv.id == moveId then return true end
  end
  return false
end

function BlankTM.isHM(data, moveId)
  if type(moveId) ~= "string" or moveId == "" then return false end
  local constants = data and data.constants or {}
  if contains(constants.hmMoves, moveId) then return true end
  for _, item in pairs(data and data.items or {}) do
    local machine = type(item) == "table" and item.machine or nil
    if machine and machine.kind == "HM" and machine.move == moveId then
      return true
    end
  end
  return false
end

function BlankTM.recordableMoves(data, mon)
  local out, seen = {}, {}
  for _, mv in ipairs(mon and mon.moves or {}) do
    local id = mv.id
    if type(id) == "string" and not seen[id]
        and data and data.moves and data.moves[id]
        and not BlankTM.isHM(data, id) then
      seen[id] = true
      out[#out + 1] = { id = id, name = data.moves[id].name or id }
    end
  end
  return out
end

function BlankTM.recordableParty(game)
  local out, data = {}, game and game.data
  for slot, mon in ipairs(game and game.save and game.save.party or {}) do
    local moves = BlankTM.recordableMoves(data, mon)
    if #moves > 0 then
      local def = data and data.pokemon and data.pokemon[mon.species] or {}
      out[#out + 1] = {
        slot = slot, mon = mon, moves = moves,
        name = mon.nickname or def.name or mon.species or ("POKEMON " .. slot),
      }
    end
  end
  return out
end

function BlankTM.canLearn(data, mon, moveId)
  if not (data and data.moves and data.moves[moveId]
      and data.pokemon and mon and mon.species) then return false end
  if knows(mon, moveId) then return false end
  local def = data.pokemon[mon.species]
  if not def then return false end
  if contains(def.tmhm, moveId) or contains(def.level1Moves, moveId) then
    return true
  end
  for _, row in ipairs(def.learnset or {}) do
    if row.move == moveId then return true end
  end
  return false
end

function BlankTM.eligibleParty(game, moveId)
  local out = {}
  for slot, mon in ipairs(game and game.save and game.save.party or {}) do
    if BlankTM.canLearn(game.data, mon, moveId) then
      local def = game.data.pokemon[mon.species] or {}
      out[#out + 1] = {
        slot = slot, mon = mon,
        name = mon.nickname or def.name or mon.species or ("POKEMON " .. slot),
      }
    end
  end
  return out
end

local function state(runtime)
  local s = runtime:getReusableState(BlankTM.STATE_KEY, nil)
  if type(s) ~= "table" then s = {} end
  if type(s.recordings) ~= "table" then s.recordings = {} end
  return s
end

local function saveState(runtime, s)
  runtime:setReusableState(BlankTM.STATE_KEY, s)
end

function BlankTM.recordings(runtime)
  local s, out = state(runtime), {}
  for i, moveId in ipairs(s.recordings) do out[i] = moveId end
  return out
end

function BlankTM.removeRecording(runtime, index, moveId)
  local s = state(runtime)
  if type(index) == "number" and s.recordings[index] == moveId then
    table.remove(s.recordings, index)
    saveState(runtime, s)
    return true
  end
  for i, id in ipairs(s.recordings) do
    if id == moveId then
      table.remove(s.recordings, i)
      saveState(runtime, s)
      return true
    end
  end
  return false
end

local function itemCount(game, id)
  return tonumber(game and game.save and game.save.inventory
    and game.save.inventory[id]) or 0
end

function BlankTM.closeItemFlow(list)
  if not list then return end
  if type(list.close) == "function" then list:close() end
  if type(list.closeStartMenu) == "function" then list.closeStartMenu() end
end

function BlankTM.convert(save, data, moveId, runtime, Bag)
  Bag = Bag or require("src.inventory.Bag")
  if not (save and save.inventory and data and data.moves
      and data.moves[moveId]) then return false end
  if BlankTM.isHM(data, moveId) then return false end
  if (tonumber(save.inventory[BlankTM.ITEM_ID]) or 0) <= 0 then return false end

  -- Remove first so a full bag can exchange BLANK TM -> RECORDED TM in the
  -- slot it just freed. Roll back completely if the add fails.
  Bag.remove(save, BlankTM.ITEM_ID, 1, data)
  if not Bag.add(save, BlankTM.RECORDED_ITEM_ID, 1, data) then
    Bag.add(save, BlankTM.ITEM_ID, 1, data)
    return false
  end
  local s = state(runtime)
  s.recordings[#s.recordings + 1] = moveId
  saveState(runtime, s)
  return true
end

local function rowsWithCancel(values, label)
  local rows = {}
  for _, value in ipairs(values) do
    rows[#rows + 1] = { label = label(value), value = value }
  end
  rows[#rows + 1] = { label = "CANCEL", value = false }
  return rows
end

function BlankTM.install(mod, runtime)
  local selectedRecord, selectedTeach, pendingTeach

  -- The bag has one protected RECORDED TM stack; its individual immutable
  -- contents live in mod.save. This remains compatible with modded moves
  -- discovered only in the final merged runtime data.
  mod.content.items:register(BlankTM.RECORDED_ITEM_ID, {
    id = BlankTM.RECORDED_ITEM_ID,
    name = "RECORDED TM",
    price = 0,
    keyItem = true, -- prevent TOSS from desynchronizing stored recordings
    tossable = false,
    effect = BlankTM.RECORDED_EFFECT_ID,
  })

  local function noTarget(game)
    game.stack:push(mod.ui.TextBox.new(game,
      "No party POKEMON can\nlearn that recording."))
  end

  local function finalizeIfSpent(game)
    local p = pendingTeach
    if not p then return false end
    if itemCount(game, BlankTM.RECORDED_ITEM_ID) >= p.beforeCount then
      return false
    end
    BlankTM.removeRecording(runtime, p.index, p.moveId)
    pendingTeach = nil
    return true
  end

  mod.hooks:wrap("item.use",
    function(next, game, battle, id, itemTarget, list, moveIndex, picker)
      if id ~= BlankTM.ITEM_ID and id ~= BlankTM.RECORDED_ITEM_ID then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end
      if battle then
        return next(game, battle, id, itemTarget, list, moveIndex, picker)
      end

      -- A new attempt supersedes a stale cancelled native learn screen.
      pendingTeach = nil

      if id == BlankTM.ITEM_ID then
        local sources = BlankTM.recordableParty(game)
        if #sources == 0 then
          game.stack:push(mod.ui.TextBox.new(game,
            "No party POKEMON has\na recordable move."))
          return nil
        end
        local sourceMenu
        sourceMenu = mod.ui.ListMenu.new(game, "TM SOURCE",
          rowsWithCancel(sources, function(row) return row.name end), {
          pageJump = true,
          onChoose = function(choice)
            if not choice or choice.value == false then
              if sourceMenu then sourceMenu:close() end
              return
            end
            local source = choice.value
            if sourceMenu then sourceMenu:close() end
            local moves = BlankTM.recordableMoves(game.data, source.mon)
            if #moves == 0 then
              game.stack:push(mod.ui.TextBox.new(game,
                "That POKEMON has no\nrecordable move now."))
              return
            end

            local moveMenu
            moveMenu = mod.ui.ListMenu.new(game, "RECORD MOVE",
              rowsWithCancel(moves, function(row) return row.name end), {
              pageJump = true,
              onChoose = function(moveChoice)
                if not moveChoice or moveChoice.value == false then
                  if moveMenu then moveMenu:close() end
                  return
                end
                local moveId = moveChoice.value.id
                if moveMenu then moveMenu:close() end
                local mdef = game.data.moves[moveId] or {}
                local confirm
                local function closeConfirm()
                  if confirm and type(confirm.close) == "function" then
                    confirm:close()
                  end
                end
                confirm = mod.ui.Menu.new(game, {
                  { label = "RECORD", onSelect = function()
                      closeConfirm()
                      selectedRecord = { mon = source.mon, moveId = moveId }
                      BlankTM.closeItemFlow(list)
                      next(game, battle, id, source.mon, list, moveIndex, picker)
                    end },
                  { label = "CANCEL", onSelect = closeConfirm },
                }, {
                  tx = 8, ty = 4, tw = 12, maxVisible = 2, noWrap = true,
                  title = mdef.name or "RECORD?", anchor = "topright",
                  onCancel = closeConfirm,
                })
                game.stack:push(confirm)
              end,
              onCancel = function()
                if moveMenu then moveMenu:close() end
              end,
            })
            game.stack:push(moveMenu)
          end,
          onCancel = function()
            if sourceMenu then sourceMenu:close() end
          end,
        })
        game.stack:push(sourceMenu)
        return nil
      end

      local recordings = BlankTM.recordings(runtime)
      if #recordings == 0 then
        game.stack:push(mod.ui.TextBox.new(game,
          "No move is stored in\nthis RECORDED TM."))
        return nil
      end
      local choices = {}
      for index, moveId in ipairs(recordings) do
        choices[#choices + 1] = { index = index, moveId = moveId }
      end
      local recordMenu
      recordMenu = mod.ui.ListMenu.new(game, "RECORDED TMS",
        rowsWithCancel(choices, function(row)
          local def = game.data.moves[row.moveId]
          return (def and def.name) or row.moveId
        end), {
        pageJump = true,
        onChoose = function(recordChoice)
          if not recordChoice or recordChoice.value == false then
            if recordMenu then recordMenu:close() end
            return
          end
          local rec = recordChoice.value
          if recordMenu then recordMenu:close() end
          if not game.data.moves[rec.moveId] then
            game.stack:push(mod.ui.TextBox.new(game,
              "That recording can no\nlonger be decoded."))
            return
          end
          local eligible = BlankTM.eligibleParty(game, rec.moveId)
          if #eligible == 0 then noTarget(game); return end

          local targetMenu
          targetMenu = mod.ui.ListMenu.new(game, "TEACH TO",
            rowsWithCancel(eligible, function(row) return row.name end), {
            pageJump = true,
            onChoose = function(targetChoice)
              if not targetChoice or targetChoice.value == false then
                if targetMenu then targetMenu:close() end
                return
              end
              local target = targetChoice.value
              if targetMenu then targetMenu:close() end
              if not BlankTM.canLearn(game.data, target.mon, rec.moveId) then
                noTarget(game)
                return
              end
              selectedTeach = {
                index = rec.index, moveId = rec.moveId, mon = target.mon,
              }
              local before = itemCount(game, BlankTM.RECORDED_ITEM_ID)
              next(game, battle, id, target.mon, list, moveIndex, picker)
              -- A free move slot consumes synchronously. Four-move replacement
              -- consumes later only if the native forget screen succeeds.
              if itemCount(game, BlankTM.RECORDED_ITEM_ID) < before then
                BlankTM.removeRecording(runtime, rec.index, rec.moveId)
                selectedTeach = nil
              else
                pendingTeach = {
                  index = rec.index, moveId = rec.moveId,
                  mon = target.mon, beforeCount = before,
                }
              end
            end,
            onCancel = function()
              if targetMenu then targetMenu:close() end
            end,
          })
          game.stack:push(targetMenu)
        end,
        onCancel = function()
          if recordMenu then recordMenu:close() end
        end,
      })
      game.stack:push(recordMenu)
      return nil
    end)

  mod.content.item_effects:register(BlankTM.ITEM_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function(ctx)
      local pick = selectedRecord
      selectedRecord = nil
      if not pick or pick.mon ~= ctx.target or not knows(ctx.target, pick.moveId)
          or BlankTM.isHM(ctx.data, pick.moveId) then
        return "failed", { "The recording source\nchanged before use." }
      end
      if not BlankTM.convert(ctx.save, ctx.data, pick.moveId, runtime) then
        return "failed", { "The BLANK TM could\nnot be recorded." }
      end
      local name = (ctx.data.moves[pick.moveId] or {}).name or pick.moveId
      return "kept", { ("Recorded %s\nonto a new TM!"):format(name) }
    end,
  })

  mod.content.item_effects:register(BlankTM.RECORDED_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function(ctx)
      local pick = selectedTeach
      selectedTeach = nil
      if not pick or pick.mon ~= ctx.target
          or not BlankTM.canLearn(ctx.data, ctx.target, pick.moveId) then
        return "failed", { "That recording cannot\nbe taught now." }
      end
      -- Native BagMenu owns four-move replacement, HM-forget protection,
      -- presentation, cancellation and successful-only item consumption.
      return "learn", pick.moveId
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    finalizeIfSpent(game)
    return result
  end)

  BlankTM.pendingTeach = function() return pendingTeach end
  BlankTM.recordedCount = function(game)
    return itemCount(game, BlankTM.RECORDED_ITEM_ID)
  end
  BlankTM.clearRecorded = function(game)
    local Bag = require("src.inventory.Bag")
    local n = itemCount(game, BlankTM.RECORDED_ITEM_ID)
    if n > 0 then
      Bag.remove(game.save, BlankTM.RECORDED_ITEM_ID, n, game.data)
    end
    saveState(runtime, { recordings = {} })
    pendingTeach = nil
  end
  return BlankTM
end

return BlankTM
