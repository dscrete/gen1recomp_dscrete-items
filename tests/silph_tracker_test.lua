local SilphTracker = dofile("lib/silph_tracker.lua")

test("Silph Tracker module loads with dedicated-screen implementation", function()
  eq(SilphTracker.KEY, "silph_tracker")
  check(type(SilphTracker.install) == "function")
end)

test("Silph Tracker open path does not regress to generic ListMenu", function()
  local f = assert(io.open("lib/silph_tracker.lua", "r"))
  local source = f:read("*a")
  f:close()
  check(source:find("newTrackerScreen", 1, true) ~= nil,
    "dedicated Tracker screen constructor missing")
  check(source:find("game.stack:push(newTrackerScreen", 1, true) ~= nil,
    "SilphTracker.open must push the dedicated Tracker screen")
  check(source:find("mod.ui.ListMenu.new(game,\"SILPH TRACKER\"", 1, true) == nil,
    "Silph Tracker regressed to generic ListMenu")
end)
