# DScrete Items implementation status and contracts

Target compatibility: Gen1Recomp **>=0.2.5 <0.3.0**, Mod API 2, Gen 1.
The minimum-version verifier targets tag `v0.2.5`. The ordered backlog lives in
[CHECKLIST.md](CHECKLIST.md).

## Current status

### Shared runtime and delivery

- Loadable API-2 manifest and root `main.lua` entrypoint.
- Canonical Lua item catalogue and real bag registration for consumables.
- Permanent/reusable gadgets use `mod.save` rather than bag slots.
- Versioned save schema with active timed field-effect persistence and migrations.
- One-active-field-effect policy with explicit second-use replacement confirmation.
- Eligible-step countdown and one-time expiration.
- Standalone Lua/static tests, minimum-engine verifier, package target, and rolling
  `dev` prerelease ZIP.
- Developer-only Pallet Town harness with GET ITEMS, WARP, INSPECT, and RESET.
- Debug grants and gadget unlocks expose implemented content only.

### Prism Scent

- Consumable field effect with dedicated Prism IDs and options.
- Configurable shiny odds: 1/1, 1/10, 1/100, 1/1000.
- Configurable duration: 50, 100, 250, 500, 1000, 2500 eligible steps.
- Active state and exact remaining steps persist through save/load and reboot.
- Eligible natural wild encounters only; trainer parties, gifts, trades, statics and
  owned Pokemon are excluded.
- Shiny results use valid Gen-1 DVs and `Stats.isShiny` verification.
- Optional Wilds of Kanto integration marks visible spawns before display and carries
  the same shiny DVs into battle.

### Elusive Scent

- Replaces the earlier planned Rare Lure concept.
- Consumable timed field effect, mutually exclusive with Prism Scent.
- Uses rarity compression rather than boosting only the single rarest tier.
- The commonest combined species weight is the 1x baseline; uncommon species receive
  a boost and progressively rarer species receive progressively larger boosts.
- Duplicate slots are summed before the species-level multiplier is calculated, then
  each species' multiplier is applied back to its original slots.
- MILD / STRONG / EXTREME are compression strengths: very rare species approach
  2x / 4x / 8x weighting while common species remain at baseline.
- Uses the shared duration presets: 50 / 100 / 250 / 500 / 1000 / 2500 steps.
- Changes species weighting only: encounter frequency, levels and species membership
  remain unchanged. Final encounter probabilities are normalized back to the engine's
  256-point table, so common final shares may fall as rarer species become easier to
  find.
- Applies to grass, cave/indoor, surf/water and Safari step encounters; fishing is
  intentionally unchanged.
- Operates through the normal `encounter.roll` chain and merged encounter registry.
- Optional Wilds of Kanto integration chooses visible-spawn species from the same
  compressed merged table when its public exports are available.

### Silph Tracker and GADGETS

- Silph Tracker is a permanent gadget with no bag item.
- The Start menu receives a GADGETS row once at least one implemented permanent/
  reusable DScrete gadget is unlocked.
- Unimplemented catalogue gadgets remain hidden even if stale debug unlock flags exist.
- Tracker scans the current map only and reports every local species using:
  NO SIGNAL / FAINT / WEAK / STRONG / VERY STRONG.
- Unseen species display as UNKNOWN while retaining their signal band.
- Tracker uses the public effective-encounter preview when available, otherwise the
  merged encounter registry; active Elusive Scent rarity compression is reflected in
  either path.
- Player-facing results use a dedicated opaque Tracker screen with manual scrolling.
  Each entry uses two fixed lines (species name, then full signal label), avoiding
  ListMenu clipping and dialogue/fast-forward readability problems.
- Current development acquisition remains debug-only via UNLOCK GADGETS.

## Shared encounter-weight contract

`lib/encounter_weights.lua` is the single source of truth for encounter weighting
used by modifiers and readers. New encounter tools should reuse it rather than
reimplementing rarity or normalization.

For a Gen-1 encounter table:

1. Convert cumulative slot buckets into per-slot weights.
2. Sum duplicate slots by species.
3. Determine each species' rarity relative to the commonest combined weight.
4. Apply the selected rarity-compression curve to species weights.
5. Reapply each species multiplier to its original slots, preserving species/levels.
6. Rebuild normalized cumulative buckets with the final threshold fixed at 256.

The Elusive curve is monotonic: the commonest species receives multiplier 1; rarer
species never receive a smaller raw multiplier than more-common species. The module
also owns coarse Tracker signal-band thresholds.

## Compatibility contract

Compatibility is optional and composable rather than dependency-based.

- Registry-based encounter changes are observed because DScrete reads merged content.
- Live Elusive Scent changes are passed through the normal `encounter.roll` hook chain.
- On engines exposing `mod.world:effectiveEncounters`, Silph Tracker uses that public
  read-side API so compatible table-preview hooks are included.
- Wilds of Kanto is detected only through `mod.find("overworld_wild_spawns").exports`.
  If absent or its expected export is unavailable, DScrete falls back to normal
  Gen1Recomp behavior without failing.
- Presentation mods remain responsible for rendering shiny/overworld appearance;
  DScrete owns gameplay state and encounter weighting.

## Timed field-effect contract

Only one encounter-modifying field effect may be active at once. Replacing one is an
explicit player decision and the new consumable is not removed until replacement has
committed.

Timed effects persist their active effect ID and exact remaining eligible steps in
`mod.save`. Transient encounter markers, menu references and telemetry are not
serialized. Only successful eligible player movement decrements duration; wall bumps,
menus, warps and scripted movement do not.

## Consumable transaction contract

Every consumable follows this order:

1. Validate context and target/selection requirements.
2. Preview irreversible consequences where appropriate.
3. Apply the effect.
4. Consume exactly one item only after successful application.
5. Return through the normal Gen1Recomp item-use path.

Cancellation or failed validation consumes nothing.

## Remaining encounter foundation

### Mystery Lure

Reserve a configured share for curated habitat candidates. Native entries normalize
into the remainder; there is no global fallback pool.

### Species Whistle

Boost one selected compatible species using the same merged distribution and weighting
helpers consumed by Silph Tracker and Elusive Scent. It must never insert an
incompatible species.

### Prototype Repel

Bias eligible encounters toward Pokemon at or above the lead Pokemon's level while
preserving the area's species identity.

## Test strategy

Standalone deterministic tests cover metadata, implemented-only debug/gadget filters,
runtime persistence/migration, field replacement and expiration, Prism Scent shiny
rules, Elusive Scent rarity compression, weighting invariants, Pikachu-like uncommon
share regression, signal bands, and a Silph Tracker module-load smoke test. GitHub
Actions runs them on every push/PR.

Still required before treating these features as fully engine-validated:

- `modkit.py validate` and in-game smoke at the minimum supported engine;
- Elusive Scent grass/cave/surf/Safari behavior in play;
- optional Wilds visible-spawn behavior with Elusive Scent;
- GADGETS Start-menu navigation and the dedicated Silph Tracker screen in play;
- Prism/Elusive replacement and expiration text in mixed-use sessions.

## Definition of done for each item

An item is complete only when it has implementation, text, persistence/stacking
rules, validation, deterministic tests, relevant save/load/transition coverage,
documented balance knobs, and no path that consumes it before its effect commits.

## Next implementation order

The next encounter work is Mystery Lure -> Species Whistle -> Prototype Repel, then
remaining detection, battle, Pokemon and travel tools. Reward/progression systems can
consume the same catalogue later without changing item behavior.
