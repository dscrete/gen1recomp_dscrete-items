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
- [x] Mark implemented catalogue entries explicitly so debug/player UIs do not expose
      future placeholder items or gadgets.
- [x] Allocate a versioned `mod.save` namespace; persist active timed field effects
      while clearing only transient runtime state on load/boot.
- [x] Add explicit save migration support. Schema v3 migrates the legacy
      `shiny_finder` active-effect ID to `prism_scent` without losing remaining steps.
- [x] Implement transactional consumable use: validate/apply first, consume exactly
      one item only after successful activation.
- [x] Implement the shared timed field-effect lifecycle, replacement confirmation,
      eligible-step countdown, persistence, and one-time expiration.
- [x] Add deterministic test helpers and seeded probability simulations.
- [x] Add shared encounter-weight helpers for rarity compression, targeted boosts,
      reserved encounter shares, signal bands, and later encounter modifiers.
- [x] Make every player-facing mod-option label identify the item it belongs to, while
      keeping stable option keys/values for saved-config compatibility.
- [x] Require completed work and changed requirements to update this checklist via
      repository instructions in `AGENTS.md`.

## Developer harness

- [x] Add a developer-only Pallet Town NPC.
- [x] Add **GET ITEMS**, **WARP**, **INSPECT**, and **RESET** flows.
- [x] Route test item grants through the engine's real inventory/script path.
- [x] Keep the harness absent from ordinary player mode.
- [x] Add direct **PRISM SCENT**, **ELUSIVE SCENT**, **MYSTERY LURE**, **PKMN WHISTLE**,
      **PROTO RESONATOR**, **SAFARI KIT**, and **GLITCH DET.** grants.
- [x] Limit **ALL IMPLEMENTED**, gadget unlocks, inventory removal, and debug
      inspection/reset helpers to implemented content only.
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

- [x] **Elusive Scent** — compress the local rarity curve without adding species.
  - [x] Keep the commonest species as the 1x baseline, boost uncommon species, and
        progressively boost rarer species more strongly before normalization.
  - [x] Preserve rarity ordering rather than targeting only the single rarest tier.
  - [x] Keep encounter frequency, species membership, and encounter levels unchanged.
  - [x] Support configurable **MILD / STRONG / EXTREME** compression strengths; very
        rare species approach 2x / 4x / 8x weighting while common species remain at
        baseline.
  - [x] Use the shared configurable 50 / 100 / 250 / 500 / 1000 / 2500 step presets.
  - [x] Keep it mutually exclusive with Prism Scent through the shared field-effect
        replacement flow.
  - [x] Apply to grass, cave/indoor, surf/water, and Safari step encounters; do not
        alter fishing.
  - [x] Compose through the normal `encounter.roll` chain and merged encounter
        registry data instead of replacing vanilla/other-mod logic wholesale.
  - [x] Add optional Wilds of Kanto visible-spawn integration without a dependency.
  - [x] Add deterministic rarity-compression tests, including a Pikachu-like
        uncommon/rare regression that must increase effective share.
  - [ ] Complete minimum-engine and in-game smoke testing, including Wilds and Safari.

- [x] **Silph Tracker** — report coarse current-map signal bands.
  - [x] Implement it as a permanent gadget with no bag slot.
  - [x] Show every local species found by the current effective/merged encounter view.
  - [x] Use **NO SIGNAL / FAINT / WEAK / STRONG / VERY STRONG** bands.
  - [x] Replace unseen species names with **UNKNOWN** while preserving their signal
        strength.
  - [x] Reflect active Elusive Scent, Mystery Lure, Species Whistle, and Safari Kit
        BAIT weighting.
  - [x] Show **INTERFERENCE - DETECTED** while an active Glitch Detector map has
        anomaly tiles, without revealing the anomalous species.
  - [x] Keep scope to the current map only.
  - [x] Present scan results on a dedicated manual scrolling screen with separate name
        and signal lines so long labels never clip and fast-forward cannot skip entries.
  - [x] Add a regression guard that fails standalone tests if `SilphTracker.open()` is
        switched back to the generic `ListMenu` implementation.
  - [ ] Complete minimum-engine and in-game UI/readout smoke testing.

- [x] **Mystery Lure** — reserve a temporary share for one random habitat mystery.
  - [x] Use habitat pools (forest / cave / water / field) rather than per-map tables.
  - [x] Exclude Articuno, Zapdos, Moltres, Mewtwo, and Mew.
  - [x] Default to Pokédex-seen candidates only, with **ALLOW UNSEEN** as a mod option.
  - [x] Randomly choose one valid mystery species per habitat while the effect is
        active and retain the chosen candidate for that habitat.
  - [x] Reserve **LOW 5% / MEDIUM 10% / HIGH 20%** of successful encounters, with LOW
        as the default.
  - [x] Preserve the area's existing encounter level when a mystery species replaces
        the native species.
  - [x] Use the standard 50 / 100 / 250 / 500 / 1000 / 2500 duration presets.
  - [x] Remain mutually exclusive with the other field effects.
  - [x] Apply to ordinary land/water encounters and fishing, but refuse activation in
        Safari Zone maps.
  - [x] Add optional Wilds of Kanto visible-spawn integration without a dependency.
  - [x] Add deterministic preset, habitat, legendary-exclusion, and share tests.
  - [ ] Complete minimum-engine/in-game smoke testing across habitats, fishing, Safari
        refusal, unseen-pool option, and Wilds.

- [x] **Species Whistle** — call one remembered Pokédex-seen non-legendary species.
  - [x] Open the species selector directly when **PKMN WHISTLE** is used from the bag,
        using the public `item.use` hook to defer normal item dispatch until selection.
  - [x] Do not add a permanent Start-menu target entry.
  - [x] Restrict target selection to Pokédex-seen non-legendary species, remember the
        last selection persistently, and start the selector on that remembered row.
  - [x] Cancel selection without consuming the Whistle.
  - [x] If the target is native locally, boost it by configurable **MILD / STRONG /
        EXTREME** 2x / 4x / 8x weighting.
  - [x] By default, fail without consumption when the selected species is not local.
  - [x] Add optional **WHISTLE NONLOCAL** mode with separately labeled **WHISTLE
        NONLOCAL RATE** choices of 0.5% / 1% / 2%.
  - [x] Use shorter duration presets: 25 / 50 / 100 / 250 / 500 / 1000 steps.
  - [x] Remain mutually exclusive with the other field effects.
  - [x] Apply to normal encounters and fishing and reflect the effective chance in
        Silph Tracker.
  - [x] Add optional Wilds of Kanto visible-spawn integration without a dependency.
  - [x] Add deterministic target-boost, non-local-share, preset, and legendary tests.
  - [ ] Complete minimum-engine/in-game smoke testing of in-bag target selection,
        remembered cursor position, local/non-local modes, cancellation, fishing,
        persistence, Tracker reflection, and Wilds.

- [x] **Prototype Resonator** — attract unusually strong specimens of local species.
  - [x] Replace the old Prototype Repel concept/name with **Prototype Resonator**.
  - [x] Preserve the area's native species probabilities and native relative level
        spread rather than filtering species or flattening all slots to one level.
  - [x] Recalculate against the first non-fainted party Pokemon's current level for
        every encounter.
  - [x] Shift local encounter levels upward toward that lead level, never downward.
  - [x] Cap the shifted area's maximum at native maximum +10 / +20 / +35 for
        **MILD / STRONG / EXTREME**, with STRONG as default, and clamp to level 100.
  - [x] Use 50 / 100 / 250 / 500 / 1000 / 2500 steps and the shared mutually-exclusive
        timed field-effect lifecycle.
  - [x] Apply to land/water encounters and fishing; refuse activation in Safari maps.
  - [x] Add optional Wilds of Kanto visible-spawn integration without a dependency.
  - [x] Persist the active effect and exact remaining steps through runtime recreation.
  - [x] Add deterministic tests for caps, level shifting, live first-conscious lead,
        Safari exclusion, native maximums, and persistence.
  - [ ] Complete minimum-engine/in-game smoke testing of grass/cave/surf/fishing,
        fainted-lead fallback, party reordering while active, save/reboot, level-100
        clamp, replacement flow, Safari refusal, and Wilds.

- [x] **Safari Kit** — one Safari-session enhancement chosen on entry.
  - [x] Implement it as a consumable bag item, but do not require manual bag use.
  - [x] When a Safari session reaches an interior Safari map and the player entered
        with a Kit, prompt once with **BAIT / PASS / SAVE KIT**.
  - [x] Consume one Kit only after BAIT or PASS is chosen; SAVE KIT/cancel consumes
        nothing but locks out Kit use for that Safari session.
  - [x] Enforce one entry decision per Safari session even if additional Kits are
        obtained during the run; entering without a Kit also locks that session.
  - [x] Persist BAIT / PASS / skipped / no-kit session state through save/load, and
        clear it only after the underlying `save.safari` session ends.
  - [x] **BAIT** compresses Safari rarity for the whole session without adding species
        or changing catch/flee rules; expose MILD / STRONG / EXTREME with STRONG default.
  - [x] Reflect BAIT-modified encounter signals in Silph Tracker.
  - [x] Add optional Wilds of Kanto visible-spawn integration for BAIT.
  - [x] **PASS** immediately adds configurable 100 / 250 / 500 steps and 3 / 5 / 10
        Safari Balls, defaulting to +250 steps / +5 balls, without resetting position.
  - [x] Manual bag use fails without consumption and explains that the choice happens
        at Safari entry.
  - [x] Add deterministic tests for Safari classification, presets, rarity compression,
        and persisted session-lock state/reset behavior.
  - [ ] Rename the Safari Kit's **BAIT** choice to a distinct term such as **LURE** so
        it cannot be confused with vanilla Safari battle BAIT; update UI, options,
        Tracker wording, tests, and docs together.
  - [ ] Complete minimum-engine/in-game smoke testing of entry timing, low-cost Yellow
        Safari admission, BAIT/Tracker/Wilds behavior, PASS counters, SAVE KIT/cancel,
        no-kit lock, acquiring extra Kits mid-session, leaving/re-entering, and save/
        reboot from each session mode.

- [x] **Glitch Detector** — create visible, safe encounter anomalies on specific tiles.
  - [x] Implement as a consumable timed field effect mutually exclusive with the other
        normal field effects.
  - [x] Seed three nearby passable/water anomaly cells per active map and persist the
        active map plus tile coordinates through save/load under the item reusable key.
  - [x] Keep seeded anomaly cells within Manhattan distance 2-6 of activation when
        possible so the player can actually spot and investigate them.
  - [x] Render a faint always-present tell plus periodic wall-clock flicker inside a
        single 8x8 tile fragment, so anomaly visuals remain visible while standing still
        and never exceed one tile.
  - [x] Keep rendering camera-relative to the saved world cell without mutating map
        blocks, collision, warps, or save-map data.
  - [x] Only alter successful ordinary encounter rolls when the player is standing on
        one of the anomaly cells; ordinary cells keep their normal encounter behavior.
  - [x] Choose anomalies from all loaded Kanto Pokédex species 1-151 except Articuno,
        Zapdos, Moltres, Mewtwo, and Mew; do not use MissingNo or invalid species IDs.
  - [x] Preserve the rolled native encounter level and ordinary catch/battle behavior.
  - [x] Expose **MILD 20% / STRONG 40% / EXTREME 60%** anomaly replacement chances,
        with STRONG default, plus standard 50 / 100 / 250 / 500 / 1000 / 2500 steps.
  - [x] Show only **INTERFERENCE DETECTED** in Silph Tracker rather than revealing the
        anomaly species.
  - [x] Clear persisted anomaly-cell state on expiry/replacement/full DScrete reset.
  - [x] Add deterministic tests for presets, tile selection, state serialization,
        Kanto/legendary filtering, camera transform, and anomaly-cell lookup.
  - [ ] Live-smoke anomaly placement on outdoor grass routes, caves, and water maps;
        verify visible cells correspond to useful encounter terrain rather than inert
        walkable path cells.
  - [ ] Live-smoke the idle flicker at multiple zoom levels, map edges/camera boundaries,
        and save/reboot; verify it stays on one world tile and does not interfere with
        battles, menus, transitions, or Wilds.

- [ ] For each future encounter item, prefer public hook chaining/merged encounter
      views so other encounter, overworld-spawn, and presentation mods remain optional
      and composable rather than becoming dependencies.

## 3. Detection tools — Detection

- [x] Build the permanent **GADGETS** menu and unlock handling.
  - [x] Add **GADGETS** to the Start menu only when at least one implemented
        permanent/reusable DScrete gadget is unlocked.
  - [x] Route Silph Tracker and Treasure Detector through the GADGETS menu.
  - [x] Hide unlocked-but-unimplemented catalogue gadgets from the player-facing menu.
  - [ ] Complete minimum-engine/in-game menu navigation smoke testing.

- [x] **Treasure Detector** — passively signal proximity to uncollected hidden items.
  - [x] Implement as a permanent gadget with no bag slot.
  - [x] Read only uncollected current-map hidden-item markers from `mod.world:mapOverview()`;
        do not reveal the item name or a direction arrow.
  - [x] Use Manhattan distance bands: **FAINT** within 10, **SIGNAL** within 6,
        **STRONG** within 3, **VERY STRONG** at 1, and **DIRECTLY HERE** at 0.
  - [x] While passive mode is enabled, emit a beep only when movement crosses into a
        stronger band; moving within a band or farther away does not spam feedback.
  - [x] Use audio-only passive feedback after live testing showed screen-space text was
        too dependent on zoom/camera presentation.
  - [x] Keep a manual GADGETS screen for the current reading plus **PASSIVE ON/OFF**.
  - [x] Persist the passive toggle under the item reusable-state key so save/load keeps
        the setting and full DScrete reset restores the default ON state.
  - [x] Add deterministic nearest-hidden-item and distance-band tests.
  - [ ] Live-smoke audio-only proximity feedback while walking, including fast-forward,
        menus, battles, and multiple zoom levels.
  - [ ] Verify hidden-item collection immediately removes the signal and that maps
        with no remaining hidden items stay silent.

- [ ] **Pokedex Chip** — display encounter statistics in Pokedex information.
- [ ] **Rocket Decoder** — detect and decode authored temporary incidents.

## 4. Battle tools — Battle

- [ ] **Prototype Ball** — apply a documented condition to the normal capture math.
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
- [ ] After all catalogue items are implemented, review every item key, bag item ID,
      effect ID, reusable-state key, and player-facing name together for consistency,
      collisions, stale prototype names, and migration needs before numbered releases.

## Build delivery

- [x] `make package` creates a minimal `dist/dscrete-items-dev.zip` with the mod
      manifest/entrypoint at the archive root.
- [x] GitHub Actions runs standalone tests and builds the ZIP on pushes and pull
      requests.
- [x] Pushes to `main` update the rolling **Development Build** (`dev`) prerelease and
      replace its attached `dscrete-items-dev.zip`.
- [ ] Add numbered/versioned release assets when tagged public releases are introduced.
