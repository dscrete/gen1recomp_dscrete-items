local GlitchDetector=dofile("lib/glitch_detector.lua")
local TreasureDetector=dofile("lib/treasure_detector.lua")
local OverworldFx=dofile("lib/overworld_fx.lua")

test("Glitch Detector flash, spot, and duration presets resolve safely", function()
  local subtle=GlitchDetector.resolveFlash("subtle")
  local normal=GlitchDetector.resolveFlash("normal")
  local frequent=GlitchDetector.resolveFlash("frequent")
  eq(subtle.period,4.0)
  eq(normal.period,2.4)
  eq(frequent.period,1.2)
  check(subtle.period>normal.period and normal.period>frequent.period,
    "flash frequency should increase from subtle to frequent")
  eq(GlitchDetector.resolveFlash("bad").period,4.0)
  eq(GlitchDetector.resolveSpotCount("1"),1)
  eq(GlitchDetector.resolveSpotCount("2"),2)
  eq(GlitchDetector.resolveSpotCount("3"),3)
  eq(GlitchDetector.resolveSpotCount("5"),5)
  eq(GlitchDetector.resolveSpotCount("bad"),1)
  eq(GlitchDetector.resolveDuration("50"),50)
  eq(GlitchDetector.resolveDuration("2500"),2500)
  eq(GlitchDetector.resolveDuration("bad"),250)
end)

test("Glitch Detector state roundtrips multiple candidate spots", function()
  local encoded=GlitchDetector.encodeState("VIRIDIAN_FOREST",{{x=4,y=5},{x=8,y=9},{x=12,y=3}})
  local map,tiles=GlitchDetector.decodeState(encoded)
  eq(map,"VIRIDIAN_FOREST")
  eq(#tiles,3)
  eq(tiles[1].x,4); eq(tiles[1].y,5)
  eq(tiles[3].x,12); eq(tiles[3].y,3)
  local none,empty=GlitchDetector.decodeState(nil)
  eq(none,nil); eq(#empty,0)
end)

test("Glitch Detector candidates honor actual grass eligibility and markers", function()
  local overview={
    rows={".............",".............",".............",".............","............."},
    markers={{kind="warp",x=5,y=2},{kind="hidden",x=6,y=2}},
  }
  local grass={ ["2,2"]=true,["3,2"]=true,["4,0"]=true,["8,2"]=true,["9,2"]=true }
  local candidates=GlitchDetector.candidates(overview,4,2,function(x,y)
    return grass[tostring(x)..","..tostring(y)]==true
  end)
  check(#candidates>0)
  for _,t in ipairs(candidates) do
    local d=math.abs(t.x-4)+math.abs(t.y-2)
    check(d>=2 and d<=8,"candidate distance")
    check(grass[tostring(t.x)..","..tostring(t.y)]==true,"candidate must be grass")
    check(not (t.x==5 and t.y==2),"warp excluded")
    check(not (t.x==6 and t.y==2),"hidden marker excluded")
  end
  local picked=GlitchDetector.pickTiles(candidates,3,function(_) return 1 end)
  eq(#picked,math.min(3,#candidates))
  for i=1,#picked do
    for j=i+1,#picked do
      check(not (picked[i].x==picked[j].x and picked[i].y==picked[j].y),"spot picks stay unique")
    end
  end
end)

test("Glitch Detector forced encounter keeps a native grass level slot", function()
  local def={grass={rate=1,buckets={128,256},slots={
    {species="PIDGEY",level=4},{species="RATTATA",level=6},
  }}}
  local first=GlitchDetector.nativeEncounter(def,function() return 0 end)
  local second=GlitchDetector.nativeEncounter(def,function() return 200 end)
  eq(first.level,4)
  eq(second.level,6)
  -- Encounter frequency is deliberately irrelevant to forced anomaly battles.
  eq(first.species,"PIDGEY")
  eq(GlitchDetector.nativeEncounter({water=def.grass},function() return 0 end),nil)
end)

test("Glitch Detector Kanto pool excludes legends and later dex numbers", function()
  local pool=GlitchDetector.kantoPool({
    PIDGEY={dex=16}, CHANSEY={dex=113}, ARTICUNO={dex=144}, MEW={dex=151},
    CHIKORITA={dex=152}, MODMON={name="MODMON"},
  })
  eq(#pool,2)
  eq(pool[1],"CHANSEY")
  eq(pool[2],"PIDGEY")
end)

test("detector overlays use live camera world coordinates", function()
  local ow={camera={x=32,y=48}}
  local x,y=OverworldFx.worldCellToScreen(ow,5,6)
  eq(x,48)
  eq(y,48)
  ow.camera.x=40
  local movedX,movedY=OverworldFx.worldCellToScreen(ow,5,6)
  eq(movedX,40)
  eq(movedY,48)
end)

test("glitch overlay is injected before the world pass ends", function()
  local f=assert(io.open("lib/overworld_fx.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find("originalWorld=screen.drawWorld",1,true)~=nil,
    "overlay must wrap drawWorld, not the post-world screen draw")
  check(src:find("setAnomalyFlashProvider",1,true)~=nil,
    "glitch flash cadence must be configurable")
  check(src:find("There is deliberately no permanent tell",1,true)~=nil,
    "guaranteed anomalies should only reveal themselves intermittently")
end)

test("Glitch Detector ends after the first triggered anomaly", function()
  local f=assert(io.open("lib/glitch_detector.lua","r"))
  local src=f:read("*a"); f:close()
  check(src:find("runtime:clearFieldEffect()",1,true)~=nil,
    "trigger must terminate the field effect")
  check(src:find("there is no automatic reseed after the battle",1,true)~=nil,
    "single encounter rule should remain explicit")
  check(src:find("GlitchDetector.activate=function",1,true)~=nil,
    "future scripted/curse activation seam")
end)

test("Treasure Detector finds nearest uncollected hidden marker", function()
  local overview={markers={
    {kind="warp",x=1,y=1},
    {kind="hidden",x=10,y=10},
    {kind="hidden",x=4,y=5},
  }}
  eq(TreasureDetector.nearestHidden(overview,4,3),2)
  eq(TreasureDetector.nearestHidden({markers={}},4,3),nil)
end)

test("Treasure Detector distance bands get stronger nearby without text payloads", function()
  eq(TreasureDetector.bandForDistance(nil).name,"NO SIGNAL")
  eq(TreasureDetector.bandForDistance(15).name,"NO SIGNAL")
  eq(TreasureDetector.bandForDistance(10).name,"FAINT")
  eq(TreasureDetector.bandForDistance(6).name,"SIGNAL")
  eq(TreasureDetector.bandForDistance(3).name,"STRONG")
  eq(TreasureDetector.bandForDistance(1).name,"VERY STRONG")
  eq(TreasureDetector.bandForDistance(0).name,"DIRECTLY HERE")
  eq(TreasureDetector.bandForDistance(3).text,nil)
end)

test("Treasure Detector proximity bands have distinct electronic signatures", function()
  eq(TreasureDetector.SOUND_FALLBACK,"Switch")
  local faint=TreasureDetector.patternForRank(1)
  local signal=TreasureDetector.patternForRank(2)
  local strong=TreasureDetector.patternForRank(3)
  local very=TreasureDetector.patternForRank(4)
  local here=TreasureDetector.patternForRank(5)
  eq(#faint.tones,1)
  eq(#signal.tones,2)
  eq(#strong.tones,2)
  eq(#very.tones,3)
  eq(#here.tones,4)
  check(here.tones[1]>very.tones[1] and very.tones[1]>faint.tones[1],
    "closer bands should move to clearly higher tones")
  check(here.tones[1]~=here.tones[2],
    "directly-here pattern should alternate pitches")
  check(here.spacing<signal.spacing,
    "nearer patterns should sound denser")
end)
