local SpeciesWhistle = {}

SpeciesWhistle.EFFECT_ID = "species_whistle"
SpeciesWhistle.ITEM_EFFECT_ID = "DS_SPECIES_WHISTLE_EFFECT"
SpeciesWhistle.STRENGTH_OPTION = "species_whistle_strength"
SpeciesWhistle.STEPS_OPTION = "species_whistle_steps"
SpeciesWhistle.NONLOCAL_OPTION = "species_whistle_nonlocal"
SpeciesWhistle.NONLOCAL_RATE_OPTION = "species_whistle_nonlocal_rate"
SpeciesWhistle.TARGET_KEY = "species_whistle_target"

local STRENGTHS={ mild=2, strong=4, extreme=8 }
local DURATIONS={ [25]=true,[50]=true,[100]=true,[250]=true,[500]=true,[1000]=true }
local RATES={ ["0.5"]=0.005,["1"]=0.01,["2"]=0.02 }
local LEGENDARY={ ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true }

function SpeciesWhistle.resolveStrength(v) return STRENGTHS[tostring(v or "")] or 2 end
function SpeciesWhistle.resolveDuration(v) local n=tonumber(v); if n and DURATIONS[n] then return n end; return 100 end
function SpeciesWhistle.resolveNonlocalRate(v) return RATES[tostring(v or "")] or 0.005 end
function SpeciesWhistle.nonlocalEnabled(mod) return tostring(mod.options:get(SpeciesWhistle.NONLOCAL_OPTION))=="on" end
function SpeciesWhistle.isLegendary(species) return LEGENDARY[species] == true end

local function seen(save,species)
  local d=save and save.pokedex
  return d and ((d.seen and d.seen[species]) or (d.owned and d.owned[species])) or false
end

local function localSpecies(mod, Weights, mapId, species)
  local registry=mod.content and mod.content.encounters
  if not (registry and type(registry.get)=="function") then return false end
  local ok,def=pcall(registry.get,registry,mapId); if not ok or type(def)~="table" then return false end
  for _,terrain in ipairs({"grass","water"}) do
    if (Weights.distribution(def,terrain)[species] or 0)>0 then return true end
  end
  return false
end

function SpeciesWhistle.install(mod,runtime,Weights)
  local function target() return runtime:getReusableState(SpeciesWhistle.TARGET_KEY,nil) end
  local function validTarget(data,save,species)
    return type(species)=="string" and not LEGENDARY[species] and data and data.pokemon and data.pokemon[species] and seen(save,species)
  end

  local function openSelector(game)
    local rows={}
    for species,def in pairs(game.data.pokemon or {}) do
      if validTarget(game.data,game.save,species) then
        rows[#rows+1]={label=(def.name or species),value=species}
      end
    end
    table.sort(rows,function(a,b) return a.label<b.label end)
    rows[#rows+1]={label="CANCEL",value="cancel"}
    local menu
    menu=mod.ui.ListMenu.new(game,"WHISTLE TARGET",rows,{
      pageJump=true,
      onChoose=function(row)
        if not row then return end
        if row.value~="cancel" then runtime:setReusableState(SpeciesWhistle.TARGET_KEY,row.value) end
        if menu then menu:close() end
      end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end
  SpeciesWhistle.openSelector=openSelector

  mod.hooks:wrap("ui.start_menu.items",function(next,game,items)
    local out=next(game,items); if type(out)~="table" then out=items end
    local inv=game.save and game.save.inventory or {}
    if (tonumber(inv.DS_SPECIES_WHISTLE) or 0)<=0 then return out end
    local selected=target(); local label=selected and "WHISTLE TARGET*" or "WHISTLE TARGET"
    local row={label=label,onSelect=function() openSelector(game) end}
    for i,item in ipairs(out) do
      if item.label=="OPTION" then table.insert(out,i,row); return out end
    end
    out[#out+1]=row; return out
  end)

  mod.content.item_effects:register(SpeciesWhistle.ITEM_EFFECT_ID,{
    needsTarget=false,field=true,battle=false,
    use=function(ctx)
      local species=target()
      if not validTarget(ctx.data,ctx.save,species) then return "failed", {"Choose a seen POKéMON\nwith WHISTLE TARGET."} end
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

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    if runtime.pendingExpirationNotice==SpeciesWhistle.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then runtime.pendingExpirationNotice=nil; game.stack:push(mod.ui.TextBox.new(game,"The whistle's call\nfaded away.")) end
    end
    return r
  end)

  SpeciesWhistle.target=target
  SpeciesWhistle.localSpecies=function(mapId,species) return localSpecies(mod,Weights,mapId,species) end
  return SpeciesWhistle
end

return SpeciesWhistle
