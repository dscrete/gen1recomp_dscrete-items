# DScrete Items

**DScrete Items** is a planned Gen1Recomp expansion built around strange, useful
pieces of late-1990s Pokemon technology. Rather than backporting later-generation
features, the mod adds gadgets that create new decisions and activities while
fitting the existing game's presentation.

The guiding loop is:

> find a gadget -> gain a capability -> discover a new way to play

This repository currently defines the product and implementation contract for the
mod. Integration starts with the groundwork and Shiny Finder milestones in the
[implementation checklist](docs/CHECKLIST.md).

## Design principles

1. **Gen 1 first.** Gadgets use the existing bag, text boxes, palettes, sounds, and
   animations wherever possible. New art is optional rather than a requirement.
2. **Capabilities, not conveniences.** A gadget should create a new decision or
   unlock an activity, not merely shorten a menu operation.
3. **One shared framework.** Timed field effects, encounter modifiers, permanent
   unlocks, and consumable experiments share state and hooks instead of becoming
   unrelated scripts.
4. **Respect the encounter table.** Effects bias an area's identity; they do not
   silently replace it. Exceptional encounters are curated by habitat.
5. **No guaranteed miracles.** Rare and shiny effects improve odds, but retain
   uncertainty. Gen-1-compatible shiny Pokemon must be produced through valid DVs.
6. **Distribution comes later.** Implementation does not assume how an item is
   earned. Shops, characters, locations, and activities can be designed after the
   items themselves are stable.

## Item catalogue

The **category** column assigns implementation ownership. It describes which shared
system should contain the behavior, not where or how the player receives the item.

| Item | Type | Category | Intended effect |
| --- | --- | --- | --- |
| Shiny Finder | Consumable | Encounters | Temporarily raises shiny generation to about 1 in 100 via valid shiny DVs. |
| Rare Lure | Consumable | Encounters | Biases encounters toward the rarest species already in the area's table. |
| Mystery Lure | Consumable | Encounters | Adds a small, curated habitat-specific encounter pool for a limited duration. |
| Species Whistle | Consumable | Encounters | Selects a species and raises its weight in compatible encounter tables. |
| Prototype Repel | Consumable | Encounters | Attracts encounters at or above the lead Pokemon's level. |
| Glitch Detector | Consumable | Encounters | Enables a curated temporary encounter anomaly without corrupting game state. |
| Safari Bait / Pass | Consumable | Encounters | Alters curated Safari encounters or one clearly stated Safari rule. |
| Silph Tracker | Permanent | Detection | Reports whether a selected species is absent, faint, present, or strong locally. |
| Treasure Detector | Permanent | Detection | Gives stronger feedback as the player approaches an uncollected hidden item. |
| Rocket Decoder | Permanent | Detection | Detects and decodes authored, temporary Rocket incidents. |
| Pokedex Chip | Permanent | Detection | Adds encounter statistics to Pokedex information. |
| Prototype Ball | Consumable | Battle | Applies a documented conditional modifier to the normal capture calculation. |
| EXP Battery | Consumable | Battle | Arms a bonus for a future eligible EXP award. |
| Trainer Beacon | Consumable | Battle | Allows a previously defeated, eligible trainer to be challenged again. |
| Link Cable | Consumable | Pokemon | Evolves Kadabra, Machoke, Graveler, or Haunter using the existing trade presentation. |
| Move Recorder | Consumable | Pokemon | Offers an eligible missed level-up move to the selected Pokemon. |
| Fossil Catalyst | Consumable | Pokemon | Applies a disclosed modifier during fossil revival. |
| DNA Stabilizer | Consumable | Pokemon | Improves DVs within bounded, shiny-safe rules. |
| Mutation Capsule | Consumable | Pokemon | Rerolls one random DV and previews the affected stat. |
| Blank TM | Consumable | Pokemon | Records one eligible move, then teaches it to a compatible recipient. |
| PC Transfer Unit | Consumable | Travel | Opens portable PC access once, then returns to the original map safely. |
| Emergency Teleporter | Consumable | Travel | Returns the player to the last valid Pokemon Center. |
| Map Beacon | Consumable pair | Travel | Records a valid field tile and later returns the player to it. |

Permanent gadgets live in a dedicated **GADGETS** menu and do not consume normal
bag slots. Consumables remain normal items so their cost and scarcity stay visible.
Only one encounter-modifying field effect may be active at a time; using another
asks the player to replace the current effect.

## Category ownership

- **Encounters:** encounter-table transforms, wild generation, durations, and
  habitat rules.
- **Detection:** reusable information tools and their menus or overworld feedback.
- **Battle:** capture, experience, and trainer-rematch hooks.
- **Pokemon:** moves, evolution, fossils, and DV modification.
- **Travel:** map, PC, warp, and safe-return behavior.

These boundaries are intended to remain stable as more items are added. Player-facing
sources and progression are deliberately unassigned for now.

## Scope and safety decisions

- Save data is versioned and migrated; no feature may reuse an unexplained vanilla
  byte or silently invalidate an existing save.
- Map Beacon, PC Transfer, and teleport effects are disabled in battles, link rooms,
  scripted movement, Safari transitions, and other unsafe map states.
- Trainer rematches use an explicit eligibility table. Story trainers and scripts
  are excluded unless they have a purpose-built rematch definition.
- Blank TM compatibility is data-driven and cannot bypass a species' intended move
  compatibility merely because the source Pokemon knows the move.
- Shiny generation modifies wild DVs at creation time. It does not apply a cosmetic
  flag, retroactively alter owned Pokemon, or promise that an encounter will shine.

## Delivery

The ordered source of truth is [docs/CHECKLIST.md](docs/CHECKLIST.md). After the
shared foundation, **Shiny Finder is the first item to implement**. Later items are
ordered to reuse proven hooks and infrastructure. Detailed behavioral contracts and
edge cases remain in [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).
