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

DScrete Items is a standalone **Mod API 2** mod for Gen1Recomp. The supported engine
range is `>=0.2.5 <0.3.0`; the minimum-version verifier targets the `v0.2.5` tag.
Full in-game smoke testing at the compatibility floor remains part of the integration
checklist.

## Design principles

1. **Gen 1 first.** Items use the existing bag, text boxes, palettes, sounds, and
   animations wherever possible.
2. **Capabilities, not conveniences.** An item should create a new decision or
   unlock an activity, not merely shorten a menu operation.
3. **One shared framework.** Timed field effects, encounter modifiers, permanent
   unlocks, reusable tools, and consumables share state and hooks.
4. **Respect the encounter table.** Effects bias an area's identity rather than
   silently replacing it.
5. **Compatibility first.** Encounter tools compose through public hook chains and
   merged encounter data where possible. Companion mods such as Wilds of Kanto are
   optional integrations, never requirements.
6. **Distribution comes later.** Item implementation does not assume how an item is
   earned.

## Storage and ownership

- **Permanent:** unlocked once, never consumed, and shown through **GADGETS**.
- **Reusable:** persistent gadget usable repeatedly.
- **Consumable:** normal bag item; one copy is removed only after successful use.
- **Consumable pair:** linked consumable states such as placing and using a beacon.

Only one encounter-modifying field effect may be active at a time. Activating a
different one requires explicit replacement confirmation.

## Current playable items

### Prism Scent

A timed consumable that gives eligible natural wild encounters a configurable chance
to receive valid Gen-1 shiny DVs. Odds presets are `1/1`, `1/10`, `1/100`, and
`1/1000`; duration presets are `50`, `100`, `250`, `500`, `1000`, and `2500` eligible
steps. Active state and remaining steps survive save/load and a game reboot.

Wilds of Kanto support is optional. When its public exports are available, a successful
Prism Scent roll is attached to the visible spawn so the overworld presentation and
battle use the same shiny DVs. Trainer parties, gifts, trades, and static encounters
remain unaffected.

### Elusive Scent

A timed consumable that boosts the rarest species already present in the local
encounter table. Species tied for the lowest combined weight are boosted equally.
It never introduces a species, changes levels, or changes encounter frequency.

Strength is configurable as **MILD / STRONG / EXTREME**, corresponding to roughly
`2x / 4x / 8x` weighting for the tied rarest species. It uses the same duration
presets as Prism Scent and is mutually exclusive with other field effects. It applies
to grass, cave/indoor, surf/water, and Safari step encounters; fishing is unchanged.
Optional Wilds of Kanto integration uses its published runtime surface when present.

### Silph Tracker

A permanent gadget accessed from the new **GADGETS** Start-menu entry after it has
been unlocked. It scans the current map and reports each local species using coarse
signal bands:

`NO SIGNAL / FAINT / WEAK / STRONG / VERY STRONG`

Species not yet known to the player's Pokédex are shown as **UNKNOWN** while keeping
the signal strength. Tracker readings use merged encounter data, reflect active
Elusive Scent weighting, and use the newer public effective-encounter preview API
when available.

## Item catalogue

| Item | Type | Category | Intended effect |
| --- | --- | --- | --- |
| Prism Scent | Consumable | Encounters | Configurable shiny odds through valid Gen-1 shiny DVs. |
| Elusive Scent | Consumable | Encounters | Biases encounters toward the rarest species already in the area's table. |
| Mystery Lure | Consumable | Encounters | Adds a small curated habitat-specific encounter pool temporarily. |
| Species Whistle | Consumable | Encounters | Selects a species and raises its weight in compatible tables. |
| Prototype Repel | Consumable | Encounters | Attracts encounters at or above the lead Pokemon's level. |
| Glitch Detector | Consumable | Encounters | Enables a curated temporary encounter anomaly. |
| Safari Bait / Pass | Consumable | Encounters | Alters curated Safari encounters or one stated Safari rule. |
| Silph Tracker | Permanent | Detection | Reports coarse signal bands for all local species. |
| Treasure Detector | Permanent | Detection | Gives stronger feedback near an uncollected hidden item. |
| Rocket Decoder | Permanent | Detection | Detects and decodes authored temporary Rocket incidents. |
| Pokedex Chip | Permanent | Detection | Adds encounter statistics to Pokedex information. |
| Prototype Ball | Consumable | Battle | Applies a documented modifier to normal capture calculation. |
| EXP Battery | Consumable | Battle | Arms a bonus for a future eligible EXP award. |
| Trainer Beacon | Consumable | Battle | Allows an eligible defeated trainer to be challenged again. |
| Link Cable | Consumable | Pokemon | Evolves the four Gen-1 trade-evolution species. |
| Move Recorder | Consumable | Pokemon | Offers an eligible missed level-up move. |
| Fossil Catalyst | Consumable | Pokemon | Applies a disclosed modifier during fossil revival. |
| DNA Stabilizer | Consumable | Pokemon | Improves DVs within bounded shiny-safe rules. |
| Mutation Capsule | Consumable | Pokemon | Rerolls one random DV with preview. |
| Blank TM | Consumable | Pokemon | Records and teaches one compatible move. |
| PC Transfer Unit | Consumable | Travel | Opens portable PC access once and safely returns. |
| Emergency Teleporter | Consumable | Travel | Returns to the last valid Pokemon Center. |
| Map Beacon | Consumable pair | Travel | Records a valid field tile and later returns to it. |

## Development access

Current item acquisition is deliberately development-only while behavior is being
stabilized. The developer Pallet Town NPC provides **GET ITEMS**, **WARP**,
**INSPECT**, and **RESET**. **ALL TEST ITEMS** grants consumables through the real
inventory path, while **UNLOCK GADGETS** unlocks permanent tools such as Silph
Tracker.

## Testing and downloadable build

`make test` runs the standalone Lua/static suite. `make test-integration` validates
against the minimum supported Gen1Recomp checkout when an imported Gen-1 cache is
available.

Every push and pull request runs tests and builds a minimal
`dist/dscrete-items-dev.zip`. Successful pushes to `main` update the rolling
**Development Build** (`dev`) prerelease and replace its attached ZIP, providing a
stable latest-development download from the Releases page.

## Delivery

The ordered source of truth is [docs/CHECKLIST.md](docs/CHECKLIST.md). Detailed
behavioral contracts and integration notes live in
[docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).

Prism Scent, Elusive Scent, Silph Tracker, and the initial GADGETS menu now form the
playable encounter foundation. The next planned encounter items are Mystery Lure,
Species Whistle, and Prototype Repel.
