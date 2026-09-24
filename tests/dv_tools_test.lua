local DvTools=dofile("lib/dv_tools.lua")
local DNAStabilizer=dofile("lib/dna_stabilizer.lua")
local MutationCapsule=dofile("lib/mutation_capsule.lua")

local SHINY_ATK={ [2]=true,[3]=true,[6]=true,[7]=true,[10]=true,[11]=true,[14]=true,[15]=true }
local function isShiny(d)
  return type(d)=="table" and d.defense==10 and d.speed==10 and d.special==10
    and SHINY_ATK[d.attack]==true
end

local function mon(dvs)
  return { species="TESTMON", level=20, nickname="TESTY", catchRate=45,
    dvs=dvs, statExp={hp=0,attack=0,defense=0,speed=0,special=0},
    stats={hp=50,attack=30,defense=30,speed=30,special=30}, hp=50 }
end

test("DV helpers derive HP DV from the four stored primary DVs",function()
  local d=DvTools.copy({attack=3,defense=10,speed=10,special=10,hp=0})
  eq(d.attack,3)
  eq(d.hp,8,"odd attack should contribute the HP high bit")
  check(isShiny(d),"copied shiny DV shape should remain shiny")
end)

test("DNA Stabilizer improves non-shiny primary DVs by one with a hard cap",function()
  local m=mon({attack=1,defense=14,speed=15,special=0,hp=0})
  local p=DNAStabilizer.plan(m,isShiny,DvTools)
  check(p,"non-maxed mon should be eligible")
  eq(p.after.attack,2)
  eq(p.after.defense,15)
  eq(p.after.speed,15)
  eq(p.after.special,1)
  eq(p.after.hp,DvTools.hpDV(p.after))
end)

test("DNA Stabilizer preserves an existing shiny and only advances shiny-safe Attack",function()
  local m=mon({attack=3,defense=10,speed=10,special=10,hp=8})
  local p=DNAStabilizer.plan(m,isShiny,DvTools)
  check(p and p.shinyBefore and p.shinyAfter,"shiny must remain shiny")
  eq(p.after.attack,6,"Attack should advance to next engine-valid shiny value")
  eq(p.after.defense,10)
  eq(p.after.speed,10)
  eq(p.after.special,10)

  local maxed=mon({attack=15,defense=10,speed=10,special=10,hp=8})
  eq(DNAStabilizer.plan(maxed,isShiny,DvTools),nil,"max shiny has no safe improvement")
end)

test("DV application recalculates stats without healing damaged or fainted Pokemon",function()
  local data={pokemon={TESTMON={baseStats={hp=40,attack=40,defense=40,speed=40,special=40}}}}
  local Stats={calc=function(_,_,dvs)
    return {hp=50+dvs.hp,attack=30+dvs.attack,defense=30+dvs.defense,
      speed=30+dvs.speed,special=30+dvs.special}
  end}

  local full=mon({attack=1,defense=1,speed=1,special=1,hp=15})
  full.stats.hp=65; full.hp=65
  check(DvTools.apply(data,full,{attack=2,defense=2,speed=2,special=2},Stats))
  eq(full.hp,50,"full-health mon should stay full at its new maximum")

  local hurt=mon({attack=0,defense=0,speed=0,special=0,hp=0})
  hurt.hp=17
  DvTools.apply(data,hurt,{attack=1,defense=1,speed=1,special=1},Stats)
  eq(hurt.hp,17,"damage should not be healed")

  local fainted=mon({attack=0,defense=0,speed=0,special=0,hp=0})
  fainted.hp=0
  DvTools.apply(data,fainted,{attack=1,defense=1,speed=1,special=1},Stats)
  eq(fainted.hp,0,"fainted mon must stay fainted")
end)

test("Mutation Capsule rerolls exactly one primary DV to a different value",function()
  local m=mon({attack=4,defense=5,speed=7,special=8,hp=0})
  local calls=0
  local values={3,7}
  local offer=MutationCapsule.rollOffer(m,function()
    calls=calls+1
    return values[calls]
  end,DvTools)
  eq(offer.stat,"speed")
  eq(offer.value,8,"raw roll equal to old value should skip to next allowed DV")
end)

local function fakeRuntime()
  local store={}
  return {
    getReusableState=function(_,key,default)
      local v=store[key]; if v==nil then return default end; return v
    end,
    setReusableState=function(_,key,value) store[key]=value end,
    store=store,
  }
end

test("Mutation Capsule preview is locked across cancel reopen and level changes",function()
  local runtime=fakeRuntime()
  local m=mon({attack=4,defense=5,speed=7,special=8,hp=0})
  local seq={2,0}; local i=0
  local first,sig=MutationCapsule.offerFor(runtime,m,function()
    i=i+1; return seq[i]
  end,DvTools)
  eq(first.stat,"defense")
  eq(first.value,0)

  m.level=55
  m.exp=999999
  local second,sig2=MutationCapsule.offerFor(runtime,m,function()
    error("locked preview should not reroll",0)
  end,DvTools)
  eq(sig2,sig)
  eq(second.stat,first.stat)
  eq(second.value,first.value)

  MutationCapsule.clearOffer(runtime,sig)
  eq(MutationCapsule.storedOffer(runtime,m,DvTools),nil)
end)

test("Mutation Capsule preview reports shiny creation or loss but does not silently block it",function()
  local shiny=mon({attack=3,defense=10,speed=10,special=10,hp=8})
  local p=MutationCapsule.plan(shiny,{stat="defense",value=9},isShiny,DvTools)
  check(p.shinyBefore and not p.shinyAfter,"risky preview should disclose shiny loss")

  local plain=mon({attack=2,defense=10,speed=10,special=9,hp=0})
  local p2=MutationCapsule.plan(plain,{stat="special",value=10},isShiny,DvTools)
  check(not p2.shinyBefore and p2.shinyAfter,"mutation may legitimately create shiny DVs")
end)

test("DNA tools are engine-predicate driven and contain no species whitelist",function()
  local f=assert(io.open("lib/dna_stabilizer.lua","r")); local stabilizer=f:read("*a"); f:close()
  local g=assert(io.open("lib/mutation_capsule.lua","r")); local mutation=g:read("*a"); g:close()
  check(stabilizer:find("Stats.isShiny",1,true),"Stabilizer must use engine shiny predicate")
  check(mutation:find("Stats.isShiny",1,true),"Mutation preview must use engine shiny predicate")
  for _,name in ipairs({"PIKACHU","CHARIZARD","MEW","GYARADOS"}) do
    check(not stabilizer:find(name,1,true),"Stabilizer should not hardcode "..name)
    check(not mutation:find(name,1,true),"Mutation Capsule should not hardcode "..name)
  end
end)
