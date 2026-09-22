# DScrete Items

**DScrete Items** is a planned Gen1Recomp expansion built around strange, useful
pieces of late-1990s Pokemon technology. The initial goal is to implement a shared
item framework and the items themselves. How players obtain them will be designed
later, so acquisition locations, currencies, ranks, and reward systems are
intentionally out of scope for now.

## Engine compatibility

DScrete Items is a standalone **Mod API 2** mod for Gen1Recomp. It does not vendor,
fork, or bundle the engine. The authoritative integration target is:

- Gen1Recomp tag `v0.2.74`;
- upstream commit `9545ebbb839a8a7ea28472b626681154ab222623`;
- game target `gen1`; and
- supported engine range `>=0.2.74 <0.3.0`.

The compatibility contract is machine-readable in [`manifest.json`](manifest.json).
Development and integration testing use a separate Gen1Recomp checkout with this
repository placed or symlinked under its `mods/` directory. Release archives contain
only the standalone mod files.

Implementation must use only the public API documented by the tagged upstream
source. If an item needs an unavailable hook, registry, or behavior, record the gap
instead of including private engine headers or silently depending on internals.

## Design principles

1. **Gen 1 first.** Items use the existing bag, text boxes, palettes, sounds, and
   animations wherever possible. New art is optional rather than a requirement.
2. **Capabilities, not conveniences.** An item should create a new decision or
   unlock an activity, not merely shorten a menu operation.
3. **One shared framework.** Timed field effects, encounter modifiers, permanent
   unlocks, reusable tools, and consumables share state and hooks instead of
   becoming unrelated scripts.
4. **Respect the encounter table.** Effects bias an area's identity; they do not
   silently replace it. Exceptional encounters are curated by habitat.
5. **No guaranteed miracles.** Rare and shiny effects improve odds, but retain
   uncertainty. Gen-1-compatible shiny Pokemon must be produced through valid DVs.

## Ownership categories

Ownership describes how an item is stored and used, independently of how it may
eventually be awarded:

- **Permanent:** unlocked once, never consumed, and shown in a dedicated
  **GADGETS** menu rather than occupying a normal bag slot.
- **Reusable:** owned as a persistent gadget and usable repeatedly. Any cooldown,
  charges, or other limiting rule must be defined when that item is implemented.
- **Consumable:** stored in the normal bag and removes exactly one copy only after
  its effect has been applied successfully.
- **Consumable pair:** two linked consumable states, such as placing and then using
  a beacon. The implementation must define cancellation and replacement behavior.

Only one encounter-modifying field effect may be active at a time. Activating a
different one asks the player to confirm replacement.

## Thematic item families

Items also carry a thematic family label. These labels establish the identity and
visual language of each item; they do not yet decide exactly where, when, or how
the player obtains it.

**Oak / Pallet**

- Field equipment and Pokédex technology
- Shiny Finder
- Rare Lure, Mystery Lure, and Species Whistle
- Pokédex Chip

**Silph Co.**

- Link Cable and PC Transfer Unit
- Trainer Beacon and EXP Battery
- Blank TM
- Prototype Ball and Prototype Repel
- Silph Tracker and Emergency Teleporter

**Cinnabar Lab**

- Fossil Catalyst and Move Recorder
- DNA Stabilizer and Mutation Capsule
- Glitch Detector

**Safari Zone**

- Safari Bait / Pass
- Wildlife-focused variants of lures and trackers

**Rocket content**

- Rocket Decoder
- Stolen or black-market variants of prototype gadgets

**Exploration**

- Treasure Detector
- Map Beacon

The family label is required metadata, but variants may reuse an item's underlying
behavior with different presentation or balance. A family is not an acquisition
system and does not imply a shop, quest, currency, or reward track.

## Item catalogue

This catalogue defines ownership and intended behavior, not acquisition method.

| Item | Ownership | Intended effect |
| --- | --- | --- |
| Shiny Finder | Consumable | Temporarily raises wild shiny generation to about 1 in 100 via valid shiny DVs. |
| Rare Lure | Consumable | Biases encounters toward the rarest species already in the area's table. |
| Mystery Lure | Consumable | Adds a small, curated habitat-specific encounter pool for a limited duration. |
| Species Whistle | Consumable | Selects a species and raises its weight in compatible encounter tables. |
| Silph Tracker | Permanent | Reports whether a selected species is absent, faint, present, or strong locally. |
| Treasure Detector | Permanent | Gives stronger feedback as the player approaches an uncollected hidden item. |
| Trainer Beacon | Consumable | Allows a previously defeated, eligible trainer to be challenged again. |
| Prototype Ball | Consumable | Applies a documented conditional modifier to the normal capture calculation. |
| Prototype Repel | Consumable | Attracts encounters at or above the lead Pokemon's level. |
| EXP Battery | Consumable | Arms a bonus for a future eligible EXP award. |
| Link Cable | Consumable | Evolves Kadabra, Machoke, Graveler, or Haunter using the existing trade presentation. |
| PC Transfer Unit | Consumable | Opens portable PC access once, then returns to the original map safely. |
| Blank TM | Consumable | Records one eligible move, then teaches it to a compatible recipient. |
| Emergency Teleporter | Consumable | Returns the player to the last valid Pokemon Center. |
| Map Beacon | Consumable pair | Records a valid field tile and later returns the player to it. |
| Move Recorder | Consumable | Offers an eligible missed level-up move to the selected Pokemon. |
| Fossil Catalyst | Consumable | Applies a disclosed modifier during fossil revival. |
| DNA Stabilizer | Consumable | Improves DVs within bounded, shiny-safe rules. |
| Mutation Capsule | Consumable | Rerolls one random DV and previews the affected stat. |
| Glitch Detector | Consumable | Enables a curated temporary encounter anomaly without corrupting game state. |
| Safari Bait / Pass | Consumable | Alters curated Safari encounters or one clearly stated Safari rule. |
| Rocket Decoder | Permanent | Detects and decodes authored, temporary Rocket incidents. |
| Pokédex Chip | Permanent | Adds encounter statistics to Pokédex information. |

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

The ordered implementation checklist, beginning with shared groundwork and then
the **Shiny Finder**, lives in [the implementation plan](docs/IMPLEMENTATION.md).
New items should be added to both the catalogue and that checklist, with explicit
ownership and thematic family labels, before implementation begins.

The first playable milestone also includes a debug-only Pallet Town NPC with
**GET ITEMS**, **WARP**, **INSPECT**, and **RESET** commands. It provides free test
items, curated safe warps, and DScrete state inspection without defining how items
are acquired in a release build.
