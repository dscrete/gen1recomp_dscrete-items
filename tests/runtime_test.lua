local Runtime = dofile("lib/runtime.lua")

local function store(seed)
  local values = seed or {}
  return {
    get = function(_, key, default)
      local value = values[key]
      if value == nil then return default end
      return value
    end,
    set = function(_, key, value) values[key] = value end,
    values = values,
  }
end

test("runtime initializes a versioned persistent namespace", function()
  local s = store()
  local runtime = Runtime.new(s)
  eq(s.values.schema_version, Runtime.SCHEMA_VERSION)
  eq(runtime.activeFieldEffect, nil)
  eq(runtime.remainingSteps, 0)
end)

test("field effects require explicit replacement", function()
  local runtime = Runtime.new(store())
  local ok = runtime:activateFieldEffect("rare_lure", 10)
  check(ok)
  local accepted, reason, current = runtime:activateFieldEffect("shiny_finder", 20)
  eq(accepted, false)
  eq(reason, Runtime.RESULT.CONFLICT)
  eq(current, "rare_lure")
  eq(runtime.activeFieldEffect, "rare_lure")
  accepted, reason, current = runtime:activateFieldEffect("shiny_finder", 20, true)
  check(accepted)
  eq(reason, Runtime.RESULT.APPLIED)
  eq(current, "rare_lure")
  eq(runtime.activeFieldEffect, "shiny_finder")
  eq(runtime.remainingSteps, 20)
end)

test("replacement requires a second matching confirmation", function()
  local runtime = Runtime.new(store())
  runtime:activateFieldEffect("rare_lure", 10)
  eq(runtime:requestFieldReplacement("shiny_finder"), false)
  eq(runtime:requestFieldReplacement("shiny_finder"), true)
  runtime.pendingFieldReplacement = nil
  eq(runtime:requestFieldReplacement("mystery_lure"), false)
  runtime:onEligibleStep()
  eq(runtime:requestFieldReplacement("mystery_lure"), false,
    "walking must clear a stale replacement confirmation")
end)

test("eligible steps expire exactly once and persist countdown", function()
  local s = store()
  local runtime = Runtime.new(s)
  runtime:activateFieldEffect("shiny_finder", 3)
  eq(s.values.active_field_effect, "shiny_finder")
  eq(s.values.active_field_steps, 3)
  eq(runtime:onEligibleStep(), nil)
  eq(runtime.remainingSteps, 2)
  eq(s.values.active_field_steps, 2)
  eq(runtime:onEligibleStep(), nil)
  eq(runtime.remainingSteps, 1)
  eq(s.values.active_field_steps, 1)
  eq(runtime:onEligibleStep(), "shiny_finder")
  eq(runtime.remainingSteps, 0)
  eq(runtime.activeFieldEffect, nil)
  eq(s.values.active_field_effect, nil)
  eq(s.values.active_field_steps, nil)
  eq(runtime:onEligibleStep(), nil)
end)

test("active field effect survives runtime recreation", function()
  local s = store()
  local first = Runtime.new(s)
  first:activateFieldEffect("shiny_finder", 250)
  first:onEligibleStep()
  first:onEligibleStep()

  local restored = Runtime.new(s)
  eq(restored.activeFieldEffect, "shiny_finder")
  eq(restored.remainingSteps, 248)
  check(restored:isActive("shiny_finder"))
end)

test("runtime reset preserves persisted field effect", function()
  local s = store()
  local runtime = Runtime.new(s)
  runtime:unlock("silph_tracker")
  runtime:activateFieldEffect("shiny_finder", 10)
  runtime.pendingNaturalEncounter = { species = "PIKACHU", level = 5 }
  runtime:resetRuntime()
  check(runtime:isUnlocked("silph_tracker"))
  eq(runtime.activeFieldEffect, "shiny_finder")
  eq(runtime.remainingSteps, 10)
  eq(runtime.pendingNaturalEncounter, false)
end)

test("persistent reset clears active field effect", function()
  local s = store()
  local runtime = Runtime.new(s)
  runtime:activateFieldEffect("shiny_finder", 10)
  runtime:resetPersistent({ "silph_tracker" })
  eq(runtime.activeFieldEffect, nil)
  eq(runtime.remainingSteps, 0)
  eq(s.values.active_field_effect, nil)
  eq(s.values.active_field_steps, nil)
end)
