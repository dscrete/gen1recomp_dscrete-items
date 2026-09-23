-- EXP Battery: consume one item to arm a persistent one-shot battle-EXP bonus.
--
-- The Battery applies to the complete EXP distribution caused by the next
-- defeated Pokémon: every ordinary EXP share produced before that battle turn
-- finishes receives the same multiplier.  It does not affect Rare Candy or
-- other non-battle growth.

local ExpBattery = {}

ExpBattery.ITEM_ID = "DS_EXP_BATTERY"
ExpBattery.ITEM_EFFECT_ID = "DS_EXP_BATTERY_EFFECT"
ExpBattery.STATE_KEY = "exp_battery"
ExpBattery.MULTIPLIER = 2

function ExpBattery.multiply(amount, multiplier)
  amount = tonumber(amount) or 0
  multiplier = tonumber(multiplier) or ExpBattery.MULTIPLIER
  if amount <= 0 then return amount end
  return math.max(1, math.floor(amount * multiplier))
end

function ExpBattery.install(mod, runtime)
  local activeBattle = nil
  local awardApplied = false

  local function state()
    local value = runtime:getReusableState(ExpBattery.STATE_KEY, nil)
    if type(value) == "table" then return value end
    if value == true then return { armed=true, multiplier=ExpBattery.MULTIPLIER } end
    return nil
  end

  function ExpBattery.isArmed()
    local value = state()
    return value and value.armed == true or false
  end

  function ExpBattery.arm(multiplier)
    runtime:setReusableState(ExpBattery.STATE_KEY, {
      armed = true,
      multiplier = tonumber(multiplier) or ExpBattery.MULTIPLIER,
    })
  end

  function ExpBattery.clear()
    runtime:setReusableState(ExpBattery.STATE_KEY, nil)
  end

  function ExpBattery.armedMultiplier()
    local value = state()
    return value and tonumber(value.multiplier) or nil
  end

  mod.content.item_effects:register(ExpBattery.ITEM_EFFECT_ID, {
    needsTarget = false,
    field = true,
    battle = false,
    use = function()
      if ExpBattery.isArmed() then
        return "failed", { "The EXP BATTERY is\nalready armed." }
      end
      ExpBattery.arm(ExpBattery.MULTIPLIER)
      return "consumed", {
        "EXP BATTERY armed!\fThe next defeated\nPOKéMON will yield\ndouble battle EXP."
      }, { useJingle=true }
    end,
  })

  -- Keep this on the Mod API surfaces already present at the advertised
  -- Gen1Recomp 0.2.5 floor.  exp.gain can fire several times while one enemy
  -- payout is distributed (participants and EXP.ALL); all of those calls
  -- happen before battle.turn_ended, so one transient battle window covers
  -- the whole defeated-Pokémon award without requiring newer
  -- battle.exp_award hooks.
  mod.events:on("battle.started", function(ev)
    activeBattle = ev and ev.battle or nil
    awardApplied = false
    runtime.pendingExpMultiplier = nil
  end)

  local function finishAward(ev)
    if not activeBattle then return end
    if ev and ev.battle and ev.battle ~= activeBattle then return end
    if awardApplied then ExpBattery.clear() end
    awardApplied = false
    runtime.pendingExpMultiplier = nil
  end

  mod.events:on("battle.turn_ended", finishAward)
  mod.events:on("battle.ended", function(ev)
    finishAward(ev)
    if not ev or not ev.battle or ev.battle == activeBattle then activeBattle = nil end
  end)

  mod.hooks:wrap("exp.gain", function(nextFn, ctx)
    local base = nextFn(ctx)
    if not activeBattle or not ExpBattery.isArmed() then return base end
    if type(base) ~= "number" or base <= 0 then return base end
    runtime.pendingExpMultiplier = ExpBattery.armedMultiplier() or ExpBattery.MULTIPLIER
    awardApplied = true
    return ExpBattery.multiply(base, runtime.pendingExpMultiplier)
  end)

  return ExpBattery
end

return ExpBattery
