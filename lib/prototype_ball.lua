-- Prototype Ball: an experimental Poké Ball that rewards setting up a
-- traditional Gen-1 status condition without replacing the stock catch math.
--
-- Baseline behavior is exactly a Poké Ball.  When the target has any major
-- status condition, its effective species catch rate is doubled (capped at
-- 255) before Gen1Recomp runs the ordinary HP/status/ball calculation.

local PrototypeBall = {}

PrototypeBall.ITEM_ID = "DS_PROTOTYPE_BALL"
PrototypeBall.ITEM_EFFECT_ID = "DS_PROTOTYPE_BALL_EFFECT"
PrototypeBall.STATUS_RATE_MULTIPLIER = 2
PrototypeBall.MAX_CATCH_RATE = 255

function PrototypeBall.hasMajorStatus(mon)
  if type(mon) ~= "table" then return false end
  local status = mon.status
  return status ~= nil and status ~= false and status ~= ""
end

function PrototypeBall.effectiveCatchRate(mon, speciesDef, rateOverride)
  local base = tonumber(rateOverride)
  if base == nil then base = tonumber(speciesDef and speciesDef.catchRate) or 0 end
  base = math.max(0, math.floor(base))
  if not PrototypeBall.hasMajorStatus(mon) then return base, false end
  return math.min(PrototypeBall.MAX_CATCH_RATE,
    base * PrototypeBall.STATUS_RATE_MULTIPLIER), true
end

function PrototypeBall.install(mod)
  mod.content.balls:register(PrototypeBall.ITEM_ID, {
    -- Poké Ball baseline factors.  Only the species catch-rate input changes.
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
