# DScrete Items implementation status and contracts

Target: Gen1Recomp **v0.2.74**, commit
`9545ebbb839a8a7ea28472b626681154ab222623`, Mod API 2, Gen 1.

The ordered backlog lives in [CHECKLIST.md](CHECKLIST.md). This document records
what is implemented now plus the behavioral contracts later items should reuse.

## Current status

### Phase 1 — Manifest and compatibility

- [x] Complete loadable API-2 manifest with ID, display name, semantic version,
  entrypoint, profile/category, Gen 1 target and engine range.
- [x] Root `main.lua` entrypoint.
- [x] Standalone manifest sanity tests based on fields verified against v0.2.74.
- [ ] Run authoritative `modkit.py validate` in the external pinned engine checkout
  before a release is considered validated.

### Phase 2 — Test layers

- [x] Pure-Lua standalone tests for item metadata, field-effect state,
  replacement/expiration and Shiny Finder probability/DV generation.
- [x] Python retained only for static repository/manifest/upstream-revision checks.
- [x] Separate `make test` and `make test-integration` targets.
- [x] Integration target verifies the exact upstream commit before invoking modkit.
- [x] Engine smoke matrix documented in `integration_tests/README.md`.
- [x] `make package` builds a minimal installable mod ZIP.
- [x] GitHub Actions runs standalone tests and uploads that ZIP as an artifact.
- [ ] Add engine regression drivers for individual items as the catalogue grows.

### Phase 3 — Shared item runtime

- [x] Canonical Lua item catalogue with ownership/category metadata.
- [x] Real bag registration for consumables; permanent/reusable gadgets do not use
  bag slots.
- [x] Versioned `mod.save` namespace for persistent unlock/reusable state.
- [x] Runtime-only field-effect, selected-species, pending EXP, beacon/debug and
  encounter state.
- [x] One-active-field-effect policy with explicit replacement confirmation.
- [x] Replacement confirmation expires when the player walks away.
- [x] Eligible-step countdown and one-time expiration.
- [x] Runtime and persistent reset/inspection surfaces for developer tooling.

### Phase 4 — Developer-only Pallet Town harness

Registered only when `mod.developer` is true.

- [x] Appended Pallet Town NPC through public content registration.
- [x] Public map-script/custom-command dispatch.
- [x] **GET ITEMS**: Shiny Finder, all consumables, gadget unlocks, test-item removal.
- [x] Grants use the engine's real `give_item` path and obey real bag capacity and
  stack rules.
- [x] Curated **WARP** menu using `mod.world:warpTo`, with a runtime return point.
- [x] **INSPECT** for version/schema/effect/steps/pending state/telemetry/unlocks.
- [x] **RESET** for field effect, runtime, DScrete save, inventory, unlocks and telemetry.
- [x] No debug NPC/commands are registered in ordinary player mode.
- [ ] Visually smoke-test NPC placement and every curated landing coordinate.

### Phase 5 — Shiny Finder

- [x] Real bag item + public custom item effect.
- [x] 250 eligible steps; initial force chance 1/100.
- [x] Consume only when activation succeeds.
- [x] Existing same effect refuses without consumption.
- [x] A conflicting effect requires a second use to confirm replacement; only the
  confirmed use consumes the Finder.
- [x] Successful manual moves decrement; wall bumps, warps and menu frames do not.
- [x] Natural grass/water/fishing encounters are marked through public encounter
  hooks; static/gift/trade/trainer Pokemon are not.
- [x] Successful rolls generate valid Gen-1 virtual-shiny DVs and verify them with
  the engine's own `Stats.isShiny` predicate before applying.
- [x] Species, level and moves are preserved; stats and HP are recalculated.
- [x] Runtime-only Finder state clears at `game.ready` instead of leaking across a
  loaded/restarted run.
- [x] Deterministic DV/chance tests plus a seeded statistical rate test.
- [ ] Complete the in-game smoke matrix against the pinned engine build.

## Shared runtime contract

The framework separates persistent and runtime state. Persistent values belong in
`mod.save`; temporary callbacks, menu state, active encounter candidates, and other
live references must never be serialized.

A timed field effect has one common lifecycle:

```text
id
duration_steps
can_activate(context) -> reason
on_activate(context)
on_step(context)
on_encounter(context, encounter)
on_expire(context)
```

Only successful eligible overworld movement decrements duration. Menu movement,
wall bumps, warps, forced/scripted movement, and battle turns do not. Map changes do
not silently reset an active duration. Expiration must occur once and leave no stale
replacement or encounter state behind.

Only one encounter-modifying field effect may be active at once. Replacing one is
an explicit player decision and the new consumable is not removed until replacement
has actually committed.

## Consumable transaction contract

Every consumable follows the same order:

1. Validate context and target/selection requirements.
2. Preview irreversible consequences where appropriate.
3. Apply the effect.
4. Consume exactly one item only after successful application.
5. Return through the normal Gen1Recomp item-use path.

Cancellation, invalid targets, failed context checks, full-party edge cases, unsafe
warps, and closed menus consume nothing.

## Encounter contracts

### Rare Lure

1. Group nonzero encounter slots by species.
2. Sum duplicate-slot weights for each species.
3. Identify the lowest nonzero combined weight (including ties).
4. Multiply those species' slot weights by a configured factor.
5. Normalize without reviving zero-weight slots.

It changes relative species odds only: not encounter frequency, level, or the set of
native species.

### Mystery Lure

Candidates are curated by habitat with explicit progression requirements. A small
configured share of the table is reserved for valid candidates and native entries
are normalized into the remainder. There is no global fallback pool.

### Species Whistle and Silph Tracker

Both should consume one shared compatibility/combined-weight view. The Whistle
boosts a compatible selected species; the Tracker reports coarse signal bands rather
than exact percentages. Detection logic must not duplicate encounter normalization.

### Shiny Finder

The Finder changes only eligible natural wild Pokemon after creation by replacing
DVs with a valid Gen-1 virtual-shiny combination on a successful roll. It preserves
species, level, moves, encounter selection, and normal battle flow. Gifts, trades,
static encounters, trainer parties, and already-owned Pokemon are outside its scope.

## Category boundaries

Each item belongs to one implementation category:

- **Encounters:** wild tables, generated wild Pokemon, habitats, durations.
- **Detection:** reusable information tools and overworld feedback.
- **Battle:** capture, EXP, and trainer-rematch integration.
- **Pokemon:** moves, evolution, fossils, and DV operations.
- **Travel:** map, PC, warp, and safe-return behavior.

Cross-category dependencies should use explicit shared interfaces. For example,
Detection may read the normalized encounter view from Encounters, but should not
reimplement its weighting rules.

## Specific future-item constraints

- **Link Cable:** accepts only Kadabra, Machoke, Graveler, and Haunter. It should use
  the existing trade/evolution presentation when that flow can return safely.
- **Blank TM:** compatibility stays data-driven; knowing a move is not sufficient to
  bypass recipient compatibility.
- **Map Beacon / PC Transfer / Emergency Teleporter:** all use one shared unsafe-state
  validator and fail without consumption in battles, link rooms, scripted movement,
  invalid map states, and other unsafe contexts.
- **Trainer Beacon:** only explicitly eligible defeated trainers may be rematched;
  story trainers are excluded unless they receive a purpose-built definition.
- **DV modifiers:** must recalculate dependent stats/HP correctly and document how
  shiny-valid combinations are preserved or intentionally changed.

## Test strategy

### Deterministic tests

- Encounter normalization preserves its exact total and never revives zero slots.
- Rare selection handles duplicates, ties, and one-species tables.
- Tracker and Whistle agree on species compatibility.
- Step duration decrements only for eligible movement and expires once.
- Transactions consume once on success and never on cancellation/failure.
- Save round trips preserve persistent state and clear runtime caches.
- Every introduced persisted schema version has a migration test.
- Forced shiny DVs pass Gen1Recomp's own shiny predicate.

### Statistical tests

Seeded simulations compare observed encounter/shiny rates to expected distributions
using tolerances selected before execution. They complement, rather than replace,
deterministic tests.

### In-game smoke matrix

Exercise item use from the bag and overworld around map transitions, blackout,
save/load, evolution, full inventory, Safari entry/exit, scripted movement, and each
explicitly unsafe context. Test Red/Blue-style and Yellow-specific behavior where the
runtime differs.

## Definition of done for each item

An item is complete only when it has:

1. an item definition and implementation category;
2. use/cancel/invalid-context/active/expiration text as applicable;
3. explicit persistence and stacking behavior;
4. data validation;
5. deterministic rule tests;
6. save/load and transition coverage where relevant;
7. documented balance knobs; and
8. no path that consumes it before its effect commits.

## Next implementation order

Extend the shared runtime rather than bypassing it. The recommended sequence is:
Rare Lure -> Silph Tracker -> Mystery Lure -> Species Whistle -> Prototype Repel,
then detection tools, battle/Pokemon tools, and finally trainer/travel items. Oak
Research and other reward systems can consume the same catalogue later without
changing item behavior.
