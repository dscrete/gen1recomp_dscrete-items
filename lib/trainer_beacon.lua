-- Trainer Beacon: consume one Beacon to rematch the defeated trainer the
-- player is facing. Rematch parties start from the trainer's current merged
-- party definition, receive a badge-tier level boost, and automatically take
-- ordinary LEVEL evolutions that the boosted level has reached.

local TrainerBeacon = {}

TrainerBeacon.ITEM_ID = "DS_TRAINER_BEACON"
TrainerBeacon.ITEM_EFFECT_ID = "DS_TRAINER_BEACON_EFFECT"
TrainerBeacon.STATE_KEY = "trainer_beacon"
TrainerBeacon.COOLDOWN_OPTION = "trainer_beacon_cooldown"
TrainerBeacon.DEFAULT_COOLDOWN = 500
TrainerBeacon.MONEY_FACTOR = 0.5
TrainerBeacon.BADGES = {
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE",
  "SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE",
}

-- Vanilla classes that are story bosses, rivals, Elite Four, or the broad
-- Rocket class. Individual targets can be explicitly whitelisted through
-- setTrainerEligibility without weakening these defaults for everybody else.
TrainerBeacon.EXCLUDED_CLASSES = {
  OPP_RIVAL1=true, OPP_RIVAL2=true, OPP_RIVAL3=true,
  OPP_PROF_OAK=true, OPP_CHIEF=true,
  OPP_BROCK=true, OPP_MISTY=true, OPP_LT_SURGE=true, OPP_ERIKA=true,
  OPP_KOGA=true, OPP_SABRINA=true, OPP_BLAINE=true, OPP_GIOVANNI=true,
  OPP_LORELEI=true, OPP_BRUNO=true, OPP_AGATHA=true, OPP_LANCE=true,
  OPP_ROCKET=true,
}

local trainerOverrides = {}

local function truth(v) return v ~= nil and v ~= false and v ~= 0 end

function TrainerBeacon.badgeTier(save)
  local inv = save and save.inventory or {}
  local count = 0
  for _, id in ipairs(TrainerBeacon.BADGES) do if truth(inv[id]) then count = count + 1 end end
  if count <= 1 then return 1, count end
  if count <= 3 then return 2, count end
  if count <= 5 then return 3, count end
  return 4, count
end

function TrainerBeacon.levelBoost(save)
  local tier = TrainerBeacon.badgeTier(save)
  return ({ 5, 10, 15, 20 })[tier] or 5, tier
end

function TrainerBeacon.cooldownSteps(mod)
  local n = tonumber(mod and mod.options and mod.options:get(TrainerBeacon.COOLDOWN_OPTION))
  if n and n >= 0 and n <= 10000 then return math.floor(n) end
  return TrainerBeacon.DEFAULT_COOLDOWN
end

function TrainerBeacon.trainerKey(mapId, index, classId, partyIndex)
  return table.concat({ tostring(mapId or "?"), tostring(index or "?"),
    tostring(classId or "?"), tostring(partyIndex or "?") }, ":")
end

function TrainerBeacon.setTrainerEligibility(mapId, index, allowed)
  local key = tostring(mapId or "?") .. ":" .. tostring(index or "?")
  trainerOverrides[key] = allowed and true or false
end

function TrainerBeacon.classEligible(classId, mapId, index)
  local target = trainerOverrides[tostring(mapId or "?") .. ":" .. tostring(index or "?")]
  if target ~= nil then return target end
  return type(classId) == "string" and classId ~= ""
    and TrainerBeacon.EXCLUDED_CLASSES[classId] ~= true
end

-- Follow only ordinary LEVEL rows. This is intentionally different from the
-- Rocket operatives' hand-authored tiers: Beacon teams preserve the original
-- trainer's species composition and evolve it from the boosted level.
function TrainerBeacon.evolveForLevel(data, species, level)
  local current, seen = species, {}
  for _ = 1, 8 do
    if seen[current] then break end
    seen[current] = true
    local def = data and data.pokemon and data.pokemon[current]
    local nextSpecies
    for _, evo in ipairs(def and def.evolutions or {}) do
      if evo.method == "LEVEL" and tonumber(evo.level or 0) <= level
          and data.pokemon[evo.species] then
        nextSpecies = evo.species
        break
      end
    end
    if not nextSpecies then break end
    current = nextSpecies
  end
  return current
end

function TrainerBeacon.scaleParty(data, party, boost)
  local out = {}
  boost = tonumber(boost) or 0
  for i, src in ipairs(party or {}) do
    local row = {}
    for k, v in pairs(src) do row[k] = v end
    row.level = math.max(1, math.min(100, math.floor((tonumber(src.level) or 1) + boost)))
    row.species = TrainerBeacon.evolveForLevel(data, src.species, row.level)
    out[i] = row
  end
  return out
end

function TrainerBeacon.strongestName(data, party)
  local best
  for _, row in ipairs(party or {}) do
    if not best or (tonumber(row.level) or 0) > (tonumber(best.level) or 0) then best = row end
  end
  if not best then return "POKEMON" end
  local def = data and data.pokemon and data.pokemon[best.species]
  return (def and def.name) or best.species or "POKEMON"
end

local function freshState()
  return { version = 1, clock = 0, trainers = {} }
end

local function normalizedState(runtime)
  local state = runtime:getReusableState(TrainerBeacon.STATE_KEY, nil)
  if type(state) ~= "table" or tonumber(state.version) ~= 1 then state = freshState() end
  state.clock = math.max(0, math.floor(tonumber(state.clock) or 0))
  if type(state.trainers) ~= "table" then state.trainers = {} end
  return state
end

function TrainerBeacon.remainingCooldown(state, key)
  local row = state and state.trainers and state.trainers[key]
  if type(row) ~= "table" then return 0 end
  return math.max(0, math.floor((tonumber(row.readyAt) or 0) - (tonumber(state.clock) or 0)))
end

local function facingTrainer(ctx)
  local ow = ctx and ctx.overworld
  local p = ow and ow.player
  local map = ow and ow.map
  if not (p and map) then return nil, "No trainer is in range." end
  local tx, ty
  if type(p.facingCell) == "function" then tx, ty = p:facingCell()
  else
    tx, ty = p.cellX, p.cellY
    local d = p.facing
    if d == "up" then ty = ty - 1 elseif d == "down" then ty = ty + 1
    elseif d == "left" then tx = tx - 1 elseif d == "right" then tx = tx + 1 end
  end
  for _, npc in ipairs(ow.npcs or {}) do
    local def = npc.def or {}
    if npc.cellX == tx and npc.cellY == ty and def.trainerClass and def.trainerParty then
      local label = map.def and map.def.label
      local header = label and ctx.data and type(ctx.data.trainerHeader) == "function"
        and ctx.data:trainerHeader(label, def.index) or nil
      return {
        npc = npc, def = def, mapId = map.id, index = def.index,
        classId = def.trainerClass, partyIndex = def.trainerParty,
        defeatFlag = header and header.event or nil,
      }
    end
  end
  return nil, "Face a defeated trainer\nand use the BEACON."
end

function TrainerBeacon.install(mod, runtime, Dialogue)
  local pending = nil

  local function persist(state) runtime:setReusableState(TrainerBeacon.STATE_KEY, state) end

  mod.events:on("world.stepped", function()
    local state = normalizedState(runtime)
    state.clock = state.clock + 1
    persist(state)
  end)

  mod.hooks:wrap("trainer.party", function(next, classId, partyIndex, party)
    local base = next(classId, partyIndex, party)
    if not (pending and pending.starting and classId == pending.classId
        and tonumber(partyIndex) == tonumber(pending.partyIndex)) then return base end
    pending.injected = true
    local source = type(base) == "table" and base or party
    local scaled = TrainerBeacon.scaleParty(pending.data, source, pending.boost)
    pending.actualParty = scaled
    return scaled
  end)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not (pending and pending.injected and battle) then return end
    pending.battle = battle
    battle._dscreteTrainerBeacon = true
    if type(battle.trainer) == "table" then
      local copy = {}
      for k, v in pairs(battle.trainer) do copy[k] = v end
      copy.baseMoney = math.max(0, math.floor((tonumber(copy.baseMoney) or 0)
        * TrainerBeacon.MONEY_FACTOR))
      battle.trainer = copy
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if pending and battle and (battle == pending.battle or battle._dscreteTrainerBeacon) then
      pending = nil
    end
  end)

  -- Consume through the normal bag transaction, then wait until the BagMenu
  -- and its message close before presenting trainer dialogue and starting the
  -- rematch. This avoids stacking a battle underneath the bag.
  mod.content.item_effects:register(TrainerBeacon.ITEM_EFFECT_ID, {
    needsTarget = false, field = true, battle = false,
    use = function(ctx)
      local target, err = facingTrainer(ctx)
      if not target then return "failed", { err } end
      if not TrainerBeacon.classEligible(target.classId, target.mapId, target.index) then
        return "failed", { "The BEACON refuses\nthat trainer signal." }
      end
      if not target.defeatFlag or not truth(ctx.save and ctx.save.flags and ctx.save.flags[target.defeatFlag]) then
        return "failed", { "That trainer has not\nbeen defeated yet." }
      end
      local trainer = ctx.data and ctx.data.trainers and ctx.data.trainers[target.classId]
      local original = trainer and trainer.parties and trainer.parties[target.partyIndex]
      if type(original) ~= "table" or #original == 0 then
        return "failed", { "The BEACON cannot read\nthat trainer's team." }
      end
      if pending then return "failed", { "The BEACON is already\ntracking a rematch." } end

      local state = normalizedState(runtime)
      local key = TrainerBeacon.trainerKey(target.mapId, target.index,
        target.classId, target.partyIndex)
      local remaining = TrainerBeacon.remainingCooldown(state, key)
      if remaining > 0 then
        return "failed", { ("That trainer's signal\nneeds %d more steps."):format(remaining) }
      end

      local boost, tier = TrainerBeacon.levelBoost(ctx.save)
      local preview = TrainerBeacon.scaleParty(ctx.data, original, boost)
      local record = state.trainers[key] or { rematches = 0 }
      local phase = (tonumber(record.rematches) or 0) == 0 and "first" or "later"
      local strongest = TrainerBeacon.strongestName(ctx.data, preview)
      local dialogue = Dialogue.pick(target.classId, phase, {
        STRONGEST = strongest,
        CLASS = (trainer and trainer.name) or target.classId,
      })

      record.rematches = (tonumber(record.rematches) or 0) + 1
      record.readyAt = state.clock + TrainerBeacon.cooldownSteps(mod)
      record.lastTier = tier
      state.trainers[key] = record
      persist(state)

      pending = {
        mapId = target.mapId, trainerKey = key, classId = target.classId,
        partyIndex = target.partyIndex, data = ctx.data, boost = boost,
        previewParty = preview, dialogue = dialogue, starting = false,
      }
      return "consumed", { "The TRAINER BEACON\nlocked onto a signal." }, { useJingle = true }
    end,
  })

  mod.hooks:wrap("input.step", function(next, game, dt)
    local result = next(game, dt)
    if not pending or pending.starting then return result end
    local _, busy = mod.world:availableFieldActions()
    if busy ~= nil then return result end
    pending.starting = true
    local snapshot = pending
    game.stack:push(mod.ui.TextBox.new(game, snapshot.dialogue, function()
      if pending ~= snapshot then return end
      local ok, qerr = mod.world:queueScript({
        { "start_battle", "trainer", snapshot.classId, snapshot.partyIndex },
      })
      if not ok then
        pending = nil
        game.stack:push(mod.ui.TextBox.new(game,
          "The BEACON signal\ncollapsed.\f" .. tostring(qerr or "Battle unavailable.")))
      end
    end))
    return result
  end)

  TrainerBeacon.state = function() return normalizedState(runtime) end
  TrainerBeacon.pending = function() return pending end
  TrainerBeacon.findFacingTrainer = facingTrainer
  return TrainerBeacon
end

return TrainerBeacon
