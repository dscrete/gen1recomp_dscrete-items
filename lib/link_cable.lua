-- Link Cable: consume one cable to perform a semantic trade evolution on an
-- eligible party Pokemon. Eligibility comes from the merged evolution-method
-- registry with trigger.kind="trade" rather than a hard-coded species list,
-- so compatible Fakemon/custom Pokemon participate automatically.

local LinkCable = {}

LinkCable.ITEM_ID = "DS_LINK_CABLE"
LinkCable.ITEM_EFFECT_ID = "DS_LINK_CABLE_EFFECT"

function LinkCable.tradeTarget(game, mon)
  local data = game and game.data
  local def = data and data.pokemon and mon and data.pokemon[mon.species]
  if not def then return nil end
  local methods = data.evolution_methods or {}
  local trigger = { kind = "trade" }
  for _, evo in ipairs(def.evolutions or {}) do
    local method = methods[evo.method]
    local qualifies = false
    if method and type(method.check) == "function" then
      local ok, value = pcall(method.check, game, mon, evo, trigger)
      qualifies = ok and value == true
    elseif evo.method == "TRADE" then
      -- Defensive floor fallback: TRADE has been registered since 0.2.5,
      -- but a stripped standalone fixture may omit the method table.
      qualifies = true
    end
    if qualifies and data.pokemon[evo.species] then return evo.species, evo end
  end
  return nil
end

function LinkCable.eligibleParty(game)
  local rows = {}
  for slot, mon in ipairs(game and game.save and game.save.party or {}) do
    local to, evo = LinkCable.tradeTarget(game, mon)
    if to then
      local fromDef = game.data.pokemon[mon.species] or {}
      local toDef = game.data.pokemon[to] or {}
      rows[#rows + 1] = {
        slot = slot, mon = mon, to = to, evo = evo,
        name = mon.nickname or fromDef.name or mon.species,
        toName = toDef.name or to,
      }
    end
  end
  return rows
end

-- A confirmed Link Cable should behave like field items that transition into
-- another presentation: dismiss the Bag and its parent Start menu first. If
-- the Bag remains open, availableFieldActions() correctly reports the field as
-- busy and the queued evolution appears to do nothing until the player backs
-- out manually.
function LinkCable.closeItemFlow(list)
  if not list then return end
  if type(list.close) == "function" then list:close() end
  if type(list.closeStartMenu) == "function" then list.closeStartMenu() end
end

function LinkCable.install(mod)
  local selected = nil
  local pendingEvolution = nil

  mod.hooks:wrap("item.use", function(next, game, battle, id, itemTarget, list, moveIndex, picker)
    if id ~= LinkCable.ITEM_ID or battle then
      return next(game, battle, id, itemTarget, list, moveIndex, picker)
    end

    local eligible = LinkCable.eligibleParty(game)
    if #eligible == 0 then
      game.stack:push(mod.ui.TextBox.new(game,
        "No party POKEMON can\nevolve through a trade."))
      return nil
    end

    local rows = {}
    for _, row in ipairs(eligible) do
      rows[#rows + 1] = {
        label = ("%s -> %s"):format(row.name, row.toName),
        value = row,
      }
    end
    rows[#rows + 1] = { label = "CANCEL", value = false }

    local targetMenu
    targetMenu = mod.ui.ListMenu.new(game, "LINK TARGET", rows, {
      pageJump = true,
      onChoose = function(choice)
        if not choice or choice.value == false then
          if targetMenu then targetMenu:close() end
          return
        end
        local row = choice.value
        if targetMenu then targetMenu:close() end

        local confirm
        local function closeConfirm()
          if confirm and type(confirm.close) == "function" then confirm:close() end
        end
        confirm = mod.ui.Menu.new(game, {
          { label = "USE CABLE", onSelect = function()
              closeConfirm()
              selected = row
              -- The selector and confirmation have already validated this
              -- target synchronously, so unwind the item UI now. Vanilla item
              -- dispatch still owns consumption/messages; this only makes the
              -- resulting field evolution visible without another manual B.
              LinkCable.closeItemFlow(list)
              next(game, battle, id, row.mon, list, moveIndex, picker)
            end },
          { label = "CANCEL", onSelect = function() closeConfirm() end },
        }, {
          tx = 9, ty = 4, tw = 11, maxVisible = 2, noWrap = true,
          title = "LINK?", anchor = "topright",
          onCancel = closeConfirm,
        })
        game.stack:push(confirm)
      end,
      onCancel = function()
        if targetMenu then targetMenu:close() end
      end,
    })
    game.stack:push(targetMenu)
    return nil
  end)

  mod.content.item_effects:register(LinkCable.ITEM_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function(ctx)
      local row = selected
      selected = nil
      if not row or row.mon ~= ctx.target or not row.to then
        return "failed", { "The LINK CABLE has\nno valid target." }
      end
      -- Recheck that the mon has not changed species between the selector and
      -- the bag transaction. We deliberately keep the semantic target chosen
      -- through the merged evolution table instead of maintaining a species list.
      if not ctx.data or not ctx.data.pokemon or not ctx.data.pokemon[row.to] then
        return "failed", { "The LINK signal\ncannot resolve." }
      end
      pendingEvolution = { mon = row.mon, to = row.to, started = false }
      return "consumed", { "The LINK CABLE\nconnected!" }, { useJingle = true }
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if not pendingEvolution or pendingEvolution.started then return result end
    local _, busy = mod.world:availableFieldActions()
    if busy ~= nil then return result end

    local pending = pendingEvolution
    pending.started = true
    game.stack:push(mod.ui.TextBox.new(game, "LINK ESTABLISHED!", function()
      if pendingEvolution ~= pending then return end
      -- Passing via="TRADE" gives the native evolution screen genuine trade
      -- semantics: standard animation/move-learning and no B-cancel once the
      -- player has confirmed and spent the cable.
      mod.ui.push(game, "EvolutionState", pending.mon, pending.to, function()
        if pendingEvolution == pending then pendingEvolution = nil end
      end, "TRADE")
    end))
    return result
  end)

  LinkCable.pending = function() return pendingEvolution end
  return LinkCable
end

return LinkCable
