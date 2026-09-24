-- Mutation Capsule: choose a party Pokemon, roll exactly one primary Gen-1 DV
-- to a different value, preview the result, then accept or cancel. Previewed
-- offers persist by Pokemon/DV signature so cancelling and reopening the bag
-- cannot be used as a free reroll button.

local MutationCapsule = {}

MutationCapsule.ITEM_ID = "DS_MUTATION_CAPSULE"
MutationCapsule.ITEM_EFFECT_ID = "DS_MUTATION_CAPSULE_EFFECT"
MutationCapsule.STATE_KEY = "mutation_capsule"
MutationCapsule.STATE_VERSION = 1
MutationCapsule.MAX_OFFERS = 16

local function helpers(explicit)
  return explicit or MutationCapsule.DvTools
end

local function freshState()
  return { version=MutationCapsule.STATE_VERSION, offers={}, order={} }
end

local function loadState(runtime)
  local state = runtime and runtime:getReusableState(MutationCapsule.STATE_KEY, nil)
  if type(state) ~= "table" or state.version ~= MutationCapsule.STATE_VERSION
      or type(state.offers) ~= "table" or type(state.order) ~= "table" then
    state = freshState()
  end
  return state
end

local function validOffer(offer, DvTools)
  if type(offer) ~= "table" or type(offer.stat) ~= "string" then return false end
  local known = false
  for _, key in ipairs(DvTools.PRIMARY or {}) do if offer.stat == key then known = true break end end
  local value = tonumber(offer.value)
  return known and value and value >= 0 and value <= 15 and value % 1 == 0
end

-- Uniformly choose one of the four stored primary DVs, then uniformly choose
-- one of the other 15 possible values for it.
function MutationCapsule.rollOffer(mon, rng, explicitTools)
  local DvTools = helpers(explicitTools)
  if not (DvTools and type(mon) == "table" and type(mon.dvs) == "table"
      and type(rng) == "function") then return nil end
  local before = DvTools.copy(mon.dvs)
  local stat = DvTools.PRIMARY[rng(1, #DvTools.PRIMARY)]
  if not stat then return nil end
  local old = before[stat]
  local pick = rng(0, 14)
  local value = pick >= old and pick + 1 or pick
  return { stat=stat, value=value }
end

function MutationCapsule.offerFor(runtime, mon, rng, explicitTools)
  local DvTools = helpers(explicitTools)
  local signature = DvTools and DvTools.signature(mon)
  if not signature then return nil end
  local state = loadState(runtime)
  local existing = state.offers[signature]
  if validOffer(existing, DvTools) and existing.value ~= DvTools.copy(mon.dvs)[existing.stat] then
    return existing, signature
  end

  local offer = MutationCapsule.rollOffer(mon, rng, DvTools)
  if not offer then return nil end
  state.offers[signature] = offer
  state.order[#state.order + 1] = signature
  while #state.order > MutationCapsule.MAX_OFFERS do
    local old = table.remove(state.order, 1)
    if old ~= signature then state.offers[old] = nil end
  end
  runtime:setReusableState(MutationCapsule.STATE_KEY, state)
  return offer, signature
end

function MutationCapsule.storedOffer(runtime, mon, explicitTools)
  local DvTools = helpers(explicitTools)
  local signature = DvTools and DvTools.signature(mon)
  if not signature then return nil end
  local state = loadState(runtime)
  local offer = state.offers[signature]
  if not validOffer(offer, DvTools) then return nil end
  return offer, signature
end

function MutationCapsule.clearOffer(runtime, signature)
  if not runtime or type(signature) ~= "string" then return end
  local state = loadState(runtime)
  state.offers[signature] = nil
  for i = #state.order, 1, -1 do
    if state.order[i] == signature then table.remove(state.order, i) end
  end
  runtime:setReusableState(MutationCapsule.STATE_KEY, state)
end

function MutationCapsule.plan(mon, offer, isShiny, explicitTools)
  local DvTools = helpers(explicitTools)
  if not (DvTools and type(mon) == "table" and type(mon.dvs) == "table"
      and validOffer(offer, DvTools) and type(isShiny) == "function") then return nil end
  local before = DvTools.copy(mon.dvs)
  if before[offer.stat] == offer.value then return nil end
  local after = DvTools.copy(before)
  after[offer.stat] = offer.value
  after.hp = DvTools.hpDV(after)
  return {
    stat=offer.stat,
    before=before,
    after=after,
    shinyBefore=isShiny(before) == true,
    shinyAfter=isShiny(after) == true,
  }
end

local function yn(value) return value and "YES" or "NO" end

function MutationCapsule.previewText(name, plan, explicitTools)
  local DvTools = helpers(explicitTools)
  local label = (DvTools.LABEL and DvTools.LABEL[plan.stat]) or plan.stat:upper()
  return ("MUTATION: %s\f%s DV %d>%d\nHP DV %d>%d\fSHINY %s>%s\nResult is locked.")
    :format(tostring(name or "POKEMON"), label,
      plan.before[plan.stat], plan.after[plan.stat],
      plan.before.hp, plan.after.hp,
      yn(plan.shinyBefore), yn(plan.shinyAfter))
end

function MutationCapsule.install(mod, runtime, DvTools)
  MutationCapsule.DvTools = DvTools
  local Stats = require("src.pokemon.Stats")
  local rng = function(lo, hi) return love.math.random(lo, hi) end
  local selected = nil

  mod.hooks:wrap("item.use", function(next, game, battle, id, itemTarget, list, moveIndex, picker)
    if id ~= MutationCapsule.ITEM_ID or battle then
      return next(game, battle, id, itemTarget, list, moveIndex, picker)
    end

    local rows = {}
    for slot, mon in ipairs(game and game.save and game.save.party or {}) do
      if DvTools.signature(mon) and game.data and game.data.pokemon and game.data.pokemon[mon.species] then
        local def = game.data.pokemon[mon.species] or {}
        rows[#rows + 1] = {
          label=mon.nickname or def.name or mon.species or ("POKEMON " .. slot),
          value={slot=slot,mon=mon,name=mon.nickname or def.name or mon.species},
        }
      end
    end
    if #rows == 0 then
      game.stack:push(mod.ui.TextBox.new(game, "No party POKEMON can\nuse the capsule."))
      return nil
    end
    rows[#rows + 1] = { label="CANCEL", value=false }

    local targetMenu
    targetMenu = mod.ui.ListMenu.new(game, "MUTATE CAP.", rows, {
      pageJump=true,
      onChoose=function(choice)
        if not choice or choice.value == false then
          if targetMenu then targetMenu:close() end
          return
        end
        local row = choice.value
        if targetMenu then targetMenu:close() end

        local offer, signature = MutationCapsule.offerFor(runtime, row.mon, rng, DvTools)
        local plan = offer and MutationCapsule.plan(row.mon, offer, Stats.isShiny, DvTools)
        if not plan then
          game.stack:push(mod.ui.TextBox.new(game, "The mutation scan\nfailed."))
          return
        end

        game.stack:push(mod.ui.TextBox.new(game,
          MutationCapsule.previewText(row.name, plan, DvTools), function()
            local confirm
            local function closeConfirm()
              if confirm and type(confirm.close) == "function" then confirm:close() end
            end
            confirm = mod.ui.Menu.new(game, {
              { label="MUTATE", onSelect=function()
                  closeConfirm()
                  selected = {
                    mon=row.mon,
                    signature=signature,
                    stat=offer.stat,
                    value=offer.value,
                  }
                  next(game, battle, id, row.mon, list, moveIndex, picker)
                end },
              { label="KEEP OLD", onSelect=closeConfirm },
            }, {
              tx=8, ty=4, tw=12, maxVisible=2, noWrap=true,
              title="APPLY?", anchor="topright", onCancel=closeConfirm,
            })
            game.stack:push(confirm)
          end))
      end,
      onCancel=function()
        if targetMenu then targetMenu:close() end
      end,
    })
    game.stack:push(targetMenu)
    return nil
  end)

  mod.content.item_effects:register(MutationCapsule.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function(ctx)
      local pick = selected
      selected = nil
      if not pick or not ctx.target or pick.mon ~= ctx.target
          or pick.signature ~= DvTools.signature(ctx.target) then
        return "failed", { "The mutation sample\nno longer matches." }
      end
      local stored, signature = MutationCapsule.storedOffer(runtime, ctx.target, DvTools)
      if not stored or signature ~= pick.signature
          or stored.stat ~= pick.stat or stored.value ~= pick.value then
        return "failed", { "The stored mutation\nresult was lost." }
      end
      local plan = MutationCapsule.plan(ctx.target, stored, Stats.isShiny, DvTools)
      if not plan or not DvTools.apply(ctx.data, ctx.target, plan.after, Stats) then
        return "failed", { "The MUTATE CAP.\nhad no effect." }
      end
      MutationCapsule.clearOffer(runtime, signature)
      local label = (DvTools.LABEL and DvTools.LABEL[plan.stat]) or plan.stat:upper()
      return "consumed", {
        ("Mutation complete!\f%s DV is now %d.\fSHINY: %s")
          :format(label, plan.after[plan.stat], yn(plan.shinyAfter))
      }, { useJingle=true }
    end,
  })

  MutationCapsule.selected = function() return selected end
  return MutationCapsule
end

return MutationCapsule
