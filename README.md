# Discrete Items

**Discrete Items** is a planned Gen1Recomp expansion built around strange, useful
pieces of late-1990s Pokemon technology. Rather than backporting later-generation
features, the mod turns new gadgets into a common reward language for research,
exploration, Silph prototypes, Cinnabar experiments, Safari ecology, and Rocket
investigations.

The guiding loop is:

> activity -> points or reward -> gadget -> new capability -> new activity

This repository currently defines the product and implementation contract for the
mod. Integration begins with the vertical slice in [the implementation plan](docs/IMPLEMENTATION.md).

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
6. **Useful places stay useful.** Oak, Silph Co., Cinnabar Lab, the Safari Zone,
   and Rocket locations each own a distinct family of rewards.

## Gadget catalogue

| Gadget | Type | Source | Intended effect |
| --- | --- | --- | --- |
| Rare Lure | Consumable | Oak / Safari | Biases encounters toward the rarest species already in the area's table. |
| Mystery Lure | Consumable | Oak / Safari | Adds a small, curated habitat-specific encounter pool for a limited duration. |
| Species Whistle | Consumable | Oak | Selects a species and raises its weight in compatible encounter tables. |
| Silph Tracker | Permanent | Oak / Silph | Reports whether a selected species is absent, faint, present, or strong locally. |
| Treasure Detector | Permanent | Oak | Gives stronger feedback as the player approaches an uncollected hidden item. |
| Trainer Beacon | Consumable | Silph | Allows a previously defeated, eligible trainer to be challenged again. |
| Prototype Ball | Consumable | Silph | Applies a documented conditional modifier to the normal capture calculation. |
| Prototype Repel | Consumable | Silph | Attracts encounters at or above the lead Pokemon's level. |
| EXP Battery | Consumable | Oak / Silph | Arms a bonus for a future eligible EXP award. |
| Link Cable | Consumable | Silph | Evolves Kadabra, Machoke, Graveler, or Haunter using the existing trade presentation. |
| PC Transfer Unit | Consumable | Silph | Opens portable PC access once, then returns to the original map safely. |
| Blank TM | Consumable | Silph | Records one eligible move, then teaches it to a compatible recipient. |
| Emergency Teleporter | Consumable | Silph | Returns the player to the last valid Pokemon Center. |
| Map Beacon | Consumable pair | Exploration | Records a valid field tile and later returns the player to it. |
| Move Recorder | Consumable | Cinnabar | Offers an eligible missed level-up move to the selected Pokemon. |
| Fossil Catalyst | Consumable | Cinnabar | Applies a disclosed modifier during fossil revival. |
| DNA Stabilizer | Consumable | Cinnabar | Improves DVs within bounded, shiny-safe rules. |
| Mutation Capsule | Consumable | Cinnabar | Rerolls one random DV and previews the affected stat. |
| Glitch Detector | Consumable | Cinnabar | Enables a curated temporary encounter anomaly without corrupting game state. |
| Safari Bait / Pass | Consumable | Safari Zone | Alters curated Safari encounters or one clearly stated Safari rule. |
| Rocket Decoder | Permanent | Rocket content | Detects and decodes authored, temporary Rocket incidents. |
| Oak's Specimen Jar | Reusable | Oak | Records evidence for active catch and observation assignments. |
| Pokedex Chip | Permanent | Oak | Adds encounter and research statistics to Pokedex information. |
| Shiny Finder | Consumable | Oak | Temporarily raises shiny generation to about 1 in 100 via valid shiny DVs. |

Permanent gadgets live in a dedicated **GADGETS** menu and do not consume normal
bag slots. Consumables remain normal items so their cost and scarcity stay visible.
Only one encounter-modifying field effect may be active at a time; using another
asks the player to replace the current effect.

## Oak's Research

Oak offers authored assignments rather than an unbounded checklist. Assignment
templates include observing a species, recording a route's biodiversity, catching
above a level threshold, catching after inflicting a status condition, surveying
multiple habitats, finding a rare specimen, and completing a special battle
observation. Progress is updated by shared encounter, battle, capture, and map hooks.

Completed assignments award **Research Points (RP)** and rank progress. RP is saved
as a capped currency and is never represented by a bag item.

| Rank | Example unlocks |
| --- | --- |
| Field Assistant | Rare Lure, Mystery Lure, basic research supplies |
| Field Researcher | Silph Tracker, Species Whistle, Trainer Beacon |
| Senior Researcher | Link Cable, EXP Battery, fossil equipment |
| Pokemon Expert | Shiny Finder, DNA Stabilizer, Mutation Capsule |

Initial balancing targets are 10 RP for a Rare Lure, 15 for the Treasure Detector,
20 for a Trainer Beacon, 25 for a Species Whistle, 30 for an EXP Battery, 40 for a
Link Cable, 75 for a Shiny Finder, and 100 for a DNA Stabilizer. These values are
configuration, not hard-coded progression rules.

## Ownership by location

- **Oak / Pallet:** field research, Pokedex upgrades, lures, and the Shiny Finder.
- **Silph Co.:** Link Cable, portable PC, Trainer Beacon, Blank TM, experimental
  balls, and Prototype Repel.
- **Cinnabar Lab:** fossil and DV experiments, Move Recorder, and Glitch Detector.
- **Safari Zone:** ecological surveys, Safari bait, passes, and wildlife tracking.
- **Rocket content:** the Decoder and stolen or black-market prototype variants.
- **Exploration:** map beacons, hidden-item surveys, and cartography rewards.

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

The first playable slice is intentionally small: the shared save/state layer,
Rare Lure, Silph Tracker, Oak research tasks, and the RP exchange. Once that loop is
stable, additional gadgets should be added through data definitions and focused
hooks rather than parallel one-off systems. See [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)
for phases, contracts, edge cases, and acceptance criteria.

