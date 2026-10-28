-- Shared conservative travel guards for DScrete travel tools.

local TravelSafety = {}

local LINK_MARKERS = {
  "TRADE_CENTER", "COLOSSEUM", "UNION_ROOM", "RECORD_CORNER",
  "TIME_CAPSULE", "CABLE_CLUB",
}

function TravelSafety.isSafari(mapId, save)
  if save and save.safari then return true end
  return type(mapId) == "string"
    and mapId:find("SAFARI_ZONE", 1, true) ~= nil
end

function TravelSafety.isLinkRoom(mapId)
  if type(mapId) ~= "string" then return false end
  for _, marker in ipairs(LINK_MARKERS) do
    if mapId:find(marker, 1, true) then return true end
  end
  return false
end

function TravelSafety.mapBlocked(mapId, save)
  if TravelSafety.isSafari(mapId, save) then return true, "safari" end
  if TravelSafety.isLinkRoom(mapId) then return true, "link" end
  return false
end

-- availableFieldActions() is the public Mod API readiness gate. It rejects
-- transitions, scripts, forced movement, trainer engagement and other world
-- busy states without DScrete inspecting private overworld fields.
function TravelSafety.fieldReady(world)
  if not (world and type(world.availableFieldActions) == "function") then
    return false, "no world"
  end
  local _, reason = world:availableFieldActions()
  if reason ~= nil then return false, reason end
  return true
end

return TravelSafety
