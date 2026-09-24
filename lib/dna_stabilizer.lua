-- DNA Stabilizer: permanently improves a party Pokemon's Gen-1 DVs while
-- preserving an existing shiny DV pattern. Non-shiny Pokemon gain +1 in each
-- primary DV (cap 15). Existing shinies keep DEF/SPD/SPC at 10 and advance
-- Attack to the next higher shiny-compatible value, if one exists.

local DNAStabilizer = {}

DNAStabilizer.ITEM_ID = "DS_DNA_STABILIZER"
DNAStabilizer.ITEM_EFFECT_ID = "DS_DNA_STABILIZER_EFFECT"

local function helpers(explicit)
  return explicit or DNAStabilizer.DvTools
end

function DNAStabilizer.plan(mon, isShiny, explicitTools)
  local DvTools = helpers(explicitTools)
  if not (DvTools and type(mon) == "table" and type(mon.dvs) == "table"
      and type(isShiny) == "function") then return nil end

  local before = DvTools.copy(mon.dvs)
  if not before then return nil end
  local after = DvTools.copy(before)
  local shinyBefore = isShiny(before) == true

  if shinyBefore then
    -- Never alter the three fixed shiny DVs. Attack can still improve, but
    -- only by moving to the next value accepted by the engine's shiny rule.
    local nextAttack
    for _, value in ipairs(DvTools.SHINY_ATTACK or {}) do
      if value > before.attack then nextAttack = value break end
    end
    if nextAttack then after.attack = nextAttack end
  else
    for _, key in ipairs(DvTools.PRIMARY or {}) do
      after[key] = math.min(15, (before[key] or 0) + 1)
    end
  end
  after.hp = DvTools.hpDV(after)

  if DvTools.equal(before, after) then return nil end
  local shinyAfter = isShiny(after) == true
  -- This is the hard safety invariant: a Stabilizer can never destroy an
  -- existing shiny, even if the engine changes its shiny predicate later.
  if shinyBefore and not shinyAfter then return nil end

  return {
    before = before,
    after = after,
    shinyBefore = shinyBefore,
    shinyAfter = shinyAfter,
  }
end

function DNAStabilizer.eligibleParty(game, isShiny, explicitTools)
  local rows = {}
  for slot, mon in ipairs(game and game.save and game.save.party or {}) do
    local plan = DNAStabilizer.plan(mon, isShiny, explicitTools)
    if plan then
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species] or {}
      rows[#rows + 1] = {
        slot = slot,
        mon = mon,
        name = mon.nickname or def.name or mon.species or ("POKEMON " .. slot),
        plan = plan,
      }
    end
  end
  return rows
end

local function yn(value) return value and "YES" or "NO" end

function DNAStabilizer.previewText(name, plan)
  local b, a = plan.before, plan.after
  return ("DNA PREVIEW: %s\fATK %d>%d  DEF %d>%d\nSPD %d>%d  SPC %d>%d\fHP DV %d>%d\nSHINY %s>%s")
    :format(tostring(name or "POKEMON"),
      b.attack, a.attack, b.defense, a.defense,
      b.speed, a.speed, b.special, a.special,
      b.hp, a.hp, yn(plan.shinyBefore), yn(plan.shinyAfter))
end

function DNAStabilizer.install(mod, DvTools)
  DNAStabilizer.DvTools = DvTools
  local Stats = require("src.pokemon.Stats")
  local selected = nil

  mod.hooks:wrap("item.use", function(next, game, battle, id, itemTarget, list, moveIndex, picker)
    if id ~= DNAStabilizer.ITEM_ID or battle then
      return next(game, battle, id, itemTarget, list, moveIndex, picker)
    end

    local eligible = DNAStabilizer.eligibleParty(game, Stats.isShiny, DvTools)
    if #eligible == 0 then
      game.stack:push(mod.ui.TextBox.new(game,
        "No party POKEMON can\nbe stabilized further."))
      return nil
    end

    local rows = {}
    for _, row in ipairs(eligible) do rows[#rows + 1] = { label=row.name, value=row } end
    rows[#rows + 1] = { label="CANCEL", value=false }

    local targetMenu
    targetMenu = mod.ui.ListMenu.new(game, "DNA STABILIZER", rows, {
      pageJump = true,
      onChoose = function(choice)
        if not choice or choice.value == false then
          if targetMenu then targetMenu:close() end
          return
        end
        local row = choice.value
        if targetMenu then targetMenu:close() end

        local fresh = DNAStabilizer.plan(row.mon, Stats.isShiny, DvTools)
        if not fresh then
          game.stack:push(mod.ui.TextBox.new(game,
            "That POKEMON cannot\nbe stabilized now."))
          return
        end

        game.stack:push(mod.ui.TextBox.new(game,
          DNAStabilizer.previewText(row.name, fresh), function()
            local confirm
            local function closeConfirm()
              if confirm and type(confirm.close) == "function" then confirm:close() end
            end
            confirm = mod.ui.Menu.new(game, {
              { label="STABILIZE", onSelect=function()
                  closeConfirm()
                  selected = {
                    mon = row.mon,
                    signature = DvTools.signature(row.mon),
                  }
                  next(game, battle, id, row.mon, list, moveIndex, picker)
                end },
              { label="CANCEL", onSelect=closeConfirm },
            }, {
              tx=8, ty=4, tw=12, maxVisible=2, noWrap=true,
              title="APPLY?", anchor="topright", onCancel=closeConfirm,
            })
            game.stack:push(confirm)
          end))
      end,
      onCancel = function()
        if targetMenu then targetMenu:close() end
      end,
    })
    game.stack:push(targetMenu)
    return nil
  end)

  mod.content.item_effects:register(DNAStabilizer.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function(ctx)
      local pick = selected
      selected = nil
      if not pick or not ctx.target or pick.mon ~= ctx.target
          or pick.signature ~= DvTools.signature(ctx.target) then
        return "failed", { "The DNA sample\nchanged before use." }
      end
      local plan = DNAStabilizer.plan(ctx.target, Stats.isShiny, DvTools)
      if not plan or not DvTools.apply(ctx.data, ctx.target, plan.after, Stats) then
        return "failed", { "The DNA STABILIZER\nhad no safe effect." }
      end
      return "consumed", {
        plan.shinyAfter and "DNA stabilized!\fIts shiny pattern\nremained stable."
          or "DNA stabilized!\fIts natural DVs\nwere improved."
      }, { useJingle=true }
    end,
  })

  DNAStabilizer.selected = function() return selected end
  return DNAStabilizer
end

return DNAStabilizer
