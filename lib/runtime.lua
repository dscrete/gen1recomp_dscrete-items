-- Shared DScrete runtime and persistence rules.
-- Pure Lua: this module intentionally has no engine dependency, so its state
-- machine can be tested without a Gen1Recomp checkout.

local Runtime = {}
Runtime.__index = Runtime

Runtime.SCHEMA_VERSION = 3
Runtime.RESULT = {
  APPLIED = "applied", CANCELLED = "cancelled", INVALID = "invalid",
  CONFLICT = "conflict", FAILED = "failed",
}

local FIELD_ID_KEY = "active_field_effect"
local FIELD_STEPS_KEY = "active_field_steps"
local LEGACY_EFFECT_IDS = { shiny_finder = "prism_scent" }

local function positiveInteger(value)
  return type(value) == "number" and value > 0 and value % 1 == 0
end

function Runtime.new(save)
  assert(save and type(save.get) == "function" and type(save.set) == "function",
    "DScrete runtime needs a mod.save-like get/set store")
  local self = setmetatable({ save = save }, Runtime)
  local version = tonumber(save:get("schema_version", 0)) or 0
  if version < Runtime.SCHEMA_VERSION then save:set("schema_version", Runtime.SCHEMA_VERSION) end
  self:reloadPersistentState()
  return self
end

function Runtime:_persistFieldEffect()
  if self.activeFieldEffect and positiveInteger(self.remainingSteps) then
    self.save:set(FIELD_ID_KEY, self.activeFieldEffect)
    self.save:set(FIELD_STEPS_KEY, self.remainingSteps)
  else
    self.save:set(FIELD_ID_KEY, nil)
    self.save:set(FIELD_STEPS_KEY, nil)
  end
end

function Runtime:_resetTransient()
  self.selectedSpecies = nil
  self.pendingExpMultiplier = nil
  self.pendingNaturalEncounter = false
  self.pendingExpirationNotice = nil
  self.pendingFieldReplacement = nil
  self.debugReturn = nil
  self.debugRolls = 0
  self.debugSuccesses = 0
end

function Runtime:reloadPersistentState()
  self:_resetTransient()
  local effect = self.save:get(FIELD_ID_KEY, nil)
  effect = LEGACY_EFFECT_IDS[effect] or effect
  local steps = tonumber(self.save:get(FIELD_STEPS_KEY, 0)) or 0
  if type(effect) == "string" and effect ~= "" and positiveInteger(steps) then
    self.activeFieldEffect = effect
    self.remainingSteps = steps
    self:_persistFieldEffect()
  else
    self.activeFieldEffect = nil
    self.remainingSteps = 0
    self:_persistFieldEffect()
  end
end

function Runtime:resetRuntime()
  local effect, steps = self.activeFieldEffect, self.remainingSteps
  self:_resetTransient()
  self.activeFieldEffect, self.remainingSteps = effect, steps
end

function Runtime:activateFieldEffect(effectId, duration, replace)
  if type(effectId) ~= "string" or effectId == "" or not positiveInteger(duration) then
    return false, Runtime.RESULT.INVALID
  end
  local current = self.activeFieldEffect
  if current and current ~= effectId and not replace then
    return false, Runtime.RESULT.CONFLICT, current
  end
  self.activeFieldEffect = effectId
  self.remainingSteps = duration
  self.selectedSpecies = nil
  self.pendingFieldReplacement = nil
  self:_persistFieldEffect()
  return true, Runtime.RESULT.APPLIED, current
end

function Runtime:clearFieldEffect()
  local old = self.activeFieldEffect
  self.activeFieldEffect = nil
  self.remainingSteps = 0
  self.selectedSpecies = nil
  self.pendingFieldReplacement = nil
  self:_persistFieldEffect()
  return old
end

function Runtime:onEligibleStep()
  self.pendingFieldReplacement = nil
  if not self.activeFieldEffect then return nil end
  if self.remainingSteps <= 0 then return self:clearFieldEffect() end
  self.remainingSteps = self.remainingSteps - 1
  if self.remainingSteps <= 0 then return self:clearFieldEffect() end
  self:_persistFieldEffect()
  return nil
end

function Runtime:isActive(effectId)
  return self.activeFieldEffect == effectId and self.remainingSteps > 0
end

function Runtime:requestFieldReplacement(newEffect)
  local current = self.activeFieldEffect
  if not current or current == newEffect then return false end
  local pending = self.pendingFieldReplacement
  if pending and pending.newEffect == newEffect and pending.oldEffect == current then
    self.pendingFieldReplacement = nil
    return true
  end
  self.pendingFieldReplacement = { newEffect = newEffect, oldEffect = current }
  return false
end

function Runtime:unlock(key)
  assert(type(key) == "string" and key ~= "", "unlock key required")
  self.save:set("unlock_" .. key, true)
end
function Runtime:isUnlocked(key) return self.save:get("unlock_" .. key, false) == true end
function Runtime:lock(key) self.save:set("unlock_" .. key, false) end
function Runtime:setReusableState(key, value) self.save:set("reusable_" .. key, value) end
function Runtime:getReusableState(key, default) return self.save:get("reusable_" .. key, default) end

function Runtime:resetPersistent(itemKeys)
  self.save:set("schema_version", Runtime.SCHEMA_VERSION)
  for _, key in ipairs(itemKeys or {}) do
    self.save:set("unlock_" .. key, false)
    self.save:set("reusable_" .. key, nil)
  end
  self.save:set("placed_beacon_map", nil)
  self.save:set("placed_beacon_x", nil)
  self.save:set("placed_beacon_y", nil)
  self.activeFieldEffect, self.remainingSteps = nil, 0
  self:_persistFieldEffect()
  self:_resetTransient()
end

function Runtime:snapshot(itemKeys)
  local unlocked = {}
  for _, key in ipairs(itemKeys or {}) do if self:isUnlocked(key) then unlocked[#unlocked+1] = key end end
  return {
    schemaVersion = self.save:get("schema_version", Runtime.SCHEMA_VERSION),
    unlocked = unlocked,
    activeFieldEffect = self.activeFieldEffect,
    remainingSteps = self.remainingSteps,
    selectedSpecies = self.selectedSpecies,
    pendingExpMultiplier = self.pendingExpMultiplier,
    pendingNaturalEncounter = self.pendingNaturalEncounter,
    debugRolls = self.debugRolls,
    debugSuccesses = self.debugSuccesses,
  }
end

return Runtime
