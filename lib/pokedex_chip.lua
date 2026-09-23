-- Pokedex Chip: encounter-area statistics layered onto seen Pokedex entries.
-- The primary entry point is SELECT from the normal DexEntryMenu; the GADGETS
-- row exists only as a discoverability/help surface.

local PokedexChip = {}

PokedexChip.KEY = "pokedex_chip"

local METHOD_ORDER = {
  grass = 1, water = 2, OLD_ROD = 3, GOOD_ROD = 4, SUPER_ROD = 5,
}
local METHOD_LABEL = {
  grass = "LAND", water = "SURF",
  OLD_ROD = "OLD ROD", GOOD_ROD = "GOOD ROD", SUPER_ROD = "SUPER ROD",
}

local function copyDist(dist)
  local out = {}
  for k,v in pairs(dist or {}) do out[k] = tonumber(v) or 0 end
  return out
end

local function contains(list, value)
  for _,v in ipairs(list or {}) do if v == value then return true end end
  return false
end

local function seen(game, species)
  local dex = game and game.save and game.save.pokedex
  return dex and ((dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])) or false
end

local function mapName(game, mapId)
  local def = game and game.data and game.data.maps and game.data.maps[mapId]
  local name = def and (def.name or def.displayName)
  if not name or name == "" then name = tostring(mapId or ""):gsub("_", " ") end
  return name
end

function PokedexChip.levelRange(Weights, tableDef, species)
  local lo, hi, anyLo, anyHi
  for _,row in ipairs(Weights.slotWeights(tableDef)) do
    local level = tonumber(row.level)
    if level then
      anyLo = anyLo and math.min(anyLo, level) or level
      anyHi = anyHi and math.max(anyHi, level) or level
      if row.species == species then
        lo = lo and math.min(lo, level) or level
        hi = hi and math.max(hi, level) or level
      end
    end
  end
  -- Mystery Lure / non-local Whistle replace native slots but preserve the
  -- area's native level, so an injected species inherits the table range.
  return lo or anyLo, hi or anyHi
end

function PokedexChip.fishingDistribution(candidates)
  local dist = {}
  local count = 0
  for _,row in ipairs(candidates or {}) do
    if row and row.species then
      dist[row.species] = (dist[row.species] or 0) + 1
      count = count + 1
    end
  end
  return dist, count
end

local function applyReserved(dist, species, share)
  if not species or not dist then return dist end
  local total = 0
  for _,v in pairs(dist) do total = total + (tonumber(v) or 0) end
  if total <= 0 then return dist end
  share = math.max(0, math.min(0.95, tonumber(share) or 0))
  local out = {}
  for k,v in pairs(dist) do out[k] = (tonumber(v) or 0) * (1-share) end
  out[species] = (out[species] or 0) + total * share
  return out
end

local function fieldValue(game,key)
  local data=game and game.data
  local direct=data and data.field and data.field[key]
  if direct~=nil then return direct end
  local ok,FieldDefaults=pcall(require,"src.world.FieldDefaults")
  if ok and FieldDefaults and type(FieldDefaults.field)=="function" then
    return FieldDefaults.field(data,key)
  end
  return nil
end

local function nativeFishing(game, mapId, rod)
  local fishing = fieldValue(game,"fishing") or {}
  local def = fishing[rod]
  if not def then return nil end
  if def.always then return { def.always } end
  if def.pool then return def.pool end
  if def.perMap then
    local groups = fieldValue(game,def.perMap)
    return groups and groups[mapId] or nil
  end
  return nil
end

local function mapIds(mod, game)
  local seenIds, out = {}, {}
  local registry = mod.content and mod.content.encounters
  if registry and type(registry.each) == "function" then
    for id in registry:each() do
      if not seenIds[id] then seenIds[id] = true; out[#out+1] = id end
    end
  end
  local fishing = fieldValue(game,"fishing") or {}
  for _,rod in ipairs({"OLD_ROD","GOOD_ROD","SUPER_ROD"}) do
    local def = fishing[rod]
    local groups = def and def.perMap and fieldValue(game,def.perMap)
    for id in pairs(groups or {}) do
      if not seenIds[id] then seenIds[id] = true; out[#out+1] = id end
    end
  end
  table.sort(out)
  return out
end

local function total(dist)
  local n = 0
  for _,v in pairs(dist or {}) do n = n + (tonumber(v) or 0) end
  return n
end

function PokedexChip.install(mod, runtime, Weights, deps)
  deps = deps or {}
  local ElusiveScent = deps.elusive
  local MysteryLure = deps.mystery
  local SpeciesWhistle = deps.whistle
  local PrototypeResonator = deps.resonator
  local SafariKit = deps.safari
  local inputLatch = false

  local function activeDistribution(mapId, terrain)
    local dist
    if mod.world and type(mod.world.effectiveEncounters) == "function" then
      local ok, info = pcall(mod.world.effectiveEncounters, mod.world, mapId, terrain)
      if ok and type(info) == "table" and type(info.dist) == "table" then
        dist = copyDist(info.dist)
      end
    end
    local registry = mod.content and mod.content.encounters
    local encDef
    if registry and type(registry.get) == "function" then
      local ok, value = pcall(registry.get, registry, mapId)
      if ok then encDef = value end
    end
    if not dist then dist = Weights.distribution(encDef, terrain) end

    if SafariKit and SafariKit.isSafari and SafariKit.isSafari(mapId)
        and SafariKit.baitActive and SafariKit.baitActive() then
      dist = Weights.compressDistribution(dist,
        SafariKit.resolveBaitStrength(mod.options:get(SafariKit.BAIT_POWER_OPTION)))
    elseif ElusiveScent and runtime:isActive(ElusiveScent.EFFECT_ID) then
      dist = Weights.compressDistribution(dist,
        ElusiveScent.resolveStrength(mod.options:get(ElusiveScent.STRENGTH_OPTION)))
    elseif MysteryLure and runtime:isActive(MysteryLure.EFFECT_ID)
        and (not MysteryLure.isSafari or not MysteryLure.isSafari(mapId)) then
      local selected = MysteryLure.selectedFor and MysteryLure.selectedFor(mapId, terrain)
      dist = Weights.reserveSpecies(dist, selected,
        MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)))
    elseif SpeciesWhistle and runtime:isActive(SpeciesWhistle.EFFECT_ID) then
      local target = SpeciesWhistle.target and SpeciesWhistle.target()
      if target then
        if dist[target] then
          dist = Weights.boostDistribution(dist, { [target]=true },
            SpeciesWhistle.resolveStrength(mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
        elseif SpeciesWhistle.nonlocalEnabled and SpeciesWhistle.nonlocalEnabled(mod) then
          dist = Weights.reserveSpecies(dist, target,
            SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)))
        end
      end
    end
    return dist, encDef
  end

  local function adjustedRange(game, mapId, tableDef, species)
    local lo, hi = PokedexChip.levelRange(Weights, tableDef, species)
    if not lo then return nil,nil end
    if PrototypeResonator and runtime:isActive(PrototypeResonator.EFFECT_ID)
        and not PrototypeResonator.isSafari(mapId) then
      local _,lead = PrototypeResonator.firstUsableLead(game.save)
      if lead then
        local nativeMax = PrototypeResonator.maxLevelFromTable(Weights, tableDef)
        local cap = PrototypeResonator.resolveCap(mod.options:get(PrototypeResonator.POWER_OPTION))
        lo = PrototypeResonator.raiseLevel(lo, lead, nativeMax, cap)
        hi = PrototypeResonator.raiseLevel(hi, lead, nativeMax, cap)
      end
    end
    return lo,hi
  end

  local function addRow(rows, game, mapId, method, dist, lo, hi)
    local weight = dist and dist[rows._species]
    local sum = total(dist)
    if not weight or weight <= 0 or sum <= 0 then return end
    rows[#rows+1] = {
      mapId = mapId,
      mapName = mapName(game,mapId),
      method = method,
      methodLabel = METHOD_LABEL[method] or method,
      share = weight / sum,
      minLevel = lo,
      maxLevel = hi,
    }
  end

  function PokedexChip.scan(game, species)
    if not seen(game, species) then return {}, "DATA UNKNOWN" end
    local rows = { _species=species }
    local ids = mapIds(mod, game)
    for _,mapId in ipairs(ids) do
      for _,terrain in ipairs({"grass","water"}) do
        local dist, encDef = activeDistribution(mapId, terrain)
        local tableDef = Weights.terrainTable(encDef, terrain)
        if tableDef and dist and dist[species] then
          local lo,hi = adjustedRange(game,mapId,tableDef,species)
          addRow(rows,game,mapId,terrain,dist,lo,hi)
        end
      end

      local registry=mod.content and mod.content.encounters
      local mergedDef
      if registry and type(registry.get)=="function" then
        local ok,value=pcall(registry.get,registry,mapId)
        if ok then mergedDef=value end
      end
      local fishable=(mergedDef and mergedDef.water~=nil)
        or (nativeFishing(game,mapId,"SUPER_ROD")~=nil)
      for _,rod in ipairs({"OLD_ROD","GOOD_ROD","SUPER_ROD"}) do
        local candidates = fishable and nativeFishing(game,mapId,rod) or nil
        if candidates and #candidates > 0 then
          local dist = PokedexChip.fishingDistribution(candidates)
          if runtime:isActive(MysteryLure and MysteryLure.EFFECT_ID or "") and MysteryLure then
            local selected = MysteryLure.selectedFor and MysteryLure.selectedFor(mapId,"fishing")
            dist = applyReserved(dist, selected,
              MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)))
          elseif SpeciesWhistle and runtime:isActive(SpeciesWhistle.EFFECT_ID) then
            local target = SpeciesWhistle.target and SpeciesWhistle.target()
            if target then
              local rate
              if dist[target] then
                rate=math.min(0.80,0.15*SpeciesWhistle.resolveStrength(
                  mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
                local base=dist[target]
                local sum=total(dist)
                if sum>0 then
                  local desired=(base/sum)+(1-base/sum)*rate
                  dist=Weights.reserveSpecies(dist,target,desired)
                end
              elseif SpeciesWhistle.nonlocalEnabled and SpeciesWhistle.nonlocalEnabled(mod) then
                dist=Weights.reserveSpecies(dist,target,
                  SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)))
              end
            end
          end
          if dist[species] then
            local lo,hi
            for _,row in ipairs(candidates) do
              local level=tonumber(row.level)
              if level then
                if row.species==species then
                  lo=lo and math.min(lo,level) or level
                  hi=hi and math.max(hi,level) or level
                end
              end
            end
            if not lo then
              for _,row in ipairs(candidates) do
                local level=tonumber(row.level)
                if level then lo=lo and math.min(lo,level) or level; hi=hi and math.max(hi,level) or level end
              end
            end
            if PrototypeResonator and runtime:isActive(PrototypeResonator.EFFECT_ID)
                and not PrototypeResonator.isSafari(mapId) and lo then
              local _,lead=PrototypeResonator.firstUsableLead(game.save)
              if lead then
                local nativeMax=PrototypeResonator.maxLevelFromCandidates(candidates)
                local cap=PrototypeResonator.resolveCap(mod.options:get(PrototypeResonator.POWER_OPTION))
                lo=PrototypeResonator.raiseLevel(lo,lead,nativeMax,cap)
                hi=PrototypeResonator.raiseLevel(hi,lead,nativeMax,cap)
              end
            end
            addRow(rows,game,mapId,rod,dist,lo,hi)
          end
        end
      end
    end
    rows._species=nil
    table.sort(rows,function(a,b)
      if a.mapName ~= b.mapName then return a.mapName < b.mapName end
      return (METHOD_ORDER[a.method] or 99) < (METHOD_ORDER[b.method] or 99)
    end)
    return rows, (#rows==0 and "NO CURRENT HABITAT" or nil)
  end

  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true
  function Screen.new(game,species,rows,empty)
    return setmetatable({game=game,species=species,rows=rows or {},empty=empty,cursor=1},Screen)
  end
  function Screen:update()
    local input=self.game.input
    local count=#self.rows
    if input:wasPressed("b") or input:wasPressed("select") then
      self.game.stack:pop(); return
    end
    if count==0 then return end
    if input:wasPressed("up") then self.cursor=math.max(1,self.cursor-1)
    elseif input:wasPressed("down") then self.cursor=math.min(count,self.cursor+1)
    elseif input:wasPressed("left") then self.cursor=math.max(1,self.cursor-3)
    elseif input:wasPressed("right") then self.cursor=math.min(count,self.cursor+3) end
  end
  function Screen:draw()
    local Font=require("src.render.Font")
    local def=self.game.data.pokemon[self.species] or {}
    love.graphics.setColor(1,1,1,1); love.graphics.rectangle("fill",0,0,160,144)
    love.graphics.setColor(0,0,0,1)
    Font.draw("POKEDEX CHIP",8,8)
    Font.draw(def.name or self.species,8,20)
    if self.empty then
      Font.draw(self.empty,8,52)
      Font.draw("B:BACK",8,132)
      love.graphics.setColor(1,1,1,1); return
    end
    local first=math.max(1,math.min(self.cursor,#self.rows-2))
    for i=0,2 do
      local row=self.rows[first+i]
      if row then
        local y=38+i*30
        Font.draw((first+i==self.cursor and ">" or " ")..row.mapName:sub(1,18),4,y)
        Font.draw(("%s  %.1f%%"):format(row.methodLabel,row.share*100),12,y+10)
        local range="LV ?"
        if row.minLevel then
          range=(row.minLevel==row.maxLevel) and ("LV "..row.minLevel)
            or ("LV "..row.minLevel.."-"..row.maxLevel)
        end
        Font.draw(range,12,y+20)
      end
    end
    Font.draw(("%d/%d  B:BACK"):format(self.cursor,#self.rows),8,132)
    love.graphics.setColor(1,1,1,1)
  end

  function PokedexChip.open(game,species)
    if not runtime:isUnlocked(PokedexChip.KEY) then return false end
    if not seen(game,species) then
      game.stack:push(mod.ui.TextBox.new(game,"Encounter data is\nstill unknown."))
      return false
    end
    local rows,empty=PokedexChip.scan(game,species)
    game.stack:push(Screen.new(game,species,rows,empty))
    return true
  end

  function PokedexChip.help(game)
    game.stack:push(mod.ui.TextBox.new(game,
      "POKEDEX CHIP ONLINE.\fOpen a seen POKEDEX\nentry and press SELECT\nto view AREA DATA."))
  end

  -- v0.2.5 has no dex-entry decoration hook. SELECT is unused by the native
  -- entry page, so detect that supported screen through input.step and layer a
  -- separate screen without replacing or rebuilding the Pokedex itself.
  mod.hooks:wrap("input.step",function(next,game,dt)
    local result=next(game,dt)
    local pressed=game and game.input and game.input:wasPressed("select")
    if pressed and not inputLatch and runtime:isUnlocked(PokedexChip.KEY) then
      local stack=game.stack
      local top=stack and stack.top and stack:top()
      local ok,DexEntryMenu=pcall(require,"src.ui.DexEntryMenu")
      if ok and top and getmetatable(top)==DexEntryMenu and top.def and top.def.id then
        PokedexChip.open(game,top.def.id)
      end
    end
    inputLatch=pressed and true or false
    return result
  end)

  return PokedexChip
end

return PokedexChip
