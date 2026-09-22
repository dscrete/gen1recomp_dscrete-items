local SpeciesWhistle = {}

SpeciesWhistle.EFFECT_ID = "species_whistle"
SpeciesWhistle.ITEM_EFFECT_ID = "DS_SPECIES_WHISTLE_EFFECT"
SpeciesWhistle.STRENGTH_OPTION = "species_whistle_strength"
SpeciesWhistle.STEPS_OPTION = "species_whistle_steps"
SpeciesWhistle.NONLOCAL_OPTION = "species_whistle_nonlocal"
SpeciesWhistle.NONLOCAL_RATE_OPTION = "species_whistle_nonlocal_rate"
SpeciesWhistle.TARGET_KEY = "species_whistle_target"
SpeciesWhistle.ITEM_ID = "DS_SPECIES_WHISTLE"

local STRENGTHS={ mild=2, strong=4, extreme=8 }
local DURATIONS={ [25]=true,[50]=true,[100]=true,[250]=true,[500]=true,[1000]=true }
local RATES={ ["0.5"]=0.005,["1"]=0.01,["2"]=0.02 }
local LEGENDARY={ ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true }
local WILDS_ID="overworld_wild_spawns"

function SpeciesWhistle.resolveStrength(v) return STRENGTHS[tostring(v or "")] or 2 end
function SpeciesWhistle.resolveDuration(v) local n=tonumber(v); if n and DURATIONS[n] then return n end; return 100 end
function SpeciesWhistle.resolveNonlocalRate(v) return RATES[tostring(v or "")] or 0.005 end
function SpeciesWhistle.nonlocalEnabled(mod) return tostring(mod.options:get(SpeciesWhistle.NONLOCAL_OPTION))=="on" end
function SpeciesWhistle.isLegendary(species) return LEGENDARY[species] == true end

local function seen(save,species)
  local d=save and save.pokedex
  return d and ((d.seen and d.seen[species]) or (d.owned and d.owned[species])) or false
end

local function encounterDef(mod,mapId)
  local registry=mod.content and mod.content.encounters
  if not (registry and type(registry.get)=="function") then return nil end
  local ok,def=pcall(registry.get,registry,mapId)
  return ok and type(def)=="table" and def or nil
end

local function localSpecies(mod, Weights, mapId, species)
  local def=encounterDef(mod,mapId); if not def then return false end
  for _,terrain in ipairs({"grass","water"}) do
    if (Weights.distribution(def,terrain)[species] or 0)>0 then return true end
  end
  return false
end

local function pickSlot(Weights,tableDef)
  local rows=Weights.slotWeights(tableDef); if #rows==0 then return nil end
  local pick=love.math.random(0,255)
  local cumulative=0
  for _,row in ipairs(rows) do
    cumulative=cumulative+row.weight
    if pick<cumulative then return {species=row.species,level=row.level} end
  end
  local last=rows[#rows]
  return last and {species=last.species,level=last.level} or nil
end

function SpeciesWhistle.install(mod,runtime,Weights)
  local wildsWrapped=false
  local function target() return runtime:getReusableState(SpeciesWhistle.TARGET_KEY,nil) end
  local function validTarget(data,save,species)
    return type(species)=="string" and not LEGENDARY[species] and data and data.pokemon and data.pokemon[species] and seen(save,species)
  end

  local function targetRows(game)
    local rows={}
    for species,def in pairs(game.data.pokemon or {}) do
      if validTarget(game.data,game.save,species) then rows[#rows+1]={label=(def.name or species),value=species} end
    end
    table.sort(rows,function(a,b) return a.label<b.label end)
    return rows
  end

  -- The public item.use hook exists specifically to let a mod delay the normal
  -- bag-item dispatch behind its own screen. Intercept only the Whistle, open
  -- the selector, then resume the same vanilla use path after a species is picked.
  -- Cancelling never calls vanilla, so the item is not consumed.
  mod.hooks:wrap("item.use",function(next,game,battle,id,itemTarget,list,moveIndex,picker)
    if id~=SpeciesWhistle.ITEM_ID or battle then
      return next(game,battle,id,itemTarget,list,moveIndex,picker)
    end

    local rows=targetRows(game)
    if #rows==0 then
      return next(game,battle,id,itemTarget,list,moveIndex,picker)
    end
    rows[#rows+1]={label="CANCEL",value="cancel"}

    local remembered=target()
    local rememberedIndex=1
    for i,row in ipairs(rows) do if row.value==remembered then rememberedIndex=i break end end

    local menu
    menu=mod.ui.ListMenu.new(game,"WHISTLE TARGET",rows,{
      pageJump=true,
      onChoose=function(row)
        if not row then return end
        if row.value=="cancel" then
          if menu then menu:close() end
          return
        end
        runtime:setReusableState(SpeciesWhistle.TARGET_KEY,row.value)
        if menu then menu:close() end
        next(game,battle,id,itemTarget,list,moveIndex,picker)
      end,
      onCancel=function()
        if menu then menu:close() end
      end,
    })
    menu.index=rememberedIndex
    game.stack:push(menu)
    return nil
  end)

  mod.content.item_effects:register(SpeciesWhistle.ITEM_EFFECT_ID,{
    needsTarget=false,field=true,battle=false,
    use=function(ctx)
      local species=target()
      if not validTarget(ctx.data,ctx.save,species) then return "failed", {"No seen POKéMON\ncan answer the call."} end
      local current=mod.world:current(); local mapId=current and current.mapId
      if not mapId then return "failed", {"The whistle has\nno effect here."} end
      local native=localSpecies(mod,Weights,mapId,species)
      if not native and not SpeciesWhistle.nonlocalEnabled(mod) then return "failed", {"No local POKéMON\nanswer that call."} end
      if runtime.activeFieldEffect==SpeciesWhistle.EFFECT_ID then return "failed", {"The whistle's call\nis already active."} end
      local replace=false
      if runtime.activeFieldEffect then
        replace=runtime:requestFieldReplacement(SpeciesWhistle.EFFECT_ID)
        if not replace then return "failed", {"Another field effect\nis already active.\fUse PKMN WHISTLE\nagain to replace it."} end
      end
      local d=SpeciesWhistle.resolveDuration(mod.options:get(SpeciesWhistle.STEPS_OPTION))
      if not runtime:activateFieldEffect(SpeciesWhistle.EFFECT_ID,d,replace) then return "failed", {"The whistle's call\nfades away."} end
      return "consumed", {("A distant cry answers!\fThe call will last\nfor %d steps."):format(d)}, {useJingle=true}
    end,
  })

  mod.hooks:wrap("encounter.roll",function(next,encDef,ctx)
    if not runtime:isActive(SpeciesWhistle.EFFECT_ID) or not ctx then return next(encDef,ctx) end
    local species=target(); if not species then return next(encDef,ctx) end
    local boosted,native=Weights.boostSpeciesEncounterDef(encDef,ctx.terrain,species,
      SpeciesWhistle.resolveStrength(mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
    local enc=next(boosted,ctx)
    if enc and not native and SpeciesWhistle.nonlocalEnabled(mod)
        and love.math.random()<=SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)) then enc.species=species end
    return enc
  end)

  mod.hooks:wrap("encounter.fishing",function(next,rod,mapId,candidates)
    local enc=next(rod,mapId,candidates)
    if not enc or not runtime:isActive(SpeciesWhistle.EFFECT_ID) then return enc end
    local species=target(); if not species then return enc end
    local present=false
    for _,c in ipairs(candidates or {}) do if c.species==species then present=true break end end
    local chance=present and math.min(0.80,0.15*SpeciesWhistle.resolveStrength(mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
      or (SpeciesWhistle.nonlocalEnabled(mod) and SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)) or 0)
    if love.math.random()<=chance then enc.species=species end
    return enc
  end)

  local function installWildsCompatibility()
    if wildsWrapped or type(mod.find)~="function" then return wildsWrapped end
    local found=mod.find(WILDS_ID)
    local logic=found and found.exports and found.exports.logic
    if not (logic and type(logic.trySpawn)=="function") then return false end
    if logic._dscreteSpeciesWhistleWrapped then wildsWrapped=true return true end
    local original=logic.trySpawn
    logic.trySpawn=function(self,game,opts)
      opts=opts or {}
      if runtime:isActive(SpeciesWhistle.EFFECT_ID) and not opts.species and not opts.testSpawn and not opts.readinessProbe then
        local species=target()
        local current=mod.world:current(); local mapId=(current and current.mapId) or self.activeMapId
        local terrain=self.surfaceInfo and self.surfaceInfo.encounterKind or "grass"
        if terrain=="indoor" then terrain="grass" end
        local def=encounterDef(mod,mapId)
        local native=def and species and (Weights.distribution(def,terrain)[species] or 0)>0
        if species and native then
          local boosted=Weights.boostSpeciesEncounterDef(def,terrain,species,SpeciesWhistle.resolveStrength(mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
          local picked=pickSlot(Weights,Weights.terrainTable(boosted,terrain))
          if picked then local f={}; for k,v in pairs(opts) do f[k]=v end; f.species,f.level=picked.species,picked.level; opts=f end
        elseif species and SpeciesWhistle.nonlocalEnabled(mod)
            and love.math.random()<=SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)) then
          local base=def and pickSlot(Weights,Weights.terrainTable(def,terrain))
          local f={}; for k,v in pairs(opts) do f[k]=v end; f.species=species; if base then f.level=base.level end; opts=f
        end
      end
      return original(self,game,opts)
    end
    logic._dscreteSpeciesWhistleWrapped=true
    wildsWrapped=true
    return true
  end

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    if runtime.pendingExpirationNotice==SpeciesWhistle.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then runtime.pendingExpirationNotice=nil; game.stack:push(mod.ui.TextBox.new(game,"The whistle's call\nfaded away.")) end
    end
    return r
  end)

  mod.events:on("mods.loaded",installWildsCompatibility)
  mod.events:on("game.ready",installWildsCompatibility)
  SpeciesWhistle.target=target
  SpeciesWhistle.localSpecies=function(mapId,species) return localSpecies(mod,Weights,mapId,species) end
  SpeciesWhistle.targetRows=targetRows
  return SpeciesWhistle
end

return SpeciesWhistle
