local SilphTracker = dofile("lib/silph_tracker.lua")

test("Silph Tracker module loads with dedicated-screen implementation", function()
  eq(SilphTracker.KEY, "silph_tracker")
  check(type(SilphTracker.install) == "function")
end)
