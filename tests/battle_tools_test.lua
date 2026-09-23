local PrototypeBall=dofile("lib/prototype_ball.lua")
local ExpBattery=dofile("lib/exp_battery.lua")

local function fakeMod()
  local effects,balls,hooks={},{},{}
  return {
    content={
      item_effects={register=function(_,id,def) effects[id]=def end},
      balls={register=function(_,id,def) balls[id]=def end},
    },
    hooks={wrap=function(_,id,fn) hooks[id]=fn end},
  },effects,balls,hooks
end

local function fakeRuntime()
  local saved={}
  local runtime={pendingExpMultiplier=nil}
  function runtime:getReusableState(key,default)
    local value=saved[key]
    if value==nil then return default end
    return value
  end
  function runtime:setReusableState(key,value) saved[key]=value end
  return runtime,saved
end

test("Prototype Ball doubles only a statused target's effective catch rate",function()
  local def={catchRate=75}
  local rate,boosted=PrototypeBall.effectiveCatchRate({status=nil},def,nil)
  eq(rate,75); eq(boosted,false)
  rate,boosted=PrototypeBall.effectiveCatchRate({status="PAR"},def,nil)
  eq(rate,150); eq(boosted,true)
  rate=PrototypeBall.effectiveCatchRate({status="SLP"},{catchRate=200},nil)
  eq(rate,255,"status boost must clamp to the Gen-1 catch-rate byte")
  rate=PrototypeBall.effectiveCatchRate({status="BRN"},def,40)
  eq(rate,80,"an existing rate override remains the baseline")
end)

test("Prototype Ball registers Poké Ball baseline math and delegates the stock roll",function()
  local mod,effects,balls=fakeMod()
  PrototypeBall.install(mod)
  local ball=balls[PrototypeBall.ITEM_ID]
  eq(ball.randMax,255)
  eq(ball.hpFactor,12)
  eq(ball.wobbleFactor,255)
  eq(ball.tossAnim,"TOSS_ANIM")
  local observed
  local caught,shakes=ball.attempt({
    targetMon={status="PSN"}, targetDef={catchRate=60}, rateOverride=nil,
    vanillaAttempt=function()
      observed=120
      return "caught",3
    end,
  })
  eq(observed,120)
  eq(caught,"caught"); eq(shakes,3)
  local use=effects[PrototypeBall.ITEM_EFFECT_ID]
  eq(use.field,false); eq(use.battle,true); eq(use.needsTarget,false)
  eq(use.use(),"ball")
end)

test("EXP Battery multiplier is deterministic",function()
  eq(ExpBattery.multiply(50),100)
  eq(ExpBattery.multiply(51,1.5),76)
  eq(ExpBattery.multiply(0),0)
end)

test("EXP Battery arms persistently and refuses a second charge",function()
  local mod,effects,_,hooks=fakeMod()
  local runtime,saved=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  local effect=effects[ExpBattery.ITEM_EFFECT_ID]
  eq(effect.field,true); eq(effect.battle,false); eq(effect.needsTarget,false)
  local result=effect.use()
  eq(result,"consumed")
  check(battery.isArmed())
  check(type(saved[ExpBattery.STATE_KEY])=="table")
  eq(saved[ExpBattery.STATE_KEY].multiplier,2)
  result=effect.use()
  eq(result,"failed","using another Battery while armed must not consume it")
  check(hooks["battle.exp_award"] and hooks["exp.gain"])
end)

test("EXP Battery doubles every share from one award then disarms",function()
  local mod,effects,_,hooks=fakeMod()
  local runtime=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  effects[ExpBattery.ITEM_EFFECT_ID].use()
  local first,second
  hooks["battle.exp_award"](function(ctx)
    first=hooks["exp.gain"](function() return 80 end,{mon={species="PIKACHU"}})
    second=hooks["exp.gain"](function() return 25 end,{mon={species="BULBASAUR"}})
  end,{battle={}})
  eq(first,160)
  eq(second,50)
  check(not battery.isArmed(),"the charge is spent after a real EXP distribution")
  eq(runtime.pendingExpMultiplier,nil,"the transient multiplier must not leak")

  local later=hooks["exp.gain"](function() return 40 end,{})
  eq(later,40,"later EXP awards remain vanilla")
end)

test("EXP Battery stays armed if an award produces no positive EXP gain",function()
  local mod,effects,_,hooks=fakeMod()
  local runtime=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  effects[ExpBattery.ITEM_EFFECT_ID].use()
  hooks["battle.exp_award"](function() end,{battle={}})
  check(battery.isArmed())
end)
