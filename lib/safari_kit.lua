local SafariKit = {}

SafariKit.ITEM_EFFECT_ID = "DS_SAFARI_KIT_EFFECT"
SafariKit.ITEM_ID = "DS_SAFARI_KIT"
SafariKit.BAIT_POWER_OPTION = "safari_kit_bait_power"
SafariKit.PASS_STEPS_OPTION = "safari_kit_pass_steps"
SafariKit.PASS_BALLS_OPTION = "safari_kit_pass_balls"
SafariKit.SESSION_KEY = "safari_kit"

local STRENGTHS={ mild=2,strong=4,extreme=8 }
local PASS_STEPS={ [100]=true,[250]=true,[500]=true }
local PASS_BALLS={ [3]=true,[5]=true,[10]=true }
local WILDS_ID="overworld_wild_spawns"

function SafariKit.resolveBaitStrength(v) return STRENGTHS[tostring(v or "")] or 4 end
function SafariKit.resolvePassSteps(v) local n=tonumber(v); return (n and PASS_STEPS[n]) and n or 250 end
function SafariKit.resolvePassBalls(v) local n=tonumber(v); return (n and PASS_BALLS[n]) and n or 5 end
function SafariKit.isSafari(mapId) return type(mapId)=="string" and mapId:find("SAFARI_ZONE",1,true)~=nil end
function SafariKit.isSafariInterior(mapId) return SafariKit.isSafari(mapId) and mapId~="SAFARI_ZONE_GATE" end

local function itemCount(game)
  return tonumber(game and game.save and game.save.inventory and game.save.inventory[SafariKit.ITEM_ID]) or 0
end

local function consumeOne(game)
  local save=game and game.save
  local inv=save and save.inventory
  if not inv or (tonumber(inv[SafariKit.ITEM_ID]) or 0)<=0 then return false end
  inv[SafariKit.ITEM_ID]=inv[SafariKit.ITEM_ID]-1
  if inv[SafariKit.ITEM_ID]<=0 then
    inv[SafariKit.ITEM_ID]=nil
    for i,id in ipairs(save.bagOrder or {}) do
      if id==SafariKit.ITEM_ID then table.remove(save.bagOrder,i) break end
    end
  end
  return true
end

function SafariKit.install(mod,runtime,Weights)
  local promptOpen=false
  local wildsWrapped=false

  local function sessionMode() return runtime:getReusableState(SafariKit.SESSION_KEY,nil) end
  local function setSessionMode(v) runtime:setReusableState(SafariKit.SESSION_KEY,v) end
  local function baitActive() return sessionMode()=="bait" end

  local function applyPass(game)
    local safari=game and game.save and game.save.safari
    if not safari then return false end
    safari.steps=(tonumber(safari.steps) or 0)+SafariKit.resolvePassSteps(mod.options:get(SafariKit.PASS_STEPS_OPTION))
    safari.balls=math.min(99,(tonumber(safari.balls) or 0)+SafariKit.resolvePassBalls(mod.options:get(SafariKit.PASS_BALLS_OPTION)))
    return true
  end

  local function openEntryPrompt(game)
    if promptOpen or sessionMode()~=nil then return end
    promptOpen=true
    local menu
    local rows={
      {label="BAIT",value="bait"},
      {label="PASS",value="pass"},
      {label="SAVE KIT",value="skip"},
    }
    local function finish(mode)
      if mode=="bait" then
        if consumeOne(game) then setSessionMode("bait") else setSessionMode("no_kit") end
      elseif mode=="pass" then
        if consumeOne(game) then applyPass(game); setSessionMode("pass") else setSessionMode("no_kit") end
      else
        setSessionMode("skipped")
      end
      promptOpen=false
      if menu then menu:close() end
    end
    menu=mod.ui.ListMenu.new(game,"SAFARI KIT",rows,{
      onChoose=function(row) finish(row and row.value or "skip") end,
      onCancel=function() finish("skip") end,
    })
    game.stack:push(menu)
  end

  SafariKit.openEntryPrompt=openEntryPrompt
  SafariKit.sessionMode=sessionMode
  SafariKit.baitActive=baitActive
  SafariKit.applyPass=applyPass

  mod.content.item_effects:register(SafariKit.ITEM_EFFECT_ID,{
    needsTarget=false,field=true,battle=false,
    use=function()
      return "failed", {"SAFARI KIT choices\nare made on entry."}
    end,
  })

  mod.hooks:wrap("encounter.roll",function(next,encDef,ctx)
    if not baitActive() or not ctx or not SafariKit.isSafari(ctx.mapId) then return next(encDef,ctx) end
    local boosted=Weights.boostEncounterDef(encDef,ctx.terrain,
      SafariKit.resolveBaitStrength(mod.options:get(SafariKit.BAIT_POWER_OPTION)))
    return next(boosted,ctx)
  end)

  local function installWildsCompatibility()
    if wildsWrapped or type(mod.find)~="function" then return wildsWrapped end
    local found=mod.find(WILDS_ID)
    local logic=found and found.exports and found.exports.logic
    if not (logic and type(logic.trySpawn)=="function") then return false end
    if logic._dscreteSafariKitWrapped then wildsWrapped=true return true end
    local original=logic.trySpawn
    logic.trySpawn=function(self,game,opts)
      opts=opts or {}
      local current=mod.world:current()
      local mapId=(current and current.mapId) or self.activeMapId
      if baitActive() and SafariKit.isSafari(mapId) and not opts.species
          and not opts.testSpawn and not opts.readinessProbe then
        local terrain=self.surfaceInfo and self.surfaceInfo.encounterKind or "grass"
        if terrain=="indoor" then terrain="grass" end
        local registry=mod.content and mod.content.encounters
        local ok,def=registry and pcall(registry.get,registry,mapId)
        if ok and def then
          local boosted=Weights.boostEncounterDef(def,terrain,
            SafariKit.resolveBaitStrength(mod.options:get(SafariKit.BAIT_POWER_OPTION)))
          local rows=Weights.slotWeights(Weights.terrainTable(boosted,terrain))
          if #rows>0 then
            local pick=love.math.random(0,255)
            local cumulative=0
            local chosen=rows[#rows]
            for _,row in ipairs(rows) do cumulative=cumulative+row.weight; if pick<cumulative then chosen=row break end end
            local f={}; for k,v in pairs(opts) do f[k]=v end
            f.species,f.level=chosen.species,chosen.level
            opts=f
          end
        end
      end
      return original(self,game,opts)
    end
    logic._dscreteSafariKitWrapped=true
    wildsWrapped=true
    return true
  end

  mod.hooks:wrap("input.step",function(next,game,dt)
    local r=next(game,dt)
    local current=mod.world:current()
    local mapId=current and current.mapId
    local safari=game.save and game.save.safari
    if not safari then
      if sessionMode()~=nil then setSessionMode(nil) end
      promptOpen=false
      return r
    end
    if SafariKit.isSafariInterior(mapId) and sessionMode()==nil then
      local _,busy=mod.world:availableFieldActions()
      if busy==nil then
        if itemCount(game)>0 then openEntryPrompt(game) else setSessionMode("no_kit") end
      end
    end
    return r
  end)

  mod.events:on("mods.loaded",installWildsCompatibility)
  mod.events:on("game.ready",installWildsCompatibility)
  return SafariKit
end

return SafariKit
