local Beacon=dofile("lib/trainer_beacon.lua")
local Dialogue=dofile("lib/trainer_beacon_dialogue.lua")
local LinkCable=dofile("lib/link_cable.lua")

local function badgeSave(count)
  local save={inventory={}}
  for i=1,count do save.inventory[Beacon.BADGES[i]]=1 end
  return save
end

test("Trainer Beacon badge tiers use authored additive boosts",function()
  local cases={{0,5,1},{1,5,1},{2,10,2},{3,10,2},{4,15,3},{5,15,3},{6,20,4},{8,20,4}}
  for _,c in ipairs(cases) do
    local boost,tier=Beacon.levelBoost(badgeSave(c[1]))
    eq(boost,c[2],"boost at "..c[1].." badges")
    eq(tier,c[3],"tier at "..c[1].." badges")
  end
end)

test("Trainer Beacon preserves party composition while applying level evolutions",function()
  local data={pokemon={
    CATERPIE={evolutions={{method="LEVEL",level=7,species="METAPOD"}}},
    METAPOD={evolutions={{method="LEVEL",level=10,species="BUTTERFREE"}}},
    BUTTERFREE={evolutions={}},
    PIKACHU={evolutions={{method="ITEM",item="THUNDER_STONE",species="RAICHU"}}},
    RAICHU={evolutions={}},
    KADABRA={evolutions={{method="TRADE",species="ALAKAZAM"}}},
    ALAKAZAM={evolutions={}},
  }}
  local original={
    {species="CATERPIE",level=4},
    {species="PIKACHU",level=20},
    {species="KADABRA",level=30},
  }
  local scaled=Beacon.scaleParty(data,original,10)
  eq(#scaled,3)
  eq(scaled[1].species,"BUTTERFREE","recursive level evolutions should apply")
  eq(scaled[1].level,14)
  eq(scaled[2].species,"PIKACHU","stone evolutions must not be inferred from level")
  eq(scaled[2].level,30)
  eq(scaled[3].species,"KADABRA","trade evolutions must not be inferred from level")
  eq(original[1].species,"CATERPIE","original trainer party must stay untouched")
end)

test("Trainer Beacon level boosts clamp to 100 and strongest lookup uses generated party",function()
  local data={pokemon={RATTATA={name="RATTATA",evolutions={}},RATICATE={name="RATICATE",evolutions={}}}}
  local scaled=Beacon.scaleParty(data,{{species="RATTATA",level=95},{species="RATICATE",level=70}},20)
  eq(scaled[1].level,100)
  eq(Beacon.strongestName(data,scaled),"RATTATA")
end)

test("Trainer Beacon excludes story classes but supports explicit target overrides",function()
  check(Beacon.classEligible("OPP_BUG_CATCHER","ROUTE_3",2))
  check(not Beacon.classEligible("OPP_BROCK","PEWTER_GYM",1))
  check(not Beacon.classEligible("OPP_ROCKET","ROCKET_HIDEOUT_B1F",3))
  Beacon.setTrainerEligibility("PEWTER_GYM",1,true)
  check(Beacon.classEligible("OPP_BROCK","PEWTER_GYM",1),"explicit whitelist should win")
  Beacon.setTrainerEligibility("ROUTE_3",2,false)
  check(not Beacon.classEligible("OPP_BUG_CATCHER","ROUTE_3",2),"explicit blacklist should win")
end)

test("Trainer Beacon cooldown state is per trainer and step based",function()
  local state={clock=125,trainers={a={readyAt=625},b={readyAt=100}}}
  eq(Beacon.remainingCooldown(state,"a"),500)
  eq(Beacon.remainingCooldown(state,"b"),0)
  eq(Beacon.remainingCooldown(state,"missing"),0)
end)

test("Trainer Beacon dialogue ships exactly ten first and ten later variants per class",function()
  local classes=Dialogue.supportedClasses()
  check(#classes>=20,"expected broad ordinary trainer-class coverage")
  for _,classId in ipairs(classes) do
    eq(#Dialogue.variants(classId,"first"),10,classId.." first")
    eq(#Dialogue.variants(classId,"later"),10,classId.." later")
  end
  eq(#Dialogue.variants("OPP_FAKE_MOD_CLASS","first"),10,"modded fallback first")
  eq(#Dialogue.variants("OPP_FAKE_MOD_CLASS","later"),10,"modded fallback later")
end)

test("Trainer Beacon dialogue substitutes generated strongest Pokemon and fits Gen 1 width",function()
  local text=Dialogue.render("My {STRONGEST} is ready this time.",{STRONGEST="BUTTERFREE"})
  check(text:find("BUTTERFREE",1,true),"strongest Pokemon token should resolve")
  check(not text:find("{STRONGEST}",1,true),"raw token should not remain")
  for line in text:gmatch("[^\n\f]+") do
    check(#line<=18,"dialogue line wider than 18 chars: "..line)
  end
end)

test("Link Cable asks merged evolution methods for semantic trade eligibility",function()
  local tradeCalls,customCalls=0,0
  local game={data={pokemon={
    KADABRA={name="KADABRA",evolutions={{method="TRADE",species="ALAKAZAM"}}},
    ALAKAZAM={name="ALAKAZAM",evolutions={}},
    FOOMON={name="FOOMON",evolutions={{method="MOD_LINK",species="BARMON"}}},
    BARMON={name="BARMON",evolutions={}},
    PIKACHU={name="PIKACHU",evolutions={{method="ITEM",item="THUNDER_STONE",species="RAICHU"}}},
    RAICHU={name="RAICHU",evolutions={}},
  },evolution_methods={
    TRADE={check=function(_,_,_,trigger) tradeCalls=tradeCalls+1; return trigger.kind=="trade" end},
    MOD_LINK={check=function(_,_,_,trigger) customCalls=customCalls+1; return trigger.kind=="trade" end},
    ITEM={check=function(_,_,evo,trigger) return trigger.kind=="item" and trigger.item==evo.item end},
  }}}
  local to=LinkCable.tradeTarget(game,{species="KADABRA"})
  eq(to,"ALAKAZAM")
  to=LinkCable.tradeTarget(game,{species="FOOMON"})
  eq(to,"BARMON","custom semantic trade method should work without a species list")
  to=LinkCable.tradeTarget(game,{species="PIKACHU"})
  eq(to,nil,"non-trade evolution should not qualify")
  check(tradeCalls>0 and customCalls>0)
end)

test("Link Cable selector exposes only eligible party Pokemon",function()
  local game={save={party={{species="KADABRA"},{species="PIKACHU"},{species="FOOMON"}}},data={pokemon={
    KADABRA={name="KADABRA",evolutions={{method="TRADE",species="ALAKAZAM"}}},
    ALAKAZAM={name="ALAKAZAM",evolutions={}},
    PIKACHU={name="PIKACHU",evolutions={}},
    FOOMON={name="FOOMON",evolutions={{method="CUSTOM",species="BARMON"}}},
    BARMON={name="BARMON",evolutions={}},
  },evolution_methods={
    TRADE={check=function(_,_,_,trigger) return trigger.kind=="trade" end},
    CUSTOM={check=function(_,_,_,trigger) return trigger.kind=="trade" end},
  }}}
  local rows=LinkCable.eligibleParty(game)
  eq(#rows,2)
  eq(rows[1].slot,1); eq(rows[1].to,"ALAKAZAM")
  eq(rows[2].slot,3); eq(rows[2].to,"BARMON")
end)

test("Link Cable implementation does not hardcode vanilla trade species",function()
  local f=assert(io.open("lib/link_cable.lua","r")); local source=f:read("*a"); f:close()
  for _,name in ipairs({"KADABRA","MACHOKE","GRAVELER","HAUNTER"}) do
    check(not source:find(name,1,true),"Link Cable should not hardcode "..name)
  end
  check(source:find('kind = "trade"',1,true),"semantic trade trigger must remain explicit")
  check(source:find('"TRADE"',1,true),"native evolution screen should receive trade semantics")
end)
