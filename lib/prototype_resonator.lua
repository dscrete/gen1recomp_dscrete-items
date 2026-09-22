local PrototypeResonator = {}

PrototypeResonator.EFFECT_ID = "prototype_resonator"
PrototypeResonator.ITEM_EFFECT_ID = "DS_PROTOTYPE_RESONATOR_EFFECT"
PrototypeResonator.POWER_OPTION = "prototype_resonator_power"
PrototypeResonator.STEPS_OPTION = "prototype_resonator_steps"

local CAPS = { mild=10, strong=20, extreme=35 }
local DURATIONS = { [50]=true,[100]=true,[250]=true,[500]=true,[1000]=true,[2500]=true }
local WILDS_ID = "overworld_wild_spawns"

function PrototypeResonator.resolveCap(v)
  return CAPS[tostring(v or "")] or 20
end

function PrototypeResonator.resolveDuration(v)
  local n=tonumber(v)
  if n and DURATIONS[n] then return n end
  return 250
end

function PrototypeResonator.isSafari(mapId)
  return type(mapId)=="string" and mapId:find("SAFARI_ZONE",1,true)~=nil
end

function PrototypeResonator.firstUsableLead(save)
  for _,mon in ipairs((save and save.party) or {}) do
    local hp=tonumber(mon and mon.hp) or 0
    local level=tonumber(mon and mon.level) or 0
    if hp>0 and level>0 then return mon,level end
  end
  return nil,nil
end

function PrototypeResonator.maxLevelFromTable(Weights,tableDef)
  local maximum=0
  for _,row in ipairs(Weights.slotWeights(tableDef)) do
    maximum=math.max(maximum,tonumber(row.level) or 0)
  end
  return maximum
end

function PrototypeResonator.maxLevelFromCandidates(candidates)
  local maximum=0
  for _,row in ipairs(candidates or {}) do maximum=math.max(maximum,tonumber(row.level) or 0) end
  return maximum
end

-- Preserve the area's native level spread instead of flattening every slot.
-- If an area's slots are 3/4/5, a lead of 40 at STRONG (+20 cap) produces
-- 23/24/25: same relative shape, shifted toward the lead, never above the cap.
function PrototypeResonator.raiseLevel(nativeLevel,leadLevel,nativeMaximum,capBonus)
  nativeLevel=tonumber(nativeLevel) or 0
  leadLevel=tonumber(leadLevel) or 0
  nativeMaximum=tonumber(nativeMaximum) or nativeLevel
  capBonus=tonumber(capBonus) or 20
  if nativeLevel<=0 or leadLevel<=nativeMaximum then return nativeLevel end
  local target=math.min(leadLevel,nativeMaximum+capBonus,100)
  local shift=math.max(0,target-nativeMaximum)
  return math.max(nativeLevel,math.min(100,nativeLevel+shift))
end

local function encounterDef(mod,mapId)
  local registry=mod.content and mod.content.encounters
  if not (registry and type(registry.get)=="function") then return nil end
  local ok,def=pcall(registry.get,registry,mapId)
  return ok and type(def)=="table" and def or nil
end

local function pickSlot(Weights,tableDef)
  local rows=Weights.slotWeights(tableDef)
  if #rows==0 then return nil end
  local pick=love.math.random(0,255)
  local cumulative=0
  for _,row in ipairs(rows) do
    cumulative=cumulative+row.weight
    if pick<cumulative then return {species=row.species,level=row.level} end
  end
  local last=rows[#rows]
  return last and {species=last.species,level=last.level} or nil
end

function PrototypeResonator.install(mod,runtime,Weights)
  local wildsWrapped=false

  local function adjustedLevel(save,native,nativeMaximum)
    local _,lead=PrototypeResonator.firstUsableLead(save)
    if not lead then return native end
    return PrototypeResonator.raiseLevel(native,lead,nativeMaximum,
      PrototypeResonator.resolveCap(mod.options:get(PrototypeResonator.POWER_OPTION)))
  end

  mod.content.item_effects:register(PrototypeResonator.ITEM_EFFECT_ID,{
    needsTarget=false,field=true,battle=false,
    use=function(ctx)
      local current=mod.world:current()
      local mapId=current and current.mapId
      if PrototypeResonator.isSafari(mapId) then
        return "failed", {"The RESONATOR is\ndisabled in SAFARI."}
      end
      if not PrototypeResonator.firstUsableLead(ctx.save) then
        return "failed", {"No conscious POKéMON\ncan set the signal."}
      end
      if runtime.activeFieldEffect==PrototypeResonator.EFFECT_ID then
        return "failed", {"The RESONATOR is\nalready humming."}
      end
      local replace=false
      if runtime.activeFieldEffect then
        replace=runtime:requestFieldReplacement(PrototypeResonator.EFFECT_ID)
        if not replace then
          return "failed", {"Another field effect\nis already active.\fUse RESONATOR again\nto replace it."}
        end
      end
      local d=PrototypeResonator.resolveDuration(mod.options:get(PrototypeResonator.STEPS_OPTION))
      if not runtime:activateFieldEffect(PrototypeResonator.EFFECT_ID,d,replace) then
        return "failed", {"The signal won't\nstabilize."}
      end
      return "consumed", {("The prototype hums!\fStrong POKéMON stir\nfor %d steps."):format(d)}, {useJingle=true}
    end,
  })

  mod.hooks:wrap("encounter.roll",function(next,encDef,ctx)
    local enc=next(encDef,ctx)
    if not enc or not runtime:isActive(PrototypeResonator.EFFECT_ID) or not ctx
        or PrototypeResonator.isSafari(ctx.mapId) then return enc end
    local tableDef=Weights.terrainTable(encDef,ctx.terrain)
    local maximum=PrototypeResonator.maxLevelFromTable(Weights,tableDef)
    if maximum>0 then enc.level=adjustedLevel(ctx.save or (ctx.game and ctx.game.save),enc.level,maximum) end
    return enc
  end)

  mod.hooks:wrap("encounter.fishing",function(next,rod,mapId,candidates)
    local enc=next(rod,mapId,candidates)
    if not enc or not runtime:isActive(PrototypeResonator.EFFECT_ID)
        or PrototypeResonator.isSafari(mapId) then return enc end
    local maximum=PrototypeResonator.maxLevelFromCandidates(candidates)
    local game=mod.world and mod.world.game
    local save=(game and game.save) or nil
    if maximum>0 and save then enc.level=adjustedLevel(save,enc.level,maximum) end
    return enc
  end)

  local function installWildsCompatibility()
    if wildsWrapped or type(mod.find)~="function" then return wildsWrapped end
    local found=mod.find(WILDS_ID)
    local logic=found and found.exports and found.exports.logic
    if not (logic and type(logic.trySpawn)=="function") then return false end
    if logic._dscretePrototypeResonatorWrapped then wildsWrapped=true return true end
    local original=logic.trySpawn
    logic.trySpawn=function(self,game,opts)
      opts=opts or {}
      if runtime:isActive(PrototypeResonator.EFFECT_ID) and not opts.testSpawn and not opts.readinessProbe then
        local current=mod.world:current()
        local mapId=(current and current.mapId) or self.activeMapId
        if not PrototypeResonator.isSafari(mapId) then
          local terrain=self.surfaceInfo and self.surfaceInfo.encounterKind or "grass"
          if terrain=="indoor" then terrain="grass" end
          local def=encounterDef(mod,mapId)
          local tableDef=def and Weights.terrainTable(def,terrain)
          local maximum=PrototypeResonator.maxLevelFromTable(Weights,tableDef)
          local picked=tableDef and pickSlot(Weights,tableDef)
          if picked and maximum>0 then
            local f={}; for k,v in pairs(opts) do f[k]=v end
            if not f.species then f.species=picked.species end
            f.level=adjustedLevel(game.save,f.level or picked.level,maximum)
            opts=f
          end
        end
      end
      return original(self,game,opts)
    end
    logic._dscretePrototypeResonatorWrapped=true
    wildsWrapped=true
    return true
  end

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    if runtime.pendingExpirationNotice==PrototypeResonator.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then
        runtime.pendingExpirationNotice=nil
        game.stack:push(mod.ui.TextBox.new(game,"The RESONATOR's\nhum faded away."))
      end
    end
    return r
  end)

  mod.events:on("mods.loaded",installWildsCompatibility)
  mod.events:on("game.ready",installWildsCompatibility)
  return PrototypeResonator
end

return PrototypeResonator
