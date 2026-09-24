-- Move Recorder: recover one missed natural level-up move from a party
-- Pokemon's current evolutionary lineage. The selection flow stays in the
-- bag, then returns the engine's native "learn" result so Gen1Recomp owns the
-- ordinary learn/forget presentation and only consumes the Recorder if the
-- move is actually learned.

local MoveRecorder = {}

MoveRecorder.ITEM_ID = "DS_MOVE_RECORDER"
MoveRecorder.ITEM_EFFECT_ID = "DS_MOVE_RECORDER_EFFECT"

local function moveKnown(mon, moveId)
  for _, mv in ipairs(mon and mon.moves or {}) do
    if mv.id == moveId then return true end
  end
  return false
end

-- Return possible ancestors oldest-first, followed by the current species.
-- Reverse edges come from the merged evolution registry, so modded species and
-- non-level evolution methods participate without a hard-coded family table.
function MoveRecorder.lineageSpecies(data, species)
  local pokemon = data and data.pokemon or {}
  local out, emitted, visiting = {}, {}, {}

  local function parentsOf(child)
    local parents = {}
    for parent, def in pairs(pokemon) do
      for _, evo in ipairs(def.evolutions or {}) do
        if evo.species == child and pokemon[parent] then
          parents[#parents + 1] = parent
          break
        end
      end
    end
    table.sort(parents, function(a, b)
      local an = (pokemon[a] and pokemon[a].name) or a
      local bn = (pokemon[b] and pokemon[b].name) or b
      if an == bn then return a < b end
      return an < bn
    end)
    return parents
  end

  local function visit(current)
    if visiting[current] then return end
    visiting[current] = true
    for _, parent in ipairs(parentsOf(current)) do visit(parent) end
    visiting[current] = nil
    if pokemon[current] and not emitted[current] then
      emitted[current] = true
      out[#out + 1] = current
    end
  end

  if type(species) == "string" then visit(species) end
  return out
end

-- Eligible Recorder moves are natural starting/level-up moves from any stage
-- in the current mon's ancestry, at or below its current level, excluding
-- moves it already knows. TM/HM/tutor/event compatibility is intentionally
-- irrelevant because those sources are not part of level1Moves/learnset.
function MoveRecorder.missedMoves(data, mon)
  if not (data and data.pokemon and mon and data.pokemon[mon.species]) then return {} end
  local level = math.max(1, tonumber(mon.level) or 1)
  local known, added, rows = {}, {}, {}
  for _, mv in ipairs(mon.moves or {}) do if mv.id then known[mv.id] = true end end

  local function add(moveId, learnedAt, stage)
    if not moveId or known[moveId] or added[moveId] then return end
    local mdef = data.moves and data.moves[moveId]
    if not mdef then return end
    added[moveId] = true
    rows[#rows + 1] = {
      id = moveId,
      name = mdef.name or moveId,
      level = learnedAt,
      species = stage,
    }
  end

  for _, stage in ipairs(MoveRecorder.lineageSpecies(data, mon.species)) do
    local def = data.pokemon[stage]
    for _, moveId in ipairs(def.level1Moves or {}) do add(moveId, 1, stage) end
    for _, entry in ipairs(def.learnset or {}) do
      local learnedAt = tonumber(entry.level) or 0
      if learnedAt <= level then add(entry.move, learnedAt, stage) end
    end
  end
  return rows
end

function MoveRecorder.eligibleParty(game)
  local rows = {}
  for slot, mon in ipairs(game and game.save and game.save.party or {}) do
    local moves = MoveRecorder.missedMoves(game.data, mon)
    if #moves > 0 then
      local def = game.data.pokemon[mon.species] or {}
      rows[#rows + 1] = {
        slot = slot,
        mon = mon,
        name = mon.nickname or def.name or mon.species,
        moves = moves,
      }
    end
  end
  return rows
end

local function stillEligible(data, mon, moveId)
  for _, row in ipairs(MoveRecorder.missedMoves(data, mon)) do
    if row.id == moveId then return true end
  end
  return false
end

function MoveRecorder.install(mod)
  local selected = nil

  mod.hooks:wrap("item.use", function(next, game, battle, id, itemTarget, list, moveIndex, picker)
    if id ~= MoveRecorder.ITEM_ID or battle then
      return next(game, battle, id, itemTarget, list, moveIndex, picker)
    end

    local eligible = MoveRecorder.eligibleParty(game)
    if #eligible == 0 then
      game.stack:push(mod.ui.TextBox.new(game,
        "No party POKEMON has\na missed natural move."))
      return nil
    end

    local targetRows = {}
    for _, row in ipairs(eligible) do
      targetRows[#targetRows + 1] = { label = row.name, value = row }
    end
    targetRows[#targetRows + 1] = { label = "CANCEL", value = false }

    local targetMenu
    targetMenu = mod.ui.ListMenu.new(game, "MOVE RECORDER", targetRows, {
      pageJump = true,
      onChoose = function(choice)
        if not choice or choice.value == false then
          if targetMenu then targetMenu:close() end
          return
        end
        local target = choice.value
        if targetMenu then targetMenu:close() end

        -- Re-read merged data here rather than trusting the snapshot used to
        -- draw the first menu; another mod may have changed the mon meanwhile.
        local moves = MoveRecorder.missedMoves(game.data, target.mon)
        if #moves == 0 then
          game.stack:push(mod.ui.TextBox.new(game,
            "That POKEMON has no\nmove to recall now."))
          return
        end
        local moveRows = {}
        for _, move in ipairs(moves) do
          moveRows[#moveRows + 1] = { label = move.name, value = move.id }
        end
        moveRows[#moveRows + 1] = { label = "CANCEL", value = false }

        local moveMenu
        moveMenu = mod.ui.ListMenu.new(game, "RECALL MOVE", moveRows, {
          pageJump = true,
          onChoose = function(moveChoice)
            if not moveChoice or moveChoice.value == false then
              if moveMenu then moveMenu:close() end
              return
            end
            selected = { mon = target.mon, moveId = moveChoice.value }
            if moveMenu then moveMenu:close() end
            next(game, battle, id, target.mon, list, moveIndex, picker)
          end,
          onCancel = function()
            if moveMenu then moveMenu:close() end
          end,
        })
        game.stack:push(moveMenu)
      end,
      onCancel = function()
        if targetMenu then targetMenu:close() end
      end,
    })
    game.stack:push(targetMenu)
    return nil
  end)

  mod.content.item_effects:register(MoveRecorder.ITEM_EFFECT_ID, {
    needsTarget = false,
    field = true,
    battle = false,
    use = function(ctx)
      local pick = selected
      selected = nil
      if not pick or not ctx.target or pick.mon ~= ctx.target
          or not stillEligible(ctx.data, ctx.target, pick.moveId) then
        return "failed", { "The MOVE RECORDER\nfound no valid memory." }
      end
      -- BagMenu's native "learn" branch owns the four-move replacement UI,
      -- learned-move text/jingle, Pikachu happiness, and successful-only
      -- consumption. Cancelling that native flow therefore keeps the item.
      return "learn", pick.moveId
    end,
  })

  MoveRecorder.selected = function() return selected end
  return MoveRecorder
end

return MoveRecorder
