# DScrete Items implementation status

Target: Gen1Recomp **v0.2.74**, commit
`9545ebbb839a8a7ea28472b626681154ab222623`, Mod API 2, Gen 1.

## Phase 1 — Manifest and compatibility

- [x] Complete loadable API-2 manifest with ID, display name, semantic version,
  entrypoint, profile/category, Gen 1 target and engine range.
- [x] Root `main.lua` entrypoint.
- [x] Standalone manifest sanity test based on fields verified against v0.2.74.
- [ ] Run the authoritative `modkit.py validate` in the external pinned engine
  checkout before release.

## Phase 2 — Test layers

- [x] Pure-Lua standalone tests for item metadata, field-effect state,
  replacement/expiration and Shiny Finder probability/DV generation.
- [x] Python remains only for static repository/manifest/upstream-revision checks.
- [x] Separate `make test` and `make test-integration` targets.
- [x] Integration target verifies the exact upstream commit before invoking modkit.
- [x] Engine smoke matrix documented in `integration_tests/README.md`.
- [ ] Add engine regression drivers for individual items as the catalogue grows.

## Phase 3 — Shared item runtime

- [x] Canonical Lua item catalogue with ownership, thematic family and effect type.
- [x] Real bag registration for consumables; permanent/reusable gadgets do not use
  bag slots.
- [x] Versioned `mod.save` namespace for persistent unlock/reusable state.
- [x] Runtime-only field-effect, selected-species, pending EXP, beacon/debug and
  encounter state.
- [x] One-active-field-effect policy with explicit replacement.
- [x] Replacement confirmation expires when the player walks away.
- [x] Eligible-step countdown and one-time expiration.
- [x] Runtime and persistent reset/inspection surfaces for developer tooling.

## Phase 4 — Developer-only Pallet Town harness

Registered only when `mod.developer` is true.

- [x] Appended Pallet Town NPC through `content.maps`.
- [x] Public map-script/custom-command dispatch.
- [x] GET ITEMS: Shiny Finder, all consumables, gadget unlocks, test-item removal.
- [x] Grants use the engine's real `give_item` command and therefore obey real bag
  capacity and stack rules.
- [x] Curated WARP menu using `mod.world:warpTo`, with a runtime RETURN point.
- [x] INSPECT for version/schema/effect/steps/pending state/telemetry/unlocks.
- [x] RESET for field effect, runtime, DScrete save, inventory, unlocks and telemetry.
- [x] No debug NPC/commands are registered in ordinary player mode.
- [ ] Visually smoke-test NPC placement and every curated landing coordinate.

## Phase 5 — Shiny Finder

- [x] Real bag item + public custom item effect.
- [x] 250 eligible steps; initial force chance 1/100.
- [x] Consume only when activation succeeds; battle use/refusal is handled by the
  engine's item-effect contract.
- [x] Existing same effect refuses without consumption.
- [x] A conflicting effect asks for a second use to confirm replacement; only the
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

## Next implementation order

The shared runtime should now be extended rather than bypassed. Recommended order:
Rare Lure -> Silph Tracker -> Mystery Lure -> Species Whistle -> Prototype Repel,
then world-information gadgets, battle/Pokemon items, and finally trainer/travel
activity items. Oak Research and other acquisition/reward systems can consume the
same catalogue and exported runtime later without changing item behavior.
