local MysteryLure = {}

MysteryLure.EFFECT_ID = "mystery_lure"
MysteryLure.ITEM_EFFECT_ID = "DS_MYSTERY_LURE_EFFECT"
MysteryLure.SHARE_OPTION = "mystery_lure_share"
MysteryLure.STEPS_OPTION = "mystery_lure_steps"
MysteryLure.SEEN_ONLY_OPTION = "mystery_lure_seen_only"

local SHARES = { low=0.05, medium=0.10, high=0.20 }
local DURATIONS = { [50]=true,[100]=true,[250]=true,[500]=true,[1000]=true,[2500]=true }
local WILDS_ID = "overworld_wild_spawns"

function MysteryLure.resolveShare(v) return SHARES[tostring(v or "")] or SHARES.low end
function MysteryLure.resolveDuration(v)
  local n=tonumber(v); if n and DURATIONS[n] then return n end; return 250
end

local function isSafari(mapId) return type(mapId)=="string" and mapId:find("SAFARI_ZONE",1,true) ~= nil end
local function habitat(mapId, terrain)
  if terrain == "water" or terrain == "fishing" then return "water" end
  mapId = tostring(mapId or "")
  if mapId:find("FOREST",1,true) then return "forest" end
  if mapId:find("CAVE",1,true) or mapId:find("TUNNEL",1,true) or mapId:find("MT_MOON",1,true) then return "cave" end
  return "field"
end
MysteryLure.habitat = habitat
MysteryLure.isSafari = isSafari

local function seen(save, species)
  local dex=save and save.pokedex
  return dex and ((dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])) or false
end

-- Candidates are normal wild species from this habitat in the game's merged
-- encounter data. No companion mod or fixed Kanto-only roster is required.
function MysteryLure.candidates(data, save, mapId, terrain, seenOnly, eligible)
  local out={}
  local source=eligible and eligible.habitats and eligible.habitats[habitat(mapId,terrain)] or {}
  for species in pairs(source) do
    if data and data.pokemon and data.pokemon[species]
        and (not seenOnly or seen(save,species)) then out[#out+1]=species end
  end
  table.sort(out)
  return out
end

function MysteryLure.install(mod, runtime, Weights, Eligibility)
  local wildsWrapped=false
  local eligiblePool=nil

  local function pool(data)
    if not eligiblePool then eligiblePool=Eligibility.collect(mod,data) end
    return eligiblePool
  end

  local function stateKey(mapId, terrain)
    return "mystery_lure_"..habitat(mapId,terrain)
  end

  local function chooseFor(ctx, mapId, terrain)
    local seenOnly = tostring(mod.options:get(MysteryLure.SEEN_ONLY_OPTION)) ~= "all"
    local pool = MysteryLure.candidates(ctx.data, ctx.save, mapId, terrain, seenOnly, pool(ctx.data))
    if #pool==0 then return nil end
    local key=stateKey(mapId,terrain)
    local existing=runtime:getReusableState(key,nil)
    for _,s in ipairs(pool) do if s==existing then return s end end
    local pick=pool[love.math.random(1,#pool)]
    runtime:setReusableState(key,pick)
    return pick
  end

  function MysteryLure.selectedFor(mapId, terrain)
    return runtime:getReusableState(stateKey(mapId,terrain),nil)
  end

  mod.content.item_effects:register(MysteryLure.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function(ctx)
      local current=mod.world:current(); local mapId=current and current.mapId
      if mapId and isSafari(mapId) then return "failed", {"The MYSTERY LURE\nwon't work here."} end
      if runtime.activeFieldEffect==MysteryLure.EFFECT_ID then return "failed", {"MYSTERY LURE is\nalready active."} end
      local seenOnly=tostring(mod.options:get(MysteryLure.SEEN_ONLY_OPTION))~="all"
      local candidates=MysteryLure.candidates(ctx.data,ctx.save,mapId,"grass",seenOnly,pool(ctx.data))
      local selectedTerrain="grass"
      if #candidates==0 then
        selectedTerrain="water"
        candidates=MysteryLure.candidates(ctx.data,ctx.save,mapId,selectedTerrain,seenOnly,pool(ctx.data))
      end
      if #candidates==0 then return "failed", {"No mysterious signal\nanswers the lure."} end
      local replace=false
      if runtime.activeFieldEffect then
        replace=runtime:requestFieldReplacement(MysteryLure.EFFECT_ID)
        if not replace then return "failed", {"Another field effect\nis already active.\fUse MYSTERY LURE\nagain to replace it."} end
      end
      local d=MysteryLure.resolveDuration(mod.options:get(MysteryLure.STEPS_OPTION))
      if not runtime:activateFieldEffect(MysteryLure.EFFECT_ID,d,replace) then return "failed", {"The MYSTERY LURE\nfailed to activate."} end
      -- A fresh activation must reroll. The choice then stays stable until
      -- this activation ends (and across save/reload).
      for _,kind in ipairs({"forest","cave","field","water"}) do
        runtime:setReusableState("mystery_lure_"..kind,nil)
      end
      runtime:setReusableState(stateKey(mapId,selectedTerrain),candidates[love.math.random(1,#candidates)])
      return "consumed", {("A strange scent spreads...\fIt will last for\n%d steps."):format(d)}, {useJingle=true}
    end,
  })

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local enc=next(encDef,ctx)
    if not enc or not runtime:isActive(MysteryLure.EFFECT_ID) or not ctx or isSafari(ctx.mapId) then return enc end
    if love.math.random() <= MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)) then
      local Game=require("src.core.Game")
      local species=chooseFor({data=Game.data,save=Game.save},ctx.mapId,ctx.terrain)
      if species then enc.species=species end
    end
    return enc
  end)

  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates)
    local enc=next(rod,mapId,candidates)
    if not enc or not runtime:isActive(MysteryLure.EFFECT_ID) or isSafari(mapId) then return enc end
    if love.math.random() <= MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)) then
      local Game=require("src.core.Game")
      local species=chooseFor({data=Game.data,save=Game.save},mapId,"fishing")
      if species then enc.species=species end
    end
    return enc
  end)

  local function installWildsCompatibility()
    if wildsWrapped or type(mod.find)~="function" then return wildsWrapped end
    local found=mod.find(WILDS_ID)
    local logic=found and found.exports and found.exports.logic
    if not (logic and type(logic.trySpawn)=="function") then return false end
    if logic._dscreteMysteryLureWrapped then wildsWrapped=true return true end
    local original=logic.trySpawn
    logic.trySpawn=function(self,game,opts)
      opts=opts or {}
      if runtime:isActive(MysteryLure.EFFECT_ID) and not opts.species and not opts.testSpawn and not opts.readinessProbe then
        local current=mod.world:current(); local mapId=(current and current.mapId) or self.activeMapId
        if not isSafari(mapId) and love.math.random()<=MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)) then
          local terrain=self.surfaceInfo and self.surfaceInfo.encounterKind or "grass"
          local species=chooseFor({data=game.data,save=game.save},mapId,terrain)
          if species then
            local forwarded={}; for k,v in pairs(opts) do forwarded[k]=v end
            forwarded.species=species
            opts=forwarded
          end
        end
      end
      return original(self,game,opts)
    end
    logic._dscreteMysteryLureWrapped=true
    wildsWrapped=true
    return true
  end

  mod.hooks:wrap("input.step", function(next, game, dt)
    local r=next(game,dt)
    if runtime.pendingExpirationNotice==MysteryLure.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then runtime.pendingExpirationNotice=nil; game.stack:push(mod.ui.TextBox.new(game,"The MYSTERY LURE\nfaded away.")) end
    end
    return r
  end)

  mod.events:on("mods.loaded",installWildsCompatibility)
  mod.events:on("game.ready",function() eligiblePool=nil; installWildsCompatibility() end)
  mod.events:on("save.loaded",function() eligiblePool=nil end)
  mod.events:on("save.created",function() eligiblePool=nil end)
  return MysteryLure
end

return MysteryLure
