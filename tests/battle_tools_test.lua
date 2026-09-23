local PrototypeBall=dofile("lib/prototype_ball.lua")
local ExpBattery=dofile("lib/exp_battery.lua")

local function fakeMod()
  local effects,balls,hooks,events={},{},{},{}
  return {
    content={
      item_effects={register=function(_,id,def) effects[id]=def end},
      balls={register=function(_,id,def) balls[id]=def end},
    },
    hooks={wrap=function(_,id,fn) hooks[id]=fn end},
    events={on=function(_,id,fn) events[id]=fn end},
  },effects,balls,hooks,events
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

test("Prototype Ball uses authored health bands",function()
  local def={catchRate=80}
  local cases={
    {hp=100,max=100,rate=40,mult=0.5,band="HIGH"},
    {hp=51,max=100,rate=40,mult=0.5,band="HIGH"},
    {hp=50,max=100,rate=80,mult=1.0,band="MID"},
    {hp=26,max=100,rate=80,mult=1.0,band="MID"},
    {hp=25,max=100,rate=160,mult=2.0,band="LOW"},
    {hp=11,max=100,rate=160,mult=2.0,band="LOW"},
    {hp=10,max=100,rate=240,mult=3.0,band="CRITICAL"},
    {hp=1,max=100,rate=240,mult=3.0,band="CRITICAL"},
  }
  for _,c in ipairs(cases) do
    local rate,mult,band=PrototypeBall.effectiveCatchRate(
      {hp=c.hp,stats={hp=c.max}},def,nil)
    eq(rate,c.rate,"rate at "..c.hp.."/"..c.max)
    eq(mult,c.mult,"multiplier at "..c.hp.."/"..c.max)
    eq(band,c.band,"band at "..c.hp.."/"..c.max)
  end
end)

test("Prototype Ball clamps low-HP power and respects existing rate overrides",function()
  local rate=PrototypeBall.effectiveCatchRate(
    {hp=5,stats={hp=100}},{catchRate=200},nil)
  eq(rate,255,"critical-HP boost must clamp to the Gen-1 catch-rate byte")
  rate=PrototypeBall.effectiveCatchRate(
    {hp=100,stats={hp=100}},{catchRate=200},40)
  eq(rate,20,"high-HP drawback applies to an existing catch-rate override")
  rate=PrototypeBall.effectiveCatchRate(
    {hp=10,stats={hp=100}},{catchRate=200},40)
  eq(rate,120,"critical-HP bonus applies to an existing catch-rate override")
end)

test("Prototype Ball keeps Poké Ball factors and delegates stock HP/status math",function()
  local mod,effects,balls=fakeMod()
  PrototypeBall.install(mod)
  local ball=balls[PrototypeBall.ITEM_ID]
  eq(ball.randMax,255)
  eq(ball.hpFactor,12)
  eq(ball.wobbleFactor,255)
  eq(ball.tossAnim,"TOSS_ANIM")
  local observed
  local ctx
  ctx={
    targetMon={hp=6,stats={hp=60},status="PSN"}, targetDef={catchRate=60}, rateOverride=nil,
    vanillaAttempt=function()
      observed=ctx.rateOverride
      return "caught",3
    end,
  }
  local caught,shakes=ball.attempt(ctx)
  eq(observed,180,"critical health must pass the 3x rate into vanilla math")
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
  local mod,effects,_,hooks,events=fakeMod()
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
  check(hooks["exp.gain"])
  check(events["battle.started"] and events["battle.turn_ended"] and events["battle.ended"])
  check(not hooks["battle.exp_award"],"minimum-engine implementation must not depend on the newer award hook")
end)

test("EXP Battery doubles every share from one defeated Pokemon then disarms",function()
  local mod,effects,_,hooks,events=fakeMod()
  local runtime=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  effects[ExpBattery.ITEM_EFFECT_ID].use()
  local battle={}
  events["battle.started"]({battle=battle})
  local first=hooks["exp.gain"](function() return 80 end,{mon={species="PIKACHU"}})
  local second=hooks["exp.gain"](function() return 25 end,{mon={species="BULBASAUR"}})
  eq(first,160)
  eq(second,50)
  check(battery.isArmed(),"the charge stays live through every share in the payout")
  eq(runtime.pendingExpMultiplier,2)
  events["battle.turn_ended"]({battle=battle})
  check(not battery.isArmed(),"the charge is spent after the payout turn finishes")
  eq(runtime.pendingExpMultiplier,nil,"the transient multiplier must not leak")

  local later=hooks["exp.gain"](function() return 40 end,{})
  eq(later,40,"later EXP awards remain vanilla")
end)

test("EXP Battery stays armed through turns with no positive EXP gain",function()
  local mod,effects,_,hooks,events=fakeMod()
  local runtime=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  effects[ExpBattery.ITEM_EFFECT_ID].use()
  local battle={}
  events["battle.started"]({battle=battle})
  events["battle.turn_ended"]({battle=battle})
  check(battery.isArmed())
  eq(hooks["exp.gain"](function() return 0 end,{}),0)
  events["battle.turn_ended"]({battle=battle})
  check(battery.isArmed())
end)

test("EXP Battery clears a used charge if battle ends during the payout turn",function()
  local mod,effects,_,hooks,events=fakeMod()
  local runtime=fakeRuntime()
  local battery=ExpBattery.install(mod,runtime)
  effects[ExpBattery.ITEM_EFFECT_ID].use()
  local battle={}
  events["battle.started"]({battle=battle})
  eq(hooks["exp.gain"](function() return 33 end,{}),66)
  events["battle.ended"]({battle=battle})
  check(not battery.isArmed())
  eq(runtime.pendingExpMultiplier,nil)
end)
