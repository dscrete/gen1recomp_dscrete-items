-- Prototype Ball: an experimental Poké Ball whose capture power rises sharply
-- as the target is weakened.
--
-- The ball deliberately has a poor high-HP baseline: above half HP it halves
-- the target's effective species catch rate before Gen1Recomp runs the stock
-- Gen-1 HP/status calculation.  Its payoff arrives at low HP, where it becomes
-- stronger than an Ultra Ball while still stacking with the engine's ordinary
-- status catch bonus.

local PrototypeBall = {}

PrototypeBall.ITEM_ID = "DS_PROTOTYPE_BALL"
PrototypeBall.ITEM_EFFECT_ID = "DS_PROTOTYPE_BALL_EFFECT"
PrototypeBall.MAX_CATCH_RATE = 255

-- Authored HP bands.  Keeping these discrete makes the gimmick readable and
-- deterministic rather than hiding a smooth modern-style scaling formula.
PrototypeBall.HP_BANDS = {
  { maxRatio = 0.10, multiplier = 3.0, label = "CRITICAL" },
  { maxRatio = 0.25, multiplier = 2.0, label = "LOW" },
  { maxRatio = 0.50, multiplier = 1.0, label = "MID" },
  { maxRatio = 1.00, multiplier = 0.5, label = "HIGH" },
}

function PrototypeBall.hpRatio(mon)
  if type(mon) ~= "table" then return 1 end
  local hp = tonumber(mon.hp)
  local maxHp = tonumber(mon.stats and mon.stats.hp)
  if not hp or not maxHp or maxHp <= 0 then return 1 end
  return math.max(0, math.min(1, hp / maxHp))
end

function PrototypeBall.healthMultiplier(mon)
  local ratio = PrototypeBall.hpRatio(mon)
  for _, band in ipairs(PrototypeBall.HP_BANDS) do
    if ratio <= band.maxRatio then
      return band.multiplier, band.label, ratio
    end
  end
  return 0.5, "HIGH", ratio
end

function PrototypeBall.effectiveCatchRate(mon, speciesDef, rateOverride)
  local base = tonumber(rateOverride)
  if base == nil then base = tonumber(speciesDef and speciesDef.catchRate) or 0 end
  base = math.max(0, math.floor(base))

  local multiplier, band, ratio = PrototypeBall.healthMultiplier(mon)
  local rate = math.floor(base * multiplier)
  if base > 0 then rate = math.max(1, rate) end
  rate = math.min(PrototypeBall.MAX_CATCH_RATE, rate)
  return rate, multiplier, band, ratio
end

function PrototypeBall.install(mod)
  mod.content.balls:register(PrototypeBall.ITEM_ID, {
    -- Poké Ball factors remain the mechanical baseline.  The gimmick rewrites
    -- only the effective species catch-rate input; stock HP and status bonuses
    -- still run afterward, so status stacks naturally with the HP-based bonus.
    randMax = 255,
    hpFactor = 12,
    wobbleFactor = 255,
    tossAnim = "TOSS_ANIM",
    attempt = function(ctx)
      local rate = PrototypeBall.effectiveCatchRate(
        ctx.targetMon, ctx.targetDef, ctx.rateOverride)
      ctx.rateOverride = rate
      return ctx.vanillaAttempt()
    end,
  })

  mod.content.item_effects:register(PrototypeBall.ITEM_EFFECT_ID, {
    needsTarget = false,
    field = false,
    battle = true,
    use = function()
      -- BagMenu owns consumption + throw animation for the standard "ball"
      -- result, so this remains transactional and follows trainer/link refusal.
      return "ball"
    end,
  })

  return PrototypeBall
end

return PrototypeBall
