local MysteryLure = {}

MysteryLure.EFFECT_ID = "mystery_lure"
MysteryLure.ITEM_EFFECT_ID = "DS_MYSTERY_LURE_EFFECT"
MysteryLure.SHARE_OPTION = "mystery_lure_share"
MysteryLure.STEPS_OPTION = "mystery_lure_steps"
MysteryLure.SEEN_ONLY_OPTION = "mystery_lure_seen_only"

local SHARES = { low=0.05, medium=0.10, high=0.20 }
local DURATIONS = { [50]=true,[100]=true,[250]=true,[500]=true,[1000]=true,[2500]=true }
local LEGENDARY = { ARTICUNO=true, ZAPDOS=true, MOLTRES=true, MEWTWO=true, MEW=true }
local POOLS = {
  forest = { "CATERPIE","METAPOD","BUTTERFREE","WEEDLE","KAKUNA","BEEDRILL","PIDGEY","PIKACHU","ODDISH","BELLSPROUT","PARAS","VENONAT","EXEGGCUTE","SCYTHER","PINSIR" },
  cave = { "ZUBAT","GOLBAT","GEODUDE","GRAVELER","ONIX","MACHOP","MACHOKE","PARAS","CLEFAIRY","DIGLETT","DUGTRIO","CUBONE","MAROWAK","RHYHORN" },
  water = { "MAGIKARP","GOLDEEN","SEAKING","POLIWAG","POLIWHIRL","TENTACOOL","TENTACRUEL","HORSEA","SEADRA","SHELLDER","KRABBY","KINGLER","STARYU","PSYDUCK","SLOWPOKE" },
  field = { "PIDGEY","RATTATA","SPEAROW","EKANS","SANDSHREW","NIDORAN_F","NIDORAN_M","JIGGLYPUFF","MEOWTH","MANKEY","GROWLITHE","VULPIX","ABRA","DROWZEE","FARFETCHD","TAUROS","DITTO" },
}

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

local function seen(save, species)
  local dex=save and save.pokedex
  return dex and ((dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])) or false
end

function MysteryLure.candidates(data, save, mapId, terrain, seenOnly)
  local out={}
  for _,species in ipairs(POOLS[habitat(mapId,terrain)] or POOLS.field) do
    if not LEGENDARY[species] and data and data.pokemon and data.pokemon[species]
        and (not seenOnly or seen(save,species)) then out[#out+1]=species end
  end
  return out
end

function MysteryLure.install(mod, runtime)
  local function chooseFor(ctx, terrain)
    local current = mod.world:current(); local mapId=current and current.mapId
    local seenOnly = tostring(mod.options:get(MysteryLure.SEEN_ONLY_OPTION)) ~= "all"
    local pool = MysteryLure.candidates(ctx.data, ctx.save, mapId, terrain, seenOnly)
    if #pool==0 then return nil end
    local key = "mystery_lure_"..habitat(mapId,terrain)
    local existing = runtime:getReusableState(key,nil)
    for _,s in ipairs(pool) do if s==existing then return s end end
    local pick = pool[love.math.random(1,#pool)]
    runtime:setReusableState(key,pick)
    return pick
  end

  mod.content.item_effects:register(MysteryLure.ITEM_EFFECT_ID, {
    needsTarget=false, field=true, battle=false,
    use=function(ctx)
      local current=mod.world:current(); if current and isSafari(current.mapId) then return "failed", {"The MYSTERY LURE\nwon't work here."} end
      local species=chooseFor(ctx,"grass") or chooseFor(ctx,"water")
      if not species then return "failed", {"No mysterious signal\nanswers the lure."} end
      if runtime.activeFieldEffect==MysteryLure.EFFECT_ID then return "failed", {"MYSTERY LURE is\nalready active."} end
      local replace=false
      if runtime.activeFieldEffect then
        replace=runtime:requestFieldReplacement(MysteryLure.EFFECT_ID)
        if not replace then return "failed", {"Another field effect\nis already active.\fUse MYSTERY LURE\nagain to replace it."} end
      end
      local d=MysteryLure.resolveDuration(mod.options:get(MysteryLure.STEPS_OPTION))
      if not runtime:activateFieldEffect(MysteryLure.EFFECT_ID,d,replace) then return "failed", {"The MYSTERY LURE\nfailed to activate."} end
      return "consumed", {("A strange scent spreads...\fIt will last for\n%d steps."):format(d)}, {useJingle=true}
    end,
  })

  mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
    local enc=next(encDef,ctx)
    if not enc or not runtime:isActive(MysteryLure.EFFECT_ID) or not ctx or isSafari(ctx.mapId) then return enc end
    if love.math.random() <= MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)) then
      local fake={data=require("src.core.Game").data,save=require("src.core.Game").save}
      local species=chooseFor(fake,ctx.terrain)
      if species then enc.species=species end
    end
    return enc
  end)

  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates)
    local enc=next(rod,mapId,candidates)
    if not enc or not runtime:isActive(MysteryLure.EFFECT_ID) or isSafari(mapId) then return enc end
    if love.math.random() <= MysteryLure.resolveShare(mod.options:get(MysteryLure.SHARE_OPTION)) then
      local Game=require("src.core.Game")
      local species=chooseFor({data=Game.data,save=Game.save},"fishing")
      if species then enc.species=species end
    end
    return enc
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    local r=next(game,dt)
    if runtime.pendingExpirationNotice==MysteryLure.EFFECT_ID then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then runtime.pendingExpirationNotice=nil; game.stack:push(mod.ui.TextBox.new(game,"The MYSTERY LURE\nfaded away.")) end
    end
    return r
  end)
end

return MysteryLure
