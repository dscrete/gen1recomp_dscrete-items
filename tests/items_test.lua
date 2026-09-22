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
    if item.itemId then
      check(not ids[item.itemId], "duplicate item id " .. item.itemId)
      ids[item.itemId] = true
    end
  end
end)

test("permanent gadgets do not occupy bag slots", function()
  for _, item in ipairs(Items.permanent()) do
    eq(item.itemId, nil, item.key .. " should not be a bag item")
  end
end)

test("Prism Scent is a consumable field effect", function()
  local item = Items.byKey.prism_scent
  eq(item.itemId, "DS_PRISM_SCENT")
  eq(item.effect, "DS_PRISM_SCENT_EFFECT")
  eq(item.ownership, "CONSUMABLE")
  eq(item.effectKind, "FIELD_EFFECT")
  check(item.implemented)
end)

test("Elusive Scent is a consumable field effect", function()
  local item = Items.byKey.elusive_scent
  eq(item.itemId, "DS_ELUSIVE_SCENT")
  eq(item.effect, "DS_ELUSIVE_SCENT_EFFECT")
  eq(item.ownership, "CONSUMABLE")
  eq(item.effectKind, "FIELD_EFFECT")
  check(item.implemented)
end)

test("Silph Tracker is a permanent gadget", function()
  local item = Items.byKey.silph_tracker
  eq(item.itemId, nil)
  eq(item.ownership, "PERMANENT")
  eq(item.effectKind, "TOOL")
  check(item.implemented)
end)

test("implemented filters exclude catalogue-only future items", function()
  local consumables = Items.consumables(true)
  eq(#consumables, 2)
  eq(consumables[1].key, "prism_scent")
  eq(consumables[2].key, "elusive_scent")

  local gadgets = Items.permanent(true)
  eq(#gadgets, 1)
  eq(gadgets[1].key, "silph_tracker")
end)
