-- Canonical DScrete item catalogue.
--
-- Ownership describes storage. Family describes theme, not acquisition.
-- Consumables are registered as real Gen1Recomp bag items; permanent and
-- reusable gadgets live in mod.save and will be surfaced through GADGETS UI.

local Items = {}

Items.OWNERSHIP = { PERMANENT=true, REUSABLE=true, CONSUMABLE=true, CONSUMABLE_PAIR=true }
Items.FAMILY = { OAK_PALLET=true, SILPH_CO=true, CINNABAR_LAB=true, SAFARI_ZONE=true, ROCKET=true, EXPLORATION=true }
Items.EFFECT_KIND = { FIELD_EFFECT=true, TOOL=true, TRAINER=true, CAPTURE=true, BATTLE=true, POKEMON=true, TRAVEL=true }

Items.all = {
  { key="prism_scent", itemId="DS_PRISM_SCENT", name="PRISM SCENT", ownership="CONSUMABLE", family="OAK_PALLET", effectKind="FIELD_EFFECT", effect="DS_PRISM_SCENT_EFFECT", implemented=true },
  { key="elusive_scent", itemId="DS_ELUSIVE_SCENT", name="ELUSIVE SCENT", ownership="CONSUMABLE", family="OAK_PALLET", effectKind="FIELD_EFFECT", effect="DS_ELUSIVE_SCENT_EFFECT", implemented=true },
  { key="mystery_lure", itemId="DS_MYSTERY_LURE", name="MYSTERY LURE", ownership="CONSUMABLE", family="OAK_PALLET", effectKind="FIELD_EFFECT", effect="DS_MYSTERY_LURE_EFFECT", implemented=true },
  { key="species_whistle", itemId="DS_SPECIES_WHISTLE", name="PKMN WHISTLE", ownership="CONSUMABLE", family="OAK_PALLET", effectKind="FIELD_EFFECT", effect="DS_SPECIES_WHISTLE_EFFECT", implemented=true },
  { key="silph_tracker", name="SILPH TRACKER", ownership="PERMANENT", family="SILPH_CO", effectKind="TOOL", implemented=true },
  { key="treasure_detector", name="TREASURE DET.", ownership="PERMANENT", family="EXPLORATION", effectKind="TOOL" },
  { key="trainer_beacon", itemId="DS_TRAINER_BEACON", name="TRAINER BEACON", ownership="CONSUMABLE", family="SILPH_CO", effectKind="TRAINER" },
  { key="prototype_ball", itemId="DS_PROTOTYPE_BALL", name="PROTO BALL", ownership="CONSUMABLE", family="SILPH_CO", effectKind="CAPTURE" },
  { key="prototype_repel", itemId="DS_PROTOTYPE_REPEL", name="PROTO REPEL", ownership="CONSUMABLE", family="SILPH_CO", effectKind="FIELD_EFFECT" },
  { key="exp_battery", itemId="DS_EXP_BATTERY", name="EXP BATTERY", ownership="CONSUMABLE", family="SILPH_CO", effectKind="BATTLE" },
  { key="link_cable", itemId="DS_LINK_CABLE", name="LINK CABLE", ownership="CONSUMABLE", family="SILPH_CO", effectKind="POKEMON" },
  { key="pc_transfer_unit", itemId="DS_PC_TRANSFER", name="PC TRANSFER", ownership="CONSUMABLE", family="SILPH_CO", effectKind="TRAVEL" },
  { key="blank_tm", itemId="DS_BLANK_TM", name="BLANK TM", ownership="CONSUMABLE", family="SILPH_CO", effectKind="POKEMON" },
  { key="emergency_teleporter", itemId="DS_TELEPORTER", name="TELEPORTER", ownership="CONSUMABLE", family="SILPH_CO", effectKind="TRAVEL" },
  { key="map_beacon", itemId="DS_MAP_BEACON", name="MAP BEACON", ownership="CONSUMABLE_PAIR", family="EXPLORATION", effectKind="TRAVEL" },
  { key="move_recorder", itemId="DS_MOVE_RECORDER", name="MOVE RECORDER", ownership="CONSUMABLE", family="CINNABAR_LAB", effectKind="POKEMON" },
  { key="fossil_catalyst", itemId="DS_FOSSIL_CATALYST", name="FOSSIL CAT.", ownership="CONSUMABLE", family="CINNABAR_LAB", effectKind="POKEMON" },
  { key="dna_stabilizer", itemId="DS_DNA_STABILIZER", name="DNA STABILIZER", ownership="CONSUMABLE", family="CINNABAR_LAB", effectKind="POKEMON" },
  { key="mutation_capsule", itemId="DS_MUTATION_CAPSULE", name="MUTATE CAP.", ownership="CONSUMABLE", family="CINNABAR_LAB", effectKind="POKEMON" },
  { key="glitch_detector", itemId="DS_GLITCH_DETECTOR", name="GLITCH DET.", ownership="CONSUMABLE", family="CINNABAR_LAB", effectKind="FIELD_EFFECT" },
  { key="safari_bait_pass", itemId="DS_SAFARI_KIT", name="SAFARI KIT", ownership="CONSUMABLE", family="SAFARI_ZONE", effectKind="FIELD_EFFECT" },
  { key="rocket_decoder", name="ROCKET DECODER", ownership="PERMANENT", family="ROCKET", effectKind="TOOL" },
  { key="pokedex_chip", name="POKEDEX CHIP", ownership="PERMANENT", family="OAK_PALLET", effectKind="TOOL" },
}

Items.byKey, Items.byItemId = {}, {}
for _, item in ipairs(Items.all) do
  assert(not Items.byKey[item.key], "duplicate DScrete item key: " .. item.key)
  assert(Items.OWNERSHIP[item.ownership], "invalid ownership: " .. tostring(item.ownership))
  assert(Items.FAMILY[item.family], "invalid family: " .. tostring(item.family))
  assert(Items.EFFECT_KIND[item.effectKind], "invalid effect kind: " .. tostring(item.effectKind))
  Items.byKey[item.key] = item
  if item.itemId then
    assert(not Items.byItemId[item.itemId], "duplicate bag item id: " .. item.itemId)
    Items.byItemId[item.itemId] = item
  end
end

function Items.registerBagItems(mod)
  for _, item in ipairs(Items.all) do
    if item.itemId then
      local def = { id=item.itemId, name=item.name, price=0, keyItem=false, tossable=true }
      if item.effect then def.effect = item.effect end
      mod.content.items:register(item.itemId, def)
    end
  end
end

function Items.permanent(implementedOnly)
  local out = {}
  for _, item in ipairs(Items.all) do
    if (item.ownership == "PERMANENT" or item.ownership == "REUSABLE")
        and (not implementedOnly or item.implemented) then out[#out+1] = item end
  end
  return out
end

function Items.consumables(implementedOnly)
  local out = {}
  for _, item in ipairs(Items.all) do
    if item.itemId and (not implementedOnly or item.implemented) then out[#out+1] = item end
  end
  return out
end

return Items
