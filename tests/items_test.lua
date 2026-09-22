local Items = dofile("lib/items.lua")

test("catalogue has unique valid metadata", function()
  local keys, ids = {}, {}
  check(#Items.all >= 20, "expected the base gadget catalogue")
  for _, item in ipairs(Items.all) do
    check(not keys[item.key], "duplicate key " .. item.key)
    keys[item.key] = true
    check(Items.OWNERSHIP[item.ownership], "bad ownership " .. item.key)
    check(Items.FAMILY[item.family], "bad family " .. item.key)
    check(Items.EFFECT_KIND[item.effectKind], "bad effect kind " .. item.key)
    if item.itemId then check(not ids[item.itemId], "duplicate item id " .. item.itemId); ids[item.itemId] = true end
  end
end)

test("permanent gadgets do not occupy bag slots", function()
  for _, item in ipairs(Items.permanent()) do eq(item.itemId, nil, item.key .. " should not be a bag item") end
end)

test("implemented encounter consumables have effects", function()
  local expected={ prism_scent="DS_PRISM_SCENT_EFFECT", elusive_scent="DS_ELUSIVE_SCENT_EFFECT",
    mystery_lure="DS_MYSTERY_LURE_EFFECT", species_whistle="DS_SPECIES_WHISTLE_EFFECT",
    prototype_resonator="DS_PROTOTYPE_RESONATOR_EFFECT", safari_kit="DS_SAFARI_KIT_EFFECT",
    glitch_detector="DS_GLITCH_DETECTOR_EFFECT" }
  for key,effect in pairs(expected) do
    local item=Items.byKey[key]
    eq(item.effect,effect,key)
    eq(item.ownership,"CONSUMABLE",key)
    eq(item.effectKind,"FIELD_EFFECT",key)
    check(item.implemented,key)
  end
end)

test("implemented permanent gadgets are tracker and treasure detector", function()
  local gadgets=Items.permanent(true)
  eq(#gadgets,2)
  eq(gadgets[1].key,"silph_tracker")
  eq(gadgets[2].key,"treasure_detector")
end)

test("implemented filters expose only built content", function()
  local consumables=Items.consumables(true)
  eq(#consumables,7)
  eq(consumables[1].key,"prism_scent")
  eq(consumables[2].key,"elusive_scent")
  eq(consumables[3].key,"mystery_lure")
  eq(consumables[4].key,"species_whistle")
  eq(consumables[5].key,"prototype_resonator")
  eq(consumables[6].key,"safari_kit")
  eq(consumables[7].key,"glitch_detector")
end)
