local GlitchDetector=dofile("lib/glitch_detector.lua")
local TreasureDetector=dofile("lib/treasure_detector.lua")
local OverworldFx=dofile("lib/overworld_fx.lua")

test("Glitch Detector presets resolve safely", function()
  eq(GlitchDetector.resolveRate("mild"),0.20)
  eq(GlitchDetector.resolveRate("strong"),0.40)
  eq(GlitchDetector.resolveRate("extreme"),0.60)
  eq(GlitchDetector.resolveRate("bad"),0.40)
  eq(GlitchDetector.resolveDuration("50"),50)
  eq(GlitchDetector.resolveDuration("2500"),2500)
  eq(GlitchDetector.resolveDuration("bad"),250)
end)

test("Glitch Detector state roundtrips for save load", function()
  local encoded=GlitchDetector.encodeState("VIRIDIAN_FOREST",{{x=4,y=5},{x=8,y=9},{x=12,y=3}})
  local map,tiles=GlitchDetector.decodeState(encoded)
  eq(map,"VIRIDIAN_FOREST")
  eq(#tiles,3)
  eq(tiles[1].x,4); eq(tiles[1].y,5)
  eq(tiles[3].x,12); eq(tiles[3].y,3)
  local none,empty=GlitchDetector.decodeState(nil)
  eq(none,nil); eq(#empty,0)
end)

test("Glitch Detector chooses nearby walkable tiles and avoids markers", function()
  local overview={
    rows={".............",".............",".............",".............","............."},
    markers={{kind="warp",x=5,y=2},{kind="hidden",x=6,y=2}},
  }
  local candidates=GlitchDetector.candidates(overview,4,2)
  check(#candidates>0)
  for _,t in ipairs(candidates) do
    local d=math.abs(t.x-4)+math.abs(t.y-2)
    check(d>=2 and d<=10,"candidate distance")
    check(not (t.x==5 and t.y==2),"warp excluded")
    check(not (t.x==6 and t.y==2),"hidden marker excluded")
  end
  local picked=GlitchDetector.pickTiles(candidates,3,function(_) return 1 end)
  eq(#picked,3)
  check(not (picked[1].x==picked[2].x and picked[1].y==picked[2].y),"unique picks")
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

test("Treasure Detector finds nearest uncollected hidden marker", function()
  local overview={markers={
    {kind="warp",x=1,y=1},
    {kind="hidden",x=10,y=10},
    {kind="hidden",x=4,y=5},
  }}
  eq(TreasureDetector.nearestHidden(overview,4,3),2)
  eq(TreasureDetector.nearestHidden({markers={}},4,3),nil)
end)

test("Treasure Detector distance bands get stronger nearby", function()
  eq(TreasureDetector.bandForDistance(nil).name,"NO SIGNAL")
  eq(TreasureDetector.bandForDistance(15).name,"NO SIGNAL")
  eq(TreasureDetector.bandForDistance(10).name,"FAINT")
  eq(TreasureDetector.bandForDistance(6).name,"SIGNAL")
  eq(TreasureDetector.bandForDistance(3).name,"STRONG")
  eq(TreasureDetector.bandForDistance(1).name,"VERY STRONG")
  eq(TreasureDetector.bandForDistance(0).name,"DIRECTLY HERE")
end)
