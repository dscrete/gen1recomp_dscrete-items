# Public API status and remaining gaps

DScrete Items supports Gen1Recomp **>=0.2.5 <0.3.0** with Mod API 2. The integration
harness is currently pinned to **v0.2.74** / commit
`9545ebbb839a8a7ea28472b626681154ab222623` for repeatable validation.

## Public surfaces in use

The current feature set is built primarily on public Mod API surfaces:

- `content.items` and `content.item_effects` for real bag items and transactional use;
- `mod.save` for persistent ownership, reusable gadget state and timed effects;
- `content.maps`, `content.map_scripts`, `content.commands`, `mod.ui` and
  `mod.developer` for authored/debug interactions;
- `mod.world:current()`, `mapOverview()`, `spawnNpc()`, `removeNpc()`, `warpTo()` and
  `startWildBattle()` for field tools and Rocket incidents;
- `movement.collision`, `world.stepped`, `map.entered`, `encounter.roll`,
  `encounter.fishing` and `battle.started` for runtime behavior; and
- `mod.world:effectiveEncounters()` when available for merged encounter-table previews.

Rocket Decoder's temporary actors use runtime NPCs only. Incidents do not permanently
rewrite map blocks, collision, warps or save-map data.

## Pokédex entry seam

The compatibility floor does not expose a public hook for decorating or extending the
native Gen-1 Pokédex entry page. Pokedex Chip therefore uses a deliberately narrow
compatibility seam: it observes `input.step`, identifies the exact
`src.ui.DexEntryMenu` state, and opens a separate AREA DATA screen when SELECT is
pressed. It does **not** monkey-patch, replace, or rebuild the native Pokédex screen.

If Gen1Recomp later publishes a dex-entry action/decorator hook, migrate to that public
surface. Until then, minimum/latest-engine smoke testing of SELECT navigation remains
required.

## Encounter-preview limits

`effectiveEncounters()` can preview merged static tables and compatible
`encounter.table` transformations. DScrete additionally mirrors its own active
Elusive Scent, Mystery Lure, Species Whistle, Safari Kit and Prototype Resonator rules
when building Pokedex Chip statistics.

A read-side screen cannot perfectly predict arbitrary third-party stochastic logic
that only runs at `encounter.roll`/`encounter.fishing` time. Fishing percentages shown
by Pokedex Chip are therefore the species share **conditional on a successful catch
selection**, not the chance that a rod produces a bite at all.

For Old/Good Rod global pools, the Chip lists rows only on maps that expose a known
fishable source through a water encounter table or Super Rod group. This avoids
claiming that every encounter-registry map is fishable without a public inactive-map
shore query.

## Engine-side validation still required

This standalone repository cannot prove rendering, map placement, controller input or
live save/bag behavior by itself. `make test-integration` requires the pinned external
Gen1Recomp checkout and runs Gen1Recomp's own `modkit.py validate`; the smoke matrix in
`integration_tests/README.md` must still be exercised in-game before those validation
items are checked off.
