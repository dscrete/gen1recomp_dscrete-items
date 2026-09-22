-- Silph Tracker: permanent gadget that reports coarse signal bands for every
-- species currently present on the player's map. Unseen species remain UNKNOWN.

local SilphTracker = {}
SilphTracker.KEY = "silph_tracker"
local BAND_RANK = { ["NO SIGNAL"]=0, FAINT=1, WEAK=2, STRONG=3, ["VERY STRONG"]=4 }

local function seenSpecies(game,species)
  local dex=game and game.save and game.save.pokedex
  return dex and ((dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])) or false
end

local function displayName(game,species)
  if not seenSpecies(game,species) then return "UNKNOWN" end
  local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
  return (def and def.name) or tostring(species)
end

function SilphTracker.install(mod,runtime,Weights,ElusiveScent,MysteryLure,SpeciesWhistle,SafariKit)
  local function basePreview(mapId,terrain)
    if mod.world and type(mod.world.effectiveEncounters)=="function" then
      local ok,info=pcall(mod.world.effectiveEncounters,mod.world,mapId,terrain)
      if ok and info and type(info.dist)=="table" then return info.dist end
    end
    local registry=mod.content and mod.content.encounters
    if registry and type(registry.get)=="function" then
      local ok,def=pcall(registry.get,registry,mapId)
      if ok then return Weights.distribution(def,terrain) end
    end
    return {}
  end

  local function applyActive(dist,mapId,terrain)
    if SafariKit and SafariKit.baitActive and SafariKit.baitActive() and SafariKit.isSafari(mapId) then
      return Weights.compressDistribution(dist,SafariKit.resolveBaitStrength(mod.options:get(SafariKit.BAIT_POWER_OPTION)))
    end
    if runtime:isActive(ElusiveScent.EFFECT_ID) then
      return Weights.compressDistribution(dist,ElusiveScent.resolveStrength(mod.options:get(ElusiveScent.STRENGTH_OPTION)))
    end
    if MysteryLure and runtime:isActive(MysteryLure.EFFECT_ID) and not MysteryLure.isSafari(mapId) then
      local species=MysteryLure.selectedFor and MysteryLure.selectedFor(mapId,terrain)
      if species then return Weights.reserveSpecies(dist,species,MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION))) end
    end
    if SpeciesWhistle and runtime:isActive(SpeciesWhistle.EFFECT_ID) then
      local species=SpeciesWhistle.target and SpeciesWhistle.target()
      if species then
        if (dist[species] or 0)>0 then
          return Weights.boostDistribution(dist,{[species]=true},SpeciesWhistle.resolveStrength(mod.options:get(SpeciesWhistle.STRENGTH_OPTION)))
        elseif SpeciesWhistle.nonlocalEnabled(mod) then
          return Weights.reserveSpecies(dist,species,SpeciesWhistle.resolveNonlocalRate(mod.options:get(SpeciesWhistle.NONLOCAL_RATE_OPTION)))
        end
      end
    end
    return dist
  end

  function SilphTracker.scan(game)
    local current=mod.world:current()
    if not current or not current.mapId then return {},"NO LOCAL SIGNAL" end
    local combined={}
    for _,terrain in ipairs({"grass","water"}) do
      local dist=applyActive(basePreview(current.mapId,terrain),current.mapId,terrain)
      local total=Weights.total(dist)
      if total>0 then
        for species,weight in pairs(dist) do
          local share=weight/total
          local band=Weights.signalBand(weight,total)
          local old=combined[species]
          if not old or BAND_RANK[band]>BAND_RANK[old.band]
              or (BAND_RANK[band]==BAND_RANK[old.band] and share>old.share) then
            combined[species]={species=species,band=band,share=share}
          end
        end
      end
    end
    local out={}
    for _,row in pairs(combined) do row.name=displayName(game,row.species); out[#out+1]=row end
    table.sort(out,function(a,b)
      if a.share~=b.share then return a.share>b.share end
      if a.name~=b.name then return a.name<b.name end
      return tostring(a.species)<tostring(b.species)
    end)
    return out,(#out==0) and "NO LOCAL SIGNAL" or nil
  end

  function SilphTracker.open(game)
    local rows,empty=SilphTracker.scan(game)
    local menuRows={}
    if #rows==0 then menuRows[#menuRows+1]={label=empty or "NO LOCAL SIGNAL",value="noop"} end
    for i,row in ipairs(rows) do menuRows[#menuRows+1]={label=("%s - %s"):format(row.name,row.band),value="row"..i} end
    menuRows[#menuRows+1]={label="CLOSE",value="close"}
    local menu
    menu=mod.ui.ListMenu.new(game,"SILPH TRACKER",menuRows,{
      pageJump=true,
      onChoose=function(row) if row and row.value=="close" and menu then menu:close() end end,
      onCancel=function() if menu then menu:close() end end,
    })
    game.stack:push(menu)
  end

  function SilphTracker.text(game)
    local rows,empty=SilphTracker.scan(game)
    if #rows==0 then return "SILPH TRACKER\n"..(empty or "NO LOCAL SIGNAL") end
    local lines={"SILPH TRACKER"}
    for _,row in ipairs(rows) do lines[#lines+1]=("%s - %s"):format(row.name,row.band) end
    return table.concat(lines,"\n")
  end

  return SilphTracker
end

return SilphTracker
