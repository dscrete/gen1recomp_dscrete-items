# DScrete Items

**DScrete Items** is a Gen1Recomp expansion built around strange, useful pieces of
late-1990s Pokemon technology. Rather than backporting later-generation features,
the mod adds gadgets that create new decisions and activities while fitting the
existing game's presentation.

The guiding loop is:

> find a gadget -> gain a capability -> discover a new way to play

How players obtain the gadgets is intentionally separate from the item framework.
Oak research, Silph prototypes, Safari ecology, Rocket incidents, shops, currencies,
or other reward systems can be layered on later without changing item behavior.

## Engine compatibility

DScrete Items is a standalone **Mod API 2** mod for Gen1Recomp. It does not vendor,
fork, or bundle the engine. The authoritative integration target is:

- Gen1Recomp tag `v0.2.74`;
- upstream commit `9545ebbb839a8a7ea28472b626681154ab222623`;
- game target `gen1`; and
- supported engine range `>=0.2.74 <0.3.0`.

The compatibility contract is machine-readable in [`manifest.json`](manifest.json).
Implementation uses the public API exposed by the pinned revision. Engine-integrated
validation is kept separate from the standalone tests and requires an external
Gen1Recomp checkout plus imported Gen 1 cache.

## Design principles

1. **Gen 1 first.** Items use the existing bag, text boxes, palettes, sounds, and
   animations wherever possible. New art is optional rather than required.
2. **Capabilities, not conveniences.** An item should create a new decision or
   unlock an activity, not merely shorten a menu operation.
3. **One shared framework.** Timed field effects, encounter modifiers, permanent
   unlocks, reusable tools, and consumables share state and hooks instead of
   becoming unrelated scripts.
4. **Respect the encounter table.** Effects bias an area's identity; they do not
   silently replace it. Exceptional encounters are curated by habitat.
5. **No guaranteed miracles.** Rare and shiny effects improve odds, but retain
   uncertainty. Gen-1-compatible shiny Pokemon are produced through valid DVs.
6. **Distribution comes later.** Item implementation does not assume how an item is
   earned. Reward systems can be designed independently once behavior is stable.

## Storage and ownership

Ownership describes how an item is stored and used:

- **Permanent:** unlocked once, never consumed, and intended for a dedicated
  **GADGETS** menu rather than a normal bag slot.
- **Reusable:** persistent gadget usable repeatedly, with any cooldown/charge rule
  defined by that item.
- **Consumable:** stored in the normal bag and removes exactly one copy only after
  its effect is successfully applied.
- **Consumable pair:** linked consumable states such as placing and using a beacon.

Only one encounter-modifying field effect may be active at a time. Activating a
different one requires explicit replacement confirmation.

## Item catalogue

The **category** column assigns implementation ownership. It describes which shared
system contains the behavior, not where or how the player receives the item.

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

## Category ownership

- **Encounters:** encounter-table transforms, wild generation, durations, and
  habitat rules.
- **Detection:** reusable information tools and overworld feedback.
- **Battle:** capture, experience, and trainer-rematch hooks.
- **Pokemon:** moves, evolution, fossils, and DV modification.
- **Travel:** map, PC, warp, and safe-return behavior.

These boundaries are implementation boundaries only. Player-facing sources and
progression remain deliberately unassigned.

## Current playable foundation

The repository now contains a real Mod API 2 implementation rather than a gameplay
model in Python:

- loadable manifest and `main.lua` entrypoint;
- shared Lua item/runtime layer with persistent `mod.save` state;
- real bag registration for consumables;
- developer-only Pallet Town harness with **GET ITEMS**, **WARP**, **INSPECT**, and
  **RESET**;
- a complete Shiny Finder vertical slice using valid Gen-1 virtual-shiny DVs;
- standalone Lua/static tests and a pinned external-engine validation target.

The debug harness is registered only when Gen1Recomp runs the mod in developer mode.

## Testing and downloadable build

`make test` runs the standalone test suite. `make test-integration` validates against
an external checkout of the exact pinned Gen1Recomp revision.

Every GitHub push and pull request also runs the standalone workflow and builds a
minimal `dscrete-items-dev.zip` containing only `manifest.json`, `main.lua`, and
`lib/`. The ZIP is uploaded to the workflow run as the **dscrete-items-dev** artifact
for direct testing in Gen1Recomp.

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
  flag, retroactively alter owned Pokemon, or guarantee an encounter will shine.

## Delivery

The ordered source of truth is [docs/CHECKLIST.md](docs/CHECKLIST.md). Detailed
behavioral contracts, current integration status, and edge cases live in
[docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).

Shiny Finder is the first completed vertical slice. The next recommended work is the
shared encounter foundation: Rare Lure, Silph Tracker, Mystery Lure, Species Whistle,
and Prototype Repel.
