-- EXP Battery: consume one item to arm a persistent one-shot battle-EXP bonus.
--
-- The Battery applies to the complete EXP distribution caused by the next
-- defeated Pokémon: every ordinary EXP share produced inside that award gets
-- the same multiplier.  It does not affect Rare Candy or other non-battle
-- growth because those paths never enter battle.exp_award / exp.gain.

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
  local awardWindow = false
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

  -- Open a one-award window around vanilla's complete participant/EXP.ALL
  -- distribution.  exp.gain can fire several times inside this call; they all
  -- receive the bonus, and the persistent charge is spent only if at least one
  -- positive EXP gain actually occurred.
  mod.hooks:wrap("battle.exp_award", function(nextFn, ctx)
    if not ExpBattery.isArmed() then return nextFn(ctx) end
    awardWindow = true
    awardApplied = false
    runtime.pendingExpMultiplier = ExpBattery.armedMultiplier() or ExpBattery.MULTIPLIER

    local ok, a, b, c = pcall(nextFn, ctx)

    awardWindow = false
    runtime.pendingExpMultiplier = nil
    if not ok then error(a) end
    if awardApplied then ExpBattery.clear() end
    return a, b, c
  end)

  mod.hooks:wrap("exp.gain", function(nextFn, ctx)
    local base = nextFn(ctx)
    if not awardWindow or not ExpBattery.isArmed() then return base end
    if type(base) ~= "number" or base <= 0 then return base end
    awardApplied = true
    return ExpBattery.multiply(base,
      runtime.pendingExpMultiplier or ExpBattery.MULTIPLIER)
  end)

  return ExpBattery
end

return ExpBattery
