-- Standalone normal-wild eligibility. No companion mod or catalogue is required.
-- Build the pool from *merged normal encounter tables*, never from roaming,
-- scripted, gift, static or DScrete-injected encounters.

local Eligibility = {}

local PROTECTED_DEX = {}
local function markRanges(spec)
  for token in tostring(spec):gmatch("%S+") do
    local a,b=token:match("^(%d+)%-(%d+)$")
    if a then for n=tonumber(a),tonumber(b) do PROTECTED_DEX[n]=true end
    else PROTECTED_DEX[tonumber(token)]=true end
  end
end

-- Traditional starter evolutionary lines (Gen 1-9), not Pikachu/Eevee,
-- which legitimately occur as ordinary wild species in many games.
markRanges("1-9 152-160 252-260 387-395 495-503 650-658 722-730 810-818 906-914")
-- Legendary, mythical and Ultra Beast families through National Dex #1025.
-- Roamers are separately excluded by not reading roamMons/roamMaps.
markRanges("144-146 150-151 243-245 249-251 377-386 480-494 638-649 716-721 772-773 785-809 888-898 905 1001-1004 1007-1008 1014-1017 1024-1025")

-- Fallback for mods or fixtures that expose species IDs but omit dex numbers.
-- Form IDs inherit the base species restriction (e.g. MEWTWO_MEGA_X).
local NAMES = {}
for token in ([[
BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD SQUIRTLE WARTORTLE BLASTOISE
CHIKORITA BAYLEEF MEGANIUM CYNDAQUIL QUILAVA TYPHLOSION TOTODILE CROCONAW FERALIGATR
TREECKO GROVYLE SCEPTILE TORCHIC COMBUSKEN BLAZIKEN MUDKIP MARSHTOMP SWAMPERT
TURTWIG GROTLE TORTERRA CHIMCHAR MONFERNO INFERNAPE PIPLUP PRINPLUP EMPOLEON
SNIVY SERVINE SERPERIOR TEPIG PIGNITE EMBOAR OSHAWOTT DEWOTT SAMUROTT
CHESPIN QUILLADIN CHESNAUGHT FENNEKIN BRAIXEN DELPHOX FROAKIE FROGADIER GRENINJA
ROWLET DARTRIX DECIDUEYE LITTEN TORRACAT INCINEROAR POPPLIO BRIONNE PRIMARINA
GROOKEY THWACKEY RILLABOOM SCORBUNNY RABOOT CINDERACE SOBBLE DRIZZILE INTELEON
SPRIGATITO FLORAGATO MEOWSCARADA FUECOCO CROCALOR SKELEDIRGE QUAXLY QUAXWELL QUAQUAVAL
ARTICUNO ZAPDOS MOLTRES MEWTWO MEW RAIKOU ENTEI SUICUNE LUGIA HO_OH CELEBI
REGIROCK REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS
UXIE MESPRIT AZELF DIALGA PALKIA HEATRAN REGIGIGAS GIRATINA CRESSELIA PHIONE MANAPHY
DARKRAI SHAYMIN ARCEUS VICTINI COBALION TERRAKION VIRIZION TORNADUS THUNDURUS
RESHIRAM ZEKROM LANDORUS KYUREM KELDEO MELOETTA GENESECT XERNEAS YVELTAL
ZYGARDE DIANCIE HOOPA VOLCANION TYPE_NULL SILVALLY TAPU_KOKO TAPU_LELE TAPU_BULU
TAPU_FINI COSMOG COSMOEM SOLGALEO LUNALA NIHILEGO BUZZWOLE PHEROMOSA XURKITREE
CELESTEELA KARTANA GUZZLORD NECROZMA MAGEARNA MARSHADOW POIPOLE NAGANADEL
STAKATAKA BLACEPHALON ZERAORA MELTAN MELMETAL ZACIAN ZAMAZENTA ETERNATUS
KUBFU URSHIFU ZARUDE REGIELEKI REGIDRAGO GLASTRIER SPECTRIER CALYREX ENAMORUS
WO_CHIEN CHIEN_PAO TING_LU CHI_YU KORAIDON MIRAIDON OKIDOGI MUNKIDORI
FEZANDIPITI OGERPON TERAPAGOS PECHARUNT
]]):gmatch("%S+") do NAMES[token]=true end

local function dexNumber(def)
  if type(def)~="table" then return nil end
  return tonumber(def.dex or def.dexNo or def.nationalDex or def.nationalDexNum
    or def.pokedex or def.number)
end

function Eligibility.isProtected(species,pokemon)
  if type(species)~="string" then return true end
  local def=pokemon and pokemon[species]
  local dex=dexNumber(def)
  if dex and PROTECTED_DEX[dex] then return true end
  local id=species:gsub("^SPECIES_",""):upper()
  while id do
    if NAMES[id] then return true end
    id=id:match("^(.*)_[^_]+$")
  end
  return false
end

function Eligibility.habitat(mapId,terrain)
  if terrain=="water" or terrain=="fishing" then return "water" end
  local id=tostring(mapId or "")
  if id:find("FOREST",1,true) then return "forest" end
  if id:find("CAVE",1,true) or id:find("TUNNEL",1,true)
      or id:find("MT_MOON",1,true) then return "cave" end
  return "field"
end

local function seen(save,species)
  local dex=save and save.pokedex
  return dex and ((dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])) or false
end

local function sourceField(data,key)
  local field=data and data.field
  if field and field[key]~=nil then return field[key] end
  -- Vanilla fishing defaults are an engine facility, not another mod.
  local ok,defaults=pcall(require,"src.world.FieldDefaults")
  if ok and defaults and type(defaults.field)=="function" then
    return defaults.field(data,key)
  end
  return nil
end

local function fishCandidates(data,mapId,rod)
  local fishing=sourceField(data,"fishing") or {}
  local rule=fishing[rod]
  if not rule then return nil end
  if rule.always then return {rule.always} end
  if rule.pool then return rule.pool end
  if rule.perMap then
    local groups=sourceField(data,rule.perMap)
    return groups and groups[mapId] or nil
  end
  return nil
end

local function possibleSlots(area)
  if type(area)~="table" or (area.rate~=nil and tonumber(area.rate)==0) then return {} end
  local out,previous={},0
  for i,slot in ipairs(area.slots or {}) do
    local bound=area.buckets and tonumber(area.buckets[i])
    local hasWeight=(not area.buckets) or (bound and bound>previous)
    if bound then previous=bound end
    if hasWeight and type(slot)=="table" and slot.species then
      out[#out+1]=slot.species
    end
  end
  return out
end

local function mapEntries(mod,data,fn)
  local registry=mod and mod.content and mod.content.encounters
  if registry and type(registry.each)=="function" and type(registry.get)=="function" then
    for id in registry:each() do
      local ok,def=pcall(registry.get,registry,id)
      if ok and type(def)=="table" then fn(id,def) end
    end
  else
    for id,def in pairs((data and data.encounters) or {}) do
      if type(def)=="table" then fn(id,def) end
    end
  end
end

function Eligibility.collect(mod,data)
  local pokemon=data and data.pokemon or {}
  local all,habitats={}, { forest={}, cave={}, field={}, water={} }
  local function add(species,mapId,terrain)
    if not pokemon[species] or Eligibility.isProtected(species,pokemon) then return end
    all[species]=true
    habitats[Eligibility.habitat(mapId,terrain)][species]=true
  end
  mapEntries(mod,data,function(mapId,def)
    for _,terrain in ipairs({"grass","water"}) do
      for _,species in ipairs(possibleSlots(def[terrain])) do add(species,mapId,terrain) end
    end
    -- Other normal methods are allowed; roaming and scripted records are not.
    for _,terrain in ipairs({"rocks","fishing"}) do
      for _,species in ipairs(possibleSlots(def[terrain])) do add(species,mapId,terrain) end
    end
    local fishable=def.water~=nil or def.fishing~=nil
    if fishable then
      for _,rod in ipairs({"OLD_ROD","GOOD_ROD","SUPER_ROD"}) do
        for _,row in ipairs(fishCandidates(data,mapId,rod) or {}) do
          if row and row.species then add(row.species,mapId,"fishing") end
        end
      end
    end
  end)
  return { all=all, habitats=habitats }
end

function Eligibility.candidates(pool,pokemon,save,mapId,terrain,seenOnly)
  local out={}
  local habitats=pool and pool.habitats or {}
  local source=habitats[Eligibility.habitat(mapId,terrain)] or {}
  for species in pairs(source) do
    if not Eligibility.isProtected(species,pokemon)
        and (not seenOnly or seen(save,species)) then out[#out+1]=species end
  end
  table.sort(out)
  return out
end

function Eligibility.native(mod,data,mapId,species)
  if not mapId or not species then return false end
  local registry=mod and mod.content and mod.content.encounters
  local def
  if registry and type(registry.get)=="function" then
    local ok,value=pcall(registry.get,registry,mapId)
    if ok then def=value end
  else def=data and data.encounters and data.encounters[mapId] end
  if type(def)~="table" then return false end
  for _,terrain in ipairs({"grass","water","rocks","fishing"}) do
    for _,candidate in ipairs(possibleSlots(def[terrain])) do
      if candidate==species then return true end
    end
  end
  if def.water or def.fishing then
    for _,rod in ipairs({"OLD_ROD","GOOD_ROD","SUPER_ROD"}) do
      for _,row in ipairs(fishCandidates(data,mapId,rod) or {}) do
        if row and row.species==species then return true end
      end
    end
  end
  return false
end

return Eligibility
