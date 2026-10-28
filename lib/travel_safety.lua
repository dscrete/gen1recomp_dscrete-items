-- Shared conservative travel guards and destination validation for DScrete
-- travel tools. Everything here is data-driven against the merged Gen1 data.

local TravelSafety = {}

local LINK_MARKERS = {
  "TRADE_CENTER", "COLOSSEUM", "UNION_ROOM", "RECORD_CORNER",
  "TIME_CAPSULE", "CABLE_CLUB",
}

-- Temporary/removable story spaces and the deliberately one-way Elite Four
-- progression rooms are not valid player-defined travel anchors.
local STORY_BLOCKED_EXACT = {
  VERMILION_DOCK=true,
  LORELEIS_ROOM=true,
  BRUNOS_ROOM=true,
  AGATHAS_ROOM=true,
  LANCES_ROOM=true,
  CHAMPIONS_ROOM=true,
  HALL_OF_FAME=true,
}

local function contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

local function integer(value)
  return type(value) == "number" and value == math.floor(value)
end

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

function TravelSafety.isStoryBlocked(mapId)
  if type(mapId) ~= "string" then return true end
  if STORY_BLOCKED_EXACT[mapId] then return true end
  return mapId:find("SS_ANNE", 1, true) ~= nil
end

function TravelSafety.mapBlocked(mapId, save, opts)
  if TravelSafety.isSafari(mapId, save) then return true, "safari" end
  if TravelSafety.isLinkRoom(mapId) then return true, "link" end
  if opts and opts.blockStory and TravelSafety.isStoryBlocked(mapId) then
    return true, "story"
  end
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

local function objectVisible(save, mapId, obj)
  local toggles = save and save.objectToggles and save.objectToggles[mapId] or {}
  local visible = not obj.hidden
  if obj.name and toggles[obj.name] ~= nil then visible = toggles[obj.name] end
  if obj.item and save and save.itemsTaken
      and save.itemsTaken[mapId .. "_obj_" .. tostring(obj.index)] then
    visible = false
  end
  if obj.pokemon and save and save.defeatedTrainers
      and save.defeatedTrainers[mapId .. "_obj_" .. tostring(obj.index)] then
    visible = false
  end
  return visible
end

-- Pure merged-data version of Gen1 Map:cellTile / isWalkableCell. This lets a
-- stored Beacon be revalidated without entering the destination first.
function TravelSafety.cellInfo(data, mapId, x, y)
  if not (data and data.maps and data.tilesets) then
    return nil, "map data unavailable"
  end
  local def = data.maps[mapId]
  if not def then return nil, "map unavailable" end
  if not (integer(x) and integer(y) and type(def.width) == "number"
      and type(def.height) == "number") then
    return nil, "invalid coordinates"
  end
  if x < 0 or y < 0 or x >= def.width * 2 or y >= def.height * 2 then
    return nil, "out of bounds"
  end

  local ts = data.tilesets[def.tileset]
  if not (ts and type(ts.blocks) == "table"
      and type(ts.walkable) == "table" and type(def.blocks) == "table") then
    return nil, "collision data unavailable"
  end

  local tx, ty = x * 2, y * 2 + 1
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  local blockId = def.blocks[by * def.width + bx + 1]
  local block = type(blockId) == "number" and ts.blocks[blockId + 1] or nil
  local tile = block and block[(ty % 4) * 4 + (tx % 4) + 1] or nil
  if type(tile) ~= "number" then return nil, "collision tile unavailable" end

  return {
    def=def, tileset=ts, tile=tile,
    walkable=contains(ts.walkable, tile),
    warpTile=contains(ts.doorTiles, tile) or contains(ts.warpTiles, tile),
  }
end

local function staticMarkerAt(data, save, mapId, x, y)
  local def = data.maps[mapId]
  for _, warp in ipairs(def.warps or {}) do
    if warp.x == x and warp.y == y then return "warp" end
  end
  for _, obj in ipairs(def.objects or {}) do
    if obj.x == x and obj.y == y and objectVisible(save, mapId, obj) then
      return obj.item and "item" or "object"
    end
  end
  local hidden = data.field and data.field.hiddenItems
  for _, item in ipairs(hidden and hidden[mapId] or {}) do
    local key = mapId .. "_" .. tostring(item.x) .. "_" .. tostring(item.y)
    if item.x == x and item.y == y
        and not (save and save.hiddenTaken and save.hiddenTaken[key]) then
      return "hidden"
    end
  end
end

local function overviewMarkerAt(world, mapId, x, y)
  if not (world and type(world.mapOverview) == "function") then return nil end
  local overview = world:mapOverview()
  if not overview or overview.mapId ~= mapId then return nil end
  for _, marker in ipairs(overview.markers or {}) do
    if marker.x == x and marker.y == y then return marker.kind or "event" end
  end
end

-- Validate a Map Beacon cell both when recording and immediately before
-- returning. For an inactive map we can prove static collision/objects from
-- merged data. If the destination map is already active, also reject a live
-- NPC currently occupying or moving into that cell.
function TravelSafety.validateBeaconCell(game, world, mapId, x, y)
  local save = game and game.save
  local blocked, reason = TravelSafety.mapBlocked(mapId, save, {blockStory=true})
  if blocked then return false, reason end

  local info, err = TravelSafety.cellInfo(game and game.data, mapId, x, y)
  if not info then return false, err end
  if not info.walkable then return false, "not walkable" end
  if info.warpTile then return false, "warp tile" end

  local marker = overviewMarkerAt(world, mapId, x, y)
    or staticMarkerAt(game.data, save, mapId, x, y)
  if marker then return false, marker .. " tile" end

  if world and type(world.current) == "function"
      and type(world.overworld) == "function" then
    local current = world:current()
    if current and current.mapId == mapId then
      local ow = world:overworld()
      if ow and type(ow.npcAtCell) == "function" and ow:npcAtCell(x, y) then
        return false, "occupied"
      end
    end
  end
  return true
end

function TravelSafety.mapName(data, mapId)
  local def = data and data.maps and data.maps[mapId]
  if def and type(def.label) == "string" and def.label ~= "" then
    return def.label
  end
  if type(mapId) ~= "string" then return "UNKNOWN" end
  return (mapId:gsub("_", " "))
end

return TravelSafety
