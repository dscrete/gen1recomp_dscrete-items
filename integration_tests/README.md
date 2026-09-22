# Engine integration tests

These checks require an external Gen1Recomp checkout pinned to **v0.2.74** / commit
`9545ebbb839a8a7ea28472b626681154ab222623`. Set `GEN1RECOMP_ROOT` and run:

```sh
make test-integration
```

The target first verifies the exact upstream revision, then runs Gen1Recomp's own
`modkit.py validate` against this repository with the imported Gen 1 base. That is
the authoritative load/schema/cross-reference check; the standalone Lua tests do
not pretend to validate engine hooks.

The in-game smoke matrix for the first playable slice is:

- developer boot: Pallet Town debug NPC exists; release boot: it does not;
- GET ITEMS uses the real bag path and obeys slot/stack limits;
- SHINY FINDER activates from the bag and consumes exactly one copy on success;
- use in battle refuses and consumes nothing;
- a second Finder while active refuses and consumes nothing;
- legal player steps decrement the counter; wall bumps, menus, warps and scripted
  movement do not;
- expiration is announced once after movement finishes;
- ordinary grass/water/fishing encounters roll at the configured 1/100 force rate;
- gifts, trades, static encounters, owned Pokemon and trainer parties are unchanged;
- forced shiny DVs pass the engine's `Stats.isShiny` predicate and stats/HP are
  recalculated consistently;
- loading/restarting clears runtime-only field effects;
- debug INSPECT and RESET expose/clear the expected DScrete state.

As more items land, engine-facing regression drivers should be added beside this
matrix rather than duplicating Gen1Recomp internals in standalone Python models.
