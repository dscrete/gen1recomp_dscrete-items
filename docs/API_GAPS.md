# Public API status and remaining gaps

DScrete Items supports Gen1Recomp **>=0.2.5 <0.3.0** with Mod API 2. The integration
harness is currently pinned to **v0.2.74** / commit
`9545ebbb839a8a7ea28472b626681154ab222623` for repeatable validation.

## Public surfaces in use

The current feature set is built primarily on public Mod API surfaces:

- `content.items` and `content.item_effects` for real bag items and transactional use;
- `content.balls` plus the stock custom-ball `attempt`/`vanillaAttempt` contract for
  Prototype Ball capture behavior;
- `mod.save` for persistent ownership, reusable gadget state, timed effects, the EXP
  Battery's armed charge, and Trainer Beacon rematch/cooldown state;
- `content.maps`, `content.map_scripts`, `content.commands`, `mod.ui` and
  `mod.developer` for authored/debug interactions;
- `mod.world:current()`, `mapOverview()`, `spawnNpc()`, `removeNpc()`, `warpTo()`,
  `queueScript()` and `startWildBattle()` for field tools, rematches, and Rocket incidents;
- `movement.collision`, `world.stepped`, `map.entered`, `encounter.roll`,
  `encounter.fishing`, `exp.gain`, `trainer.party`, and battle lifecycle events for
  runtime behavior; and
- `mod.world:effectiveEncounters()` when available for merged encounter-table previews.

Rocket Decoder's temporary actors use runtime NPCs only. Incidents do not permanently
rewrite map blocks, collision, warps or save-map data.

## Battle-tool compatibility

Prototype Ball needs no private capture seam. `content.balls` already exists at the
Gen1Recomp 0.2.5 floor and custom ball attempts receive `ctx.vanillaAttempt()`, so the
mod can change only the effective species catch-rate input and then return to the
ordinary Gen-1 catch implementation.

EXP Battery deliberately does **not** depend on `battle.exp_award`. That grouping hook
was added after the supported 0.2.5 floor. The Battery instead uses the floor-compatible
`exp.gain` hook, with `battle.started`, `battle.turn_ended`, and `battle.ended` events
to keep one transient payout window open through all normal EXP shares produced by the
next defeated Pokémon. This retains the existing engine compatibility claim without
copying or patching `BattleState:awardExp()`.

Trainer Beacon composes through `trainer.party`: the downstream/current merged party
is resolved first, then the Beacon copies that party, applies its badge-tier level
increase, and follows only ordinary LEVEL evolution rows reached by those new levels.
The public field API does not expose a list of nearby trainer NPCs, so target discovery
uses the item-effect context's documented live `overworld` reference to inspect the
trainer NPC occupying the player's facing cell. The trainer header's existing defeat
event remains the authority for whether the trainer is rematchable.

## Link Cable evolution seam

Gen1Recomp's merged `evolution_methods` registry has exposed the standard TRADE method
since the supported 0.2.5 floor. Link Cable therefore determines eligibility by asking
each current evolution row's merged method whether it accepts `{ kind = "trade" }`.
This avoids a Kadabra/Machoke/Graveler/Haunter whitelist and automatically includes
compatible modded/Fakemon evolution methods that use the same semantic trigger.

After confirmation, Link Cable opens the public native `EvolutionState` with
`via="TRADE"`, preserving the normal evolution animation, apply/Pokédex behavior,
post-evolution move learning, and genuine non-cancelable trade presentation.

One public-API limitation remains: the mod-facing hook facade exposes `wrap`, but no
public `call`/`requestEvolution` operation with which another mod can explicitly invoke
Gen1Recomp's global `evolution.check` wrapper chain for a synthetic trigger. Link Cable
therefore honors the **merged evolution method's own check function**, but a third-party
mod that blocks evolution *only* by wrapping `evolution.check` will not see the Link
Cable's preflight eligibility check. If Gen1Recomp publishes a public evolution-request
entry point, Link Cable should migrate to it and remove this limitation.

## Pokédex navigation seam

The compatibility floor does not expose a public hook for decorating or extending the
native Gen-1 Pokédex list or entry page. Pokedex Chip therefore uses a deliberately
narrow compatibility seam: it observes `input.step`, identifies either the exact
`src.ui.PokedexMenu` list or `src.ui.DexEntryMenu` state, and opens a separate AREA
DATA screen when the previous fixed step contained SELECT. On the list it reads only
the highlighted row's existing `value`, which Gen1Recomp exposes only for known
Pokémon; unseen dashed rows therefore remain inert.

`input.step` runs before fresh button edges are promoted, so the Chip intentionally
observes the prior fixed step's SELECT edge rather than trying to read a new edge too
early. The native Pokédex list and entry page do not consume SELECT, so the state is
still present when that edge is observed one tick later. This keeps keyboard, gamepad,
raw joystick and touch mappings on the engine's normal input path. The Chip does
**not** monkey-patch, replace, or rebuild either native Pokédex screen.

If Gen1Recomp later publishes a Pokédex action/decorator hook, migrate to that public
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
