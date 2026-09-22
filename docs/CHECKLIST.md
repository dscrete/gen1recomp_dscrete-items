# Implementation checklist

This is the ordered delivery backlog for DScrete Items. Work from top to bottom
unless a newly discovered dependency requires reordering. Category labels assign
code ownership; they do not decide how players obtain an item.

## 0. Groundwork

- [x] Pin and document the supported Gen1Recomp compatibility floor (`>=0.2.5 <0.3.0`).
- [x] Add a reproducible standalone build/package target.
- [ ] Complete the minimum-supported-engine in-game smoke matrix.
- [ ] Finish the full audit of item-use, wild-table, capture, EXP, evolution,
      trainer-defeat, hidden-item, PC, map-transition, and menu hooks as later
      catalogue items reach those systems.
- [x] Define item IDs, ownership/category metadata, and standalone validation that
      rejects duplicate or invalid definitions.
- [x] Allocate a versioned `mod.save` namespace; persist active timed field effects
      while clearing only transient runtime state on load/boot.
- [x] Add explicit save migration support. Schema v3 migrates the legacy
      `shiny_finder` active-effect ID to `prism_scent` without losing remaining steps.
- [x] Implement transactional consumable use: validate/apply first, consume exactly
      one item only after successful activation.
- [x] Implement the shared timed field-effect lifecycle, replacement confirmation,
      eligible-step countdown, persistence, and one-time expiration.
- [x] Add deterministic test helpers and seeded probability simulations.
- [x] Require completed work and changed requirements to update this checklist via
      repository instructions in `AGENTS.md`.

## Developer harness

- [x] Add a developer-only Pallet Town NPC.
- [x] Add **GET ITEMS**, **WARP**, **INSPECT**, and **RESET** flows.
- [x] Route test item grants through the engine's real inventory/script path.
- [x] Keep the harness absent from ordinary player mode.
- [x] Rename the debug item grant and telemetry text to **Prism Scent**.
- [ ] Visually smoke-test NPC placement and every curated warp landing coordinate.

## 1. First playable item

- [x] **Prism Scent** — Encounters
  - [x] Register the consumable and activation behavior through the public item API.
  - [x] Use Prism-specific internal IDs (`prism_scent`, `DS_PRISM_SCENT`,
        `DS_PRISM_SCENT_EFFECT`) and Prism-specific option keys.
  - [x] Apply its configured chance only to eligible natural wild encounters.
  - [x] Generate only DV combinations accepted by Gen1Recomp's shiny predicate.
  - [x] Exclude gifts, trades, static encounters, owned Pokemon, and trainer parties.
  - [x] Persist active state and exact remaining eligible steps through save/load and
        a full game reboot.
  - [x] Expose configurable odds presets: 1/1, 1/10, 1/100, and 1/1000.
  - [x] Expose configurable duration presets: 50, 100, 250, 500, 1000, and 2500 steps.
  - [x] Add optional Wilds of Kanto interoperability without declaring it as a
        dependency: visible spawns roll before display and carry the same shiny DVs
        into battle.
  - [x] Preserve ordinary behavior when Wilds of Kanto is absent.
  - [x] Test transaction, duration, replacement, expiration, persistence, migration,
        visible-spawn marking, and shiny-safe DV rules.
  - [x] Run a seeded statistical check against the default 1-in-100 target.
  - [ ] Complete the minimum-supported-engine/in-game smoke matrix, including vanilla
        encounters, fishing, Safari, trainer battles, Wilds visible encounters, save/
        reboot persistence, and compatibility with a shiny presentation mod.

## 2. Encounter foundation — Encounters

- [ ] **Rare Lure** — reweight the rarest native species without changing frequency,
      levels, or the set of species; use merged/public encounter data so visible-
      encounter mods naturally observe the modified distribution.
- [ ] **Silph Tracker** — report coarse local signal bands using the same combined
      species weights consumed by encounter modifiers.
- [ ] **Mystery Lure** — reserve a configured share for curated habitat candidates.
- [ ] **Species Whistle** — boost a selected compatible species without inserting an
      incompatible one.
- [ ] **Prototype Repel** — attract encounters at or above the lead Pokemon's level.
- [ ] **Safari Bait / Pass** — alter one curated encounter set or stated Safari rule.
- [ ] **Glitch Detector** — enable curated anomalies without corrupting game state.
- [ ] For each encounter item, prefer public hook chaining/merged encounter views so
      other encounter, overworld-spawn, and presentation mods remain optional and
      composable rather than becoming dependencies.

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
- [ ] Validate all item definitions at build time against the minimum supported engine
      as well as standalone metadata rules.
- [ ] Keep player-facing balance values configurable through mod options/data where
      appropriate instead of baking them into behavior code.
- [ ] Decide player-facing sources and progression only after item behavior is stable.

## Build delivery

- [x] `make package` creates a minimal `dist/dscrete-items-dev.zip` with the mod
      manifest/entrypoint at the archive root.
- [x] GitHub Actions runs standalone tests and builds the ZIP on pushes and pull
      requests.
- [x] Pushes to `main` update the rolling **Development Build** (`dev`) prerelease and
      replace its attached `dscrete-items-dev.zip`.
- [ ] Add numbered/versioned release assets when tagged public releases are introduced.
