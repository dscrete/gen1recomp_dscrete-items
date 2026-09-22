# DScrete Items implementation checklist

This document is the ordered backlog for Gen1Recomp integration. Complete items
from top to bottom unless a dependency discovered during the integration audit
requires reordering. Exact symbols must be bound to the supported upstream
revision; this plan deliberately does not invent API names.

Acquisition and reward design are not part of this checklist. An item's ownership
category controls storage and consumption only; it does not prescribe where or how
the player receives it.

## Integration contract

- Standalone Gen1Recomp Mod API 2 mod; never a fork or bundled engine dependency.
- Authoritative engine tag: `v0.2.74`.
- Authoritative engine commit: `9545ebbb839a8a7ea28472b626681154ab222623`.
- Manifest target: `api: 2`, game `gen1`, version `>=0.2.74 <0.3.0`.
- Public API authority: the `v0.2.74` source and `docs/modding.md`.
- Local integration uses a separate engine checkout and mounts this repository in
  `mods/`; releases contain only installable mod files.
- Any missing public capability is documented as an API gap. Code must not include
  private engine modules or infer undocumented entry points.

## 0. Shared groundwork

- [x] Pin and document Gen1Recomp `v0.2.74` at
      `9545ebbb839a8a7ea28472b626681154ab222623`.
- [x] Add the minimum Mod API 2 compatibility fields to `manifest.json`.
- [x] Add standalone validation for the confirmed manifest compatibility fields.
- [ ] Validate the complete manifest against the tagged public Mod API 2 schema.
- [ ] Locate the item-use, successful-step, wild-table, DV-generation, capture,
      EXP, evolution, save, trainer-defeat, hidden-item, PC, map-transition, and
      menu-extension hooks.
- [ ] Record hook calling constraints and allocate a versioned mod save block.
- [ ] Add save migration, bounds checking, and safe initialization for old saves.
- [x] Add ownership metadata for `PERMANENT`, `REUSABLE`, `CONSUMABLE`, and
      `CONSUMABLE_PAIR`.
- [x] Add thematic family metadata for `OAK_PALLET`, `SILPH_CO`, `CINNABAR_LAB`,
      `SAFARI_ZONE`, `ROCKET`, and `EXPLORATION`, without coupling it to an
      acquisition system.
- [x] Add standalone validation of every item definition, including required and
      recognized ownership and family labels.
- [ ] Add the dedicated **GADGETS** menu for permanent and reusable ownership.
- [x] Implement and test the engine-independent transaction result and consumption
      contract shared by all consumables.
- [x] Implement and test engine-independent field-effect activation, explicit
      replacement, eligible-step duration, and one-time expiration state rules.
- [x] Add a dependency-free standalone test command and manifest/repository-boundary
      tests.
- [x] Add an integration-test command that verifies an external checkout is pinned
      to the authoritative commit before running engine-facing tests.
- [ ] Add deterministic gameplay helpers, seeded statistical simulations, and a
      minimal in-game smoke-test target as implementation code is introduced.

### Debug development harness

- [x] Define and test the **GET ITEMS**, **WARP**, **INSPECT**, **RESET**, and
      **CANCEL** menu model independently of engine internals.
- [x] Define and test ownership-aware debug grants, inspection, and resets behind a
      narrow adapter boundary.
- [ ] Add a debug build flag using the public Mod API 2 configuration mechanism.
- [ ] Add one debug-only NPC in Pallet Town through the public map/NPC registry.
- [ ] Add **GET ITEMS** with free Shiny Finder and all-items test options using the
      real public inventory and ownership APIs.
- [ ] Add **WARP** with curated, validated destinations and a return destination.
- [ ] Add **INSPECT** for schema version, ownership, active effect, remaining steps,
      selected species, pending effects, beacon state, and debug counters.
- [ ] Add confirmed **RESET** actions for DScrete runtime state, save state, item
      ownership, and debug telemetry.
- [ ] Prove that debug registrations and telemetry are absent from release builds.

Do not choose map IDs, coordinates, registry names, or hooks until they are verified
against the tagged public API. The debug NPC exercises real mod-facing APIs; it must
not patch private map data or become the release acquisition system.

Suggested state boundaries:

```text
DScreteItemSaveData
  schema_version
  permanent_unlock_bits
  reusable_item_state
  trainer_rematch_state
  placed_beacon

DScreteItemRuntimeState (not serialized)
  active_field_effect
  remaining_steps
  selected_species
  pending_exp_multiplier
  temporary_context
```

Runtime pointers, menu cursors, cached encounter-table addresses, and temporary
callbacks must never enter the save. Loading clears runtime-only state unless a
field effect later gains an explicit serialized definition and migration rule.

### Shared field-effect contract

```text
id
duration_steps
can_activate(context) -> reason
transform_encounter_table(context, scratch_table)
on_encounter_generated(context, encounter)
on_step(context)
on_expire(context)
```

The original encounter table is copied to scratch storage before transformation.
Weights are normalized after every modifier, zero-weight slots stay unreachable,
and the vanilla table is never modified in place. A map transition re-evaluates an
effect against the new map without resetting its step counter.

Only successful overworld steps decrement duration. Menu movement, wall bumps,
warps, forced movement, and battle turns do not. Expiration is announced once in a
safe overworld text context.

### Shared consumable transaction

1. Validate context and display any required selection menus.
2. Preview irreversible consequences when relevant.
3. Apply the effect.
4. Consume exactly one item only after successful application.
5. Mark the save dirty and return through the normal item-use result path.

Cancellation, invalid targets, failed map validation, and closed menus consume
nothing. A save interruption must not leave a consumed item with an unapplied
effect.

## 1. Shiny Finder — first playable item

- [x] Register **Shiny Finder** in the declarative catalogue as a consumable
      Oak/Pallet field-effect item.
- [x] Define and validate its duration and shiny-chance balance knobs (250 eligible
      steps and an initial 1/100 chance).
- [ ] Hook wild DV generation and use Gen1Recomp's own shiny predicate.
- [x] Implement an engine-independent adapter that enumerates the runtime predicate's
      valid packed DVs and chooses uniformly from them after a successful roll.
- [x] Exclude gifts, trades, static encounters, owned Pokemon, and trainer parties
      from both the chance roll and debug telemetry.
- [ ] Add use, cancel, invalid-context, already-active, replacement, and expiration
      text.
- [ ] Test use, expiration, replacement, save/load clearing, map transitions, and
      all excluded encounter classes.
- [x] Add deterministic behavior/DV tests and seeded statistical rate and candidate
      distribution tests using an explicitly test-only shiny predicate.

The Finder changes DVs only at wild Pokemon creation. It preserves species, level,
moves, and encounter flow; it neither applies a cosmetic flag nor guarantees that
an encounter will be shiny.

**Exit criterion:** a Finder can be activated and consumed transactionally, remains
active for the configured number of eligible steps, generates only runtime-valid
shiny DVs on successful rolls, and passes the smoke matrix below.

## 2. Core encounter items

- [ ] **Rare Lure** — consumable; boost the least-common native species, including
      correct handling of duplicate slots and ties.
- [ ] **Silph Tracker** — permanent; report coarse signal bands using the same
      combined species weights used by encounter modifiers.
- [ ] **Mystery Lure** — consumable; reserve a configured share for a curated
      habitat pool and reject use where no pool exists.
- [ ] **Species Whistle** — consumable; boost a selected compatible species without
      inserting an incompatible one.
- [ ] **Prototype Repel** — consumable; attract encounters at or above the lead
      Pokemon's level.

Rare Lure changes relative species weights, not encounter frequency, levels, or the
species set. Mystery candidates are data-driven by habitat and progression flags.
Tracker and Whistle share one compatibility index, including duplicate slots.

## 3. World-information items

- [ ] **Treasure Detector** — permanent; proximity feedback for uncollected hidden
      items.
- [ ] **Pokédex Chip** — permanent; encounter statistics in Pokédex information.

## 4. Battle and Pokemon items

- [ ] **Prototype Ball** — consumable; data-driven condition and capture modifier.
- [ ] **EXP Battery** — consumable; arm one future eligible EXP bonus.
- [ ] **Link Cable** — consumable; evolve Kadabra, Machoke, Graveler, or Haunter
      through the existing trade presentation.
- [ ] **Move Recorder** — consumable; offer one eligible missed level-up move.
- [ ] **Fossil Catalyst** — consumable; apply a disclosed fossil-revival modifier.
- [ ] **DNA Stabilizer** — consumable; bounded DV improvement with shiny-safe rules.
- [ ] **Mutation Capsule** — consumable; preview and reroll one random DV.
- [ ] **Blank TM** — consumable; record and teach one compatible move using a
      data-driven compatibility table.

The Link Cable remains disabled until the trade presentation can safely return to
the bag flow. It must not silently fall back to a plain-text evolution.

## 5. Trainer, travel, and activity items

- [ ] **Trainer Beacon** — consumable; rematch only explicitly eligible defeated
      trainers.
- [ ] **PC Transfer Unit** — consumable; one safe portable-PC session and return.
- [ ] **Emergency Teleporter** — consumable; return to the last valid Pokemon Center.
- [ ] **Map Beacon** — consumable pair; validate, place, replace, and return safely.
- [ ] **Safari Bait / Pass** — consumable; one curated encounter or Safari-rule
      modifier per definition.
- [ ] **Rocket Decoder** — permanent; decode authored temporary incidents.
- [ ] **Glitch Detector** — consumable; curated temporary anomalies without game
      state corruption.

Travel effects are disabled in battle, link rooms, scripted movement, Safari
transitions, and every other context not proven safe. Trainer rematches use an
allowlist; story trainers require purpose-built definitions.

## 6. Definition of done for every item

- [ ] Ownership category, thematic family, and metadata are declared and validated.
- [ ] Use, cancel, invalid-context, active, and expiration text exists where
      applicable.
- [ ] Persistence, replacement, and stacking behavior are explicit.
- [ ] Configuration and content data pass build-time validation.
- [ ] Deterministic tests cover the item's rules and failure paths.
- [ ] Save/load and map-transition behavior is covered.
- [ ] Balance knobs are documented without encoding an acquisition method.
- [ ] No path consumes an item before its effect commits.

## Test strategy

### Deterministic checks

- Encounter normalization preserves the exact total and never revives zero slots.
- Rare selection handles duplicate species, ties, and one-species tables.
- Species compatibility agrees between Tracker and Whistle.
- Step duration decrements only for eligible movement and expires once.
- Item transactions consume once on success and never on cancellation or failure.
- Ownership rules prevent duplicates or invalid bag/menu placement.
- Save round trips preserve persistent state and clear runtime caches.
- Every prior schema version migrates to the current schema.
- Shiny-forced DVs pass the runtime's own shiny predicate.

### Statistical checks

Seeded simulations compare observed encounter and shiny rates with expected
distributions using tolerances chosen before execution. They complement rather
than replace deterministic weight and DV tests; a finite random sample is never
required to contain a shiny.

### In-game smoke matrix

Test item use from the overworld and bag, then around map transitions, blackout,
save/load, evolution, full inventory, Safari entry/exit, scripted movement, and
each explicitly unsafe context. Verify both Red/Blue-style and Yellow-specific
encounter data where the supported runtime exposes them.
