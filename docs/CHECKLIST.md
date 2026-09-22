# Implementation checklist

This is the ordered delivery backlog for DScrete Items. Work from top to bottom
unless a newly discovered dependency requires reordering. Category labels assign
code ownership; they do not decide how players obtain an item.

## 0. Groundwork

- [ ] Pin and document the supported Gen1Recomp revision.
- [ ] Add a reproducible build and a minimal in-game smoke-test target.
- [ ] Audit item-use, step, wild-table, DV-generation, capture, EXP, evolution,
      save, trainer-defeat, hidden-item, PC, map-transition, and menu hooks.
- [ ] Define item IDs, permanent unlock IDs, category metadata, and validation that
      rejects duplicate or invalid definitions.
- [ ] Allocate a versioned save block and implement fresh-save defaults, migration,
      bounds checks, and runtime-state reset on load.
- [ ] Implement transactional consumable use: validate, apply, then consume exactly
      one item only after success.
- [ ] Implement the shared timed field-effect lifecycle, replacement prompt, step
      countdown, expiration message, and safe map-transition behavior.
- [ ] Add deterministic test helpers and seeded encounter simulations.

## 1. First playable item

- [ ] **Shiny Finder** — Encounters
  - [ ] Register the consumable and activation/expiration text.
  - [ ] Apply its configured chance only at eligible wild DV generation.
  - [ ] Select only DV combinations accepted by Gen1Recomp's shiny predicate.
  - [ ] Exclude gifts, trades, static encounters, owned Pokemon, and trainer parties.
  - [ ] Test item transactions, duration, save/load, and shiny-safe DV generation.
  - [ ] Run a seeded statistical check against the initial 1-in-100 target.

## 2. Encounter foundation — Encounters

- [ ] **Rare Lure** — reweight the rarest native species without changing frequency,
      levels, or the set of species.
- [ ] **Silph Tracker** — report coarse local signal bands using the same combined
      species weights consumed by encounter modifiers.
- [ ] **Mystery Lure** — reserve a configured share for curated habitat candidates.
- [ ] **Species Whistle** — boost a selected compatible species without inserting an
      incompatible one.
- [ ] **Prototype Repel** — attract encounters at or above the lead Pokemon's level.
- [ ] **Safari Bait / Pass** — alter one curated encounter set or stated Safari rule.
- [ ] **Glitch Detector** — enable curated anomalies without corrupting game state.

## 3. Detection tools — Detection

- [ ] Build the permanent **GADGETS** menu and unlock-bit handling.
- [ ] **Treasure Detector** — scale feedback by distance to an uncollected hidden item.
- [ ] **Pokedex Chip** — display encounter statistics in Pokedex information.
- [ ] **Rocket Decoder** — detect and decode authored temporary incidents.

## 4. Battle tools — Battle

- [ ] **Prototype Ball** — apply a documented condition to normal capture math.
- [ ] **EXP Battery** — arm and consume a bonus on the next eligible EXP award.
- [ ] **Trainer Beacon** — rematch only trainers in an explicit eligibility table.

## 5. Pokemon tools — Pokemon

- [ ] **Link Cable** — evolve the four trade-evolution species with the trade
      presentation and a safe return to item flow.
- [ ] **Move Recorder** — offer an eligible missed level-up move.
- [ ] **Fossil Catalyst** — apply a disclosed modifier during fossil revival.
- [ ] **DNA Stabilizer** — improve DVs within bounded, shiny-safe rules.
- [ ] **Mutation Capsule** — preview and reroll one random DV.
- [ ] **Blank TM** — record and teach one move using data-driven compatibility.

## 6. Travel tools — Travel

- [ ] Add shared validation for battles, link rooms, scripted movement, Safari
      transitions, invalid tiles, and other unsafe map states.
- [ ] **Emergency Teleporter** — return to the last valid Pokemon Center.
- [ ] **PC Transfer Unit** — provide one portable PC session and safely restore the map.
- [ ] **Map Beacon** — record a valid field tile and later return to it.

## 7. Catalogue completion

- [ ] Give every item use, cancel, invalid-context, active, and expiration text as
      applicable.
- [ ] Cover every item with deterministic rules tests plus save/load and transition
      tests.
- [ ] Validate all item definitions at build time.
- [ ] Balance durations, odds, modifiers, and limits through data rather than code.
- [ ] Decide player-facing sources and progression only after item behavior is stable.
