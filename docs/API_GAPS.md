# Public API status and remaining gaps

DScrete Items targets Gen1Recomp **v0.2.74** at commit
`9545ebbb839a8a7ea28472b626681154ab222623` and uses Mod API 2 public surfaces.

## Resolved for the first playable slice

The v0.2.74 API already supplies the pieces needed for Phases 1-5:

- `content.items` and `content.item_effects` for real bag items and transactional use;
- `mod.save` for persistent DScrete ownership/state;
- `content.maps`, `content.map_scripts`, `content.commands`, `mod.ui` and
  `mod.developer` for the developer-only Pallet Town harness;
- `mod.world:current()` / `warpTo()` for debug navigation;
- `movement.collision` for successful manual-step accounting;
- `encounter.roll` and `encounter.fishing` to identify natural random encounters;
- `battle.started` to receive the newly-created wild battle object; and
- the sandbox-supported `src.pokemon.Stats` helper for `Stats.isShiny` and stat
  recalculation.

Gen 1 does **not** expose Gen 2's `shiny.roll` hook. The Shiny Finder therefore marks
a candidate only when it comes from the natural encounter hooks, then changes that
new battle Pokemon's DVs at `battle.started`. Static battles, gifts, trades and
trainer parties never receive the natural-encounter marker. This is the narrowest
public-API implementation available in v0.2.74 and avoids engine-internal requires.

## Still requiring engine-side execution

This standalone repository cannot prove rendering, map placement or live save/bag
behavior by itself. `make test-integration` deliberately requires an external
checkout at the exact pinned commit and runs Gen1Recomp's own `modkit.py validate`.
The smoke matrix in `integration_tests/README.md` must also be exercised in-game
before a release build is tagged.

Future items may reveal new public API gaps. Record those here when discovered;
do not replace a missing public seam with an undeclared engine-internal dependency.
