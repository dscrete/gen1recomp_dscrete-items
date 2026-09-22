# Implementation checklist

This is the ordered delivery backlog for DScrete Items. Work from top to bottom
unless a newly discovered dependency requires reordering. Category labels assign
code ownership; they do not decide how players obtain an item.

## 0. Groundwork

- [x] Pin and document the supported Gen1Recomp revision.
- [x] Add a reproducible standalone build/package target.
- [ ] Complete the pinned-engine in-game smoke matrix.
- [ ] Finish the full audit of item-use, wild-table, capture, EXP, evolution,
      trainer-defeat, hidden-item, PC, map-transition, and menu hooks as later
      catalogue items reach those systems.
- [x] Define item IDs, ownership/category metadata, and standalone validation that
      rejects duplicate or invalid definitions.
- [x] Allocate a versioned `mod.save` namespace and clear runtime-only state on
      `game.ready`.
- [ ] Add explicit migrations when the first persisted schema change is introduced.
- [x] Implement transactional consumable use: validate/apply first, consume exactly
      one item only after successful activation.
- [x] Implement the shared timed field-effect lifecycle, replacement confirmation,
      eligible-step countdown, and one-time expiration.
- [x] Add deterministic test helpers and seeded probability simulations.

## Developer harness

- [x] Add a developer-only Pallet Town NPC.
- [x] Add **GET ITEMS**, **WARP**, **INSPECT**, and **RESET** flows.
- [x] Route test item grants through the engine's real inventory/script path.
- [x] Keep the harness absent from ordinary player mode.
- [ ] Visually smoke-test NPC placement and every curated warp landing coordinate.

## 1. First playable item

- [x] **Shiny Finder** — Encounters
  - [x] Register the consumable and activation behavior through the public item API.
  - [x] Apply its configured chance only to marked natural wild encounters.
  - [x] Generate only DV combinations accepted by Gen1Recomp's shiny predicate.
  - [x] Exclude gifts, trades, static encounters, owned Pokemon, and trainer parties.
  - [x] Test transaction, duration, replacement, expiration, and shiny-safe DV rules.
  - [x] Run a seeded statistical check against the initial 1-in-100 target.
  - [ ] Complete the pinned-engine/in-game smoke matrix.

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

- [ ] Build the permanent **GADGETS** menu and unlock handling.
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
- [ ] Validate all item definitions at build time against the pinned engine as well
      as standalone metadata rules.
- [ ] Balance durations, odds, modifiers, and limits through data rather than code.
- [ ] Decide player-facing sources and progression only after item behavior is stable.

## Build delivery

- [x] `make package` creates a minimal `dist/dscrete-items-dev.zip` with the mod
      manifest/entrypoint at the archive root.
- [x] GitHub Actions runs standalone tests and uploads the ZIP as the
      **dscrete-items-dev** artifact on pushes and pull requests.
- [ ] Add versioned release assets when tagged releases are introduced.
