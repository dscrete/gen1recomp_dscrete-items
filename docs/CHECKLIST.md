# Implementation checklist

This is the ordered delivery backlog for DScrete Items. Work from top to bottom
unless a newly discovered dependency requires reordering. Category labels assign
code ownership; they do not decide how players obtain an item.

## 0. Groundwork

- [x] Pin and document supported Gen1Recomp compatibility as `>=0.2.5 <1.0.0`;
      keep `v0.2.5` as the minimum verification floor and treat `1.0.0` as the next
      explicit compatibility-review boundary.
- [x] Add a reproducible standalone build/package target.
- [x] Make `manifest.json` the semantic-version/update-source authority and package
      releases in Gen1Recomp's preferred `<mod-id>-<version>.zip` form.
- [ ] Complete the minimum-supported-engine in-game smoke matrix.
- [ ] Complete a current-release in-game smoke pass on Gen1Recomp `v0.3.3` after the
      compatibility-range expansion.
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
      **PROTO RESONATOR**, **SAFARI KIT**, **GLITCH DET.**, **TRAINER BEACON**,
      **PROTO BALL**, **EXP BATTERY**, and **LINK CABLE** grants.
- [x] Limit **ALL IMPLEMENTED**, gadget unlocks, inventory removal, and debug
      inspection/reset helpers to implemented content only.
- [x] Show Treasure Detector live band/distance, last trigger/sound result, active
      Glitch Detector tile count, and EXP Battery armed state on **INSPECT** for live
      diagnostics.
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
  - [x] Restrict every anomaly spot to an actual live `isGrassCell()` tile; do not mark
        ordinary paths, cave floor, or water just because those cells are walkable.
  - [x] Expose **1 / 2 / 3 / 5** simultaneous anomaly spots through **GLITCH DET. SPOTS**,
        defaulting to one; all spots are alternate entrances to the same one-shot event.
  - [x] Keep chosen spots within Manhattan distance 2-8 of the activation point and
        exclude warps/hidden-item markers so they remain discoverable and safe.
  - [x] When the player reaches any anomaly spot, suppress that cell's ordinary random
        roll and start one guaranteed wild battle through `mod.world:startWildBattle()`.
  - [x] End the Glitch Detector field effect immediately after that battle starts and
        remove all remaining anomaly spots; never automatically generate another spot.
  - [x] Preserve the map's native grass encounter-level distribution while replacing
        only the species with a random nonlegendary Kanto Pokédex species.
  - [x] Render only an intermittent 8x8 corruption fragment; no permanent marker remains
        now that finding any spot guarantees the single encounter.
  - [x] Add configurable **SUBTLE (~4s) / NORMAL (~2s) / FREQUENT (~1s)** flash cadence,
        defaulting to SUBTLE while retaining FREQUENT for live debugging.
  - [x] Inject anomaly rendering into `drawWorld()` before `endWorldPass()` so saved
        world-cell coordinates are transformed by the same zoom/camera pipeline as the
        terrain instead of being drawn later on the UI canvas.
  - [x] Avoid mutating map blocks, collision, warps, or save-map data.
  - [x] Choose anomalies from all loaded Kanto Pokédex species 1-151 except Articuno,
        Zapdos, Moltres, Mewtwo, and Mew; do not use MissingNo or invalid species IDs.
  - [x] Exclude every species native to the current map plus every species in Mystery
        Lure's current grass-habitat pool, so Glitch encounters are deliberately
        ecologically wrong rather than merely unusual or rare.
  - [x] Show only **INTERFERENCE DETECTED** in Silph Tracker rather than revealing the
        anomaly species.
  - [x] Clear persisted anomaly-cell state on encounter, expiry, replacement, or full
        DScrete reset.
  - [x] Expose a save-safe `glitchDetector.activate(opts)` seam so future authored
        incidents/"curse" mechanics can invoke the same anomaly behavior without the
        player using or owning the bag item.
  - [x] Add deterministic tests for flash/spot presets, grass eligibility, multiple
        unique spots, native-level selection, one-shot termination, habitat/native
        species exclusion, state serialization, Kanto/legendary filtering, camera
        transform, and world-pass injection.
  - [ ] Live-smoke 1/2/3/5 grass-only spot placement on outdoor grass maps; verify any
        chosen spot fires the one guaranteed battle, is outside the local/Mystery Lure
        habitat pools, and every remaining mark disappears.
  - [ ] Verify use fails cleanly without consumption on maps/positions with no eligible
        nearby grass, including caves and water-only locations.
  - [ ] Re-test SUBTLE/NORMAL/FREQUENT idle flicker at multiple zoom levels, map edges/
        camera boundaries, and save/reboot; verify it stays on one world tile and does
        not interfere with battles, menus, transitions, or Wilds.

- [ ] For each future encounter item, prefer public hook chaining/merged encounter
      views so other encounter, overworld-spawn, and presentation mods remain optional
      and composable rather than becoming dependencies.

## 3. Detection tools — Detection

- [x] Build the permanent **GADGETS** menu and unlock handling.
  - [x] Add **GADGETS** to the Start menu only when at least one implemented
        permanent/reusable DScrete gadget is unlocked.
  - [x] Route all implemented permanent/reusable tools through GADGETS, including
        Silph Tracker, Treasure Detector, Pokedex Chip help, and Rocket Decoder.
  - [x] Hide unlocked-but-unimplemented catalogue gadgets from the player-facing menu.
  - [ ] Complete minimum-engine/in-game menu navigation smoke testing.

- [x] **Treasure Detector** — passively signal proximity to uncollected hidden items.
  - [x] Implement as a permanent gadget with no bag slot.
  - [x] Read only uncollected current-map hidden-item markers from `mod.world:mapOverview()`;
        do not reveal the item name or a direction arrow.
  - [x] Use Manhattan distance bands: **FAINT** within 10, **SIGNAL** within 6,
        **STRONG** within 3, **VERY STRONG** at 1, and **DIRECTLY HERE** at 0.
  - [x] While passive mode is enabled and a hidden item is in range, repeat detector
        pulses persistently even while standing still; re-read the marker state every
        frame so collecting the item stops the signal immediately.
  - [x] Use a metal-detector cadence that becomes progressively more urgent by band:
        roughly 3.2s FAINT, 2.0s SIGNAL, 1.05s STRONG, 0.5s VERY STRONG, and 0.22s
        DIRECTLY HERE, with higher/denser tone patterns in the closer tiers.
  - [x] Suppress and reset persistent detector audio while normal field actions are
        busy (menus, battles, transitions, etc.), then resume from the current reading.
  - [x] Use audio-only passive feedback after live testing showed screen-space text was
        too dependent on zoom/camera presentation.
  - [x] Replace the ordinary `Tink` SFX with generated short electronic detector tones;
        keep clearly different pitch/rhythm signatures across the five proximity bands.
  - [x] Respect the player's master SFX-volume setting while exposing a detector-specific
        **QUIET / NORMAL / LOUD / MAX** volume option, defaulting to **LOUD** so the
        navigation cue can cut through normal game music.
  - [x] Fall back to the Gen 1 **Switch** sound if runtime tone synthesis is unavailable.
  - [x] Keep a manual GADGETS screen for the current reading plus **PASSIVE ON/OFF**.
  - [x] Expose the live band/distance and last attempted detector sound in developer
        **INSPECT** so marker detection and audio failures can be separated in-game.
  - [x] Persist the passive toggle under the item reusable-state key so save/load keeps
        the setting and full DScrete reset restores the default ON state.
  - [x] Add deterministic nearest-hidden-item, distance-band, persistent-cadence,
        volume-preset, and tone-pattern tests.
  - [ ] Re-test persistent audio from >10 cells through **DIRECTLY HERE** at all four
        detector volume presets, confirming every band remains distinguishable over
        normal music and pauses become noticeably shorter as distance closes.
  - [ ] Verify hidden-item collection immediately removes the signal and that maps
        with no remaining hidden items stay silent.

- [x] **Pokedex Chip** — display live encounter statistics from seen Pokédex entries.
  - [x] Implement as a permanent gadget with no bag slot.
  - [x] Keep encounter data locked until the species has been SEEN; ownership is not
        required.
  - [x] Open a dedicated **AREA DATA** experience with SELECT from a highlighted seen
        species in the native Pokédex list or from its native DATA entry; keep the
        GADGETS row as help/discoverability rather than a second dex.
  - [x] Show all locations represented by merged encounter/fishing data with encounter
        method, effective species share, and effective level range.
  - [x] Reflect merged/effective tables plus active Elusive Scent, Mystery Lure,
        Species Whistle, Safari Kit weighting, and Prototype Resonator level shifts.
  - [x] Treat rod percentages as species share conditional on successful catch
        selection rather than pretending to include the separate no-bite chance.
  - [x] Preserve runtime fishing replacement semantics for local/non-local Species
        Whistle and Mystery Lure previews.
  - [x] Use a dedicated scrolling Gen-1-style screen with the native menu cursor.
  - [x] Add deterministic level-range, fishing-distribution, replacement-share, and
        native-dex-entry navigation regression tests.
  - [ ] Smoke-test SELECT list/entry navigation, seen/not-seen gating, long location
        names, land/surf/rod rows, scrolling, and live field-effect changes in game.

- [x] **Rocket Decoder** — enable and decode authored temporary Rocket incidents.
  - [x] Spawn no incidents while the Decoder is locked; after unlock, maintain at most
        one active incident globally.
  - [x] Use a progression-gated semi-random scheduler with a generous step-based
        incident window and cooldown between events.
  - [x] Gate locations from actual Gen1Recomp progression evidence: nearby fly-town
        visit flags, optional required items, and current-region presence; do not treat
        `save.visited` as a nonexistent route/dungeon history table.
  - [x] Keep the incident catalogue data-driven: locations/progression, actors,
        transmissions, prototype pools, dialogue interactions, and outcomes are
        authored content layered on one reusable framework.
  - [x] Support multi-stage decoded transmissions: initial broad signal, improved
        region clue, local signal, and incident-specific additional stages.
  - [x] Add only temporary runtime NPCs/interactables and remove them on map leave,
        resolution, expiry, reset/reload as appropriate; never permanently rewrite
        map blocks, collision, warps, or map save data.
  - [x] Persist active incident ID, chosen location, stage, phase, remaining window,
        randomized cargo, recent transmission archive, and operative memory.
  - [x] Add recurring named operatives **Ronnie**, **Milo**, and **Cass** with authored
        personality dialogue and lightweight memory for meetings, incident outcomes,
        actual trainer-battle wins/losses, last battle result, and selected flags.
  - [x] Support conditional authored conversation paths so previous outcomes and
        operative history can expose or remove later resolutions.
  - [x] Make Milo's cooperative cache split available only when the player's most
        recent actual trainer battle against Milo was a win; a later loss closes that
        offer again until Milo is beaten.
  - [x] Present incident conversation choices in a compact bordered menu over the
        overworld instead of an opaque full-screen `ListMenu`; keep Decoder archive/
        management screens full-screen where appropriate.
  - [x] Give Ronnie, Milo, and Cass distinct authored trainer classes with four party
        tiers selected from badge/story progress plus incident minimum tiers; do not
        scale directly to the player's exact Pokémon levels.
  - [x] Support multiple authored conversation paths and meaningful non-battle
        resolutions rather than forcing every incident into one trainer battle.
  - [x] Distinguish `RESOLVED_WIN`, `RESOLVED_ALTERNATE`, `ROCKET_SUCCESS`, and
        `EXPIRED` so a direct loss can affect later dialogue without treating a missed
        event as a remembered Rocket victory.
  - [x] Roll the incident's primary prototype cargo once at spawn from an authored pool
        of implemented DScrete consumables; never include permanent gadgets and never
        reroll the cargo on save/load.
  - [x] Add **ACTIVE SIGNAL**, **TRANSMISSIONS**, and **OPERATIVE DATA** Decoder views
        plus a developer-only force-incident menu.
  - [x] Ship three initial templates with distinct gameplay verbs:
        **Intercepted Shipment** (Ronnie/dialogue/hunt), **Hidden Cache**
        (Milo/decode/search), and **Illegal Experiment** (Cass/investigate/sabotage).
  - [x] Complete a dialogue-quality pass across all three initial incidents so player
        prompts read naturally and each recurring operative has a distinct voice.
  - [x] Add deterministic tests for state serialization, progression gates,
        current-region eligibility, safe open-cell actor placement, party tiers,
        compact conversation UI, conditioned paths, prototype pools, and memories.
  - [ ] In-game smoke all three incidents through win/alternate/loss/expiry paths,
        staged signals, compact conversation menus, party tiers, conditioned Milo
        negotiation, save/reload, map leave/re-entry, actor cleanup, reward delivery,
        archive entries, and remembered later dialogue.

## 4. Battle tools — Battle

- [x] **Prototype Ball** — trade terrible high-HP performance for exceptional low-HP capture power.
  - [x] Register a real consumable bag item and custom `content.balls` definition.
  - [x] Keep ordinary Poké Ball roll/HP/wobble factors and throw animation so the custom behavior is isolated to the effective catch-rate input.
  - [x] Above 50% HP, halve the target's effective species catch-rate input, making the Ball deliberately worse than a normal Poké Ball.
  - [x] At 26–50% HP, use the normal Poké Ball catch-rate input unchanged.
  - [x] At 11–25% HP, double the effective catch-rate input.
  - [x] At 10% HP or less, triple the effective catch-rate input, capped at 255, for a substantial advantage over an Ultra Ball on badly weakened targets.
  - [x] Treat an existing catch-rate override as the baseline before applying the health-band multiplier.
  - [x] Delegate back to `ctx.vanillaAttempt()` so ordinary Gen-1 HP math and status catch bonuses still stack after the Prototype Ball's health-based adjustment.
  - [x] Let the normal bag/battle `ball` path own consumption, trainer refusal, animation, and battle turn cost.
  - [x] Add deterministic tests for all four HP boundaries, high-HP penalty, low-HP cap, override composition, ball baseline values, and vanilla-attempt delegation.
  - [ ] In-game smoke throws above 50%, around 50%, at 25%, and at <=10% HP; verify status bonuses still stack, plus trainer refusal, bag consumption, throw/wobble animation, party/PC storage, and Pokédex updates.

- [x] **EXP Battery** — arm a persistent 2× bonus for the next defeated Pokémon payout.
  - [x] Implement as a field-use consumable; refuse another Battery while already armed
        without consuming it.
  - [x] Persist armed state through save/load under the standard reusable-state key.
  - [x] Apply 2× to every positive normal battle EXP share from the next defeated
        Pokémon, including multiple participant / EXP.ALL-style shares.
  - [x] Keep the charge armed through ordinary turns with no positive EXP.
  - [x] Clear the charge after the payout turn (or battle end) once it actually applied.
  - [x] Keep Rare Candy and other non-battle growth outside the Battery bonus.
  - [x] Use `exp.gain` plus battle lifecycle events available at the 0.2.5 floor; do not
        require the newer `battle.exp_award` hook.
  - [x] Expose direct developer grant and armed-state INSPECT diagnostics.
  - [x] Add deterministic tests for persistent arming, duplicate-use refusal,
        multi-share grouping, empty turns, battle-end cleanup, and hook-floor regression.
  - [ ] In-game smoke wild/trainer payouts, multi-participant shares, EXP.ALL where
        available, level-up/move learning, save/reload, Rare Candy exclusion, and reset.

- [x] **Trainer Beacon** — rematch a defeated ordinary trainer through a physical nearby signal.
  - [x] Require the player to face the trainer NPC and require that NPC's extracted
        trainer-defeat event flag to already be set; never use the Beacon for a first battle.
  - [x] Exclude Gym Leaders, Elite Four, rivals, Giovanni, Professor Oak, and broad
        scripted Rocket-class battles by default while exposing explicit per-target
        eligibility overrides for later authored exceptions.
  - [x] Preserve the trainer's current merged original party composition, then add
        **+5 / +10 / +15 / +20** levels by badge tier instead of scaling to the player's
        exact party level.
  - [x] Recursively apply only ordinary **LEVEL** evolutions reached by those boosted
        levels; do not infer stone, trade, or other special evolutions from level alone.
  - [x] Compose through the public `trainer.party` hook so other trainer-party mods can
        contribute their party before the Beacon applies its rematch boost.
  - [x] Give normal battle EXP while reducing rematch prize money to roughly 50% by
        using a battle-local copy of the trainer reward multiplier.
  - [x] Consume one Beacon only after a valid defeated target and cooldown are accepted;
        invalid, undefeated, excluded, unavailable, or cooling-down targets consume nothing.
  - [x] Persist per-trainer rematch count and a step-based cooldown; expose
        **100 / 250 / 500 / 1000 / 2500** step presets with **500** as default.
  - [x] Author exactly **10 first-rematch + 10 later-rematch** dialogue variants for
        every supported ordinary Gen-1 trainer class, with a 10+10 generic fallback for
        unknown/modded classes.
  - [x] Mix neutral, competitive, humorous, and occasional dark/spooky class-specific
        writing and support generated-party placeholders such as `{STRONGEST}`.
  - [x] Wrap generated dialogue to Gen-1 text width and derive trainer personality from
        the actual trainer class rather than guessing from overworld sprite art.
  - [x] Add direct developer grant plus deterministic tests for tiers, evolution rules,
        class exclusions/overrides, cooldowns, strongest-Pokémon substitution, dialogue
        counts/width, and implemented-catalogue exposure.
  - [ ] In-game smoke ordinary trainers from several classes across all four badge tiers,
        first/later dialogue variation, strongest-Pokémon substitutions, recursive level
        evolution, 50% reward behavior, cooldown persistence, save/reload, invalid/story
        targets, loss/blackout handling, and interaction with another trainer-party mod.

## 5. Pokemon tools — Pokemon

- [x] **Link Cable** — perform the same semantic evolution trigger as a completed trade.
  - [x] Implement as a consumable party tool with no level requirement of its own.
  - [x] Build the selector from only party Pokémon whose merged evolution method accepts
        `{ kind = "trade" }`; do not hard-code Kadabra/Machoke/Graveler/Haunter.
  - [x] Allow modded/Fakemon trade evolutions automatically when their merged evolution
        method responds to the standard trade trigger and the target species exists.
  - [x] Permit cancel from the target selector and confirmation without consuming the item.
  - [x] After **USE CABLE** confirmation, close the Bag and parent Start menu before
        normal item dispatch consumes one Cable and shows the link-connection message,
        so the native evolution presentation no longer waits behind an open menu.
  - [x] Pass `via="TRADE"` to the native evolution screen so a confirmed Cable evolution
        keeps real trade semantics: native animation/apply/move-learning and no B-cancel
        once the connection has committed.
  - [x] Fail cleanly without consumption when the party has no eligible trade evolution.
  - [x] Add deterministic tests for standard TRADE, custom semantic trade methods,
        non-trade exclusion, eligible-only party filtering, confirmed menu unwind, and
        a regression guard against reintroducing a hard-coded vanilla species list.
  - [ ] In-game smoke Kadabra/Machoke/Graveler/Haunter plus at least one compatible
        modded trade evolution, selector/confirmation cancellation, immediate Bag/Start
        menu unwind after confirmation, item consumption, native animation, evolved-species
        move learning, Pokédex flags, save state, and inability to B-cancel after confirmation.

- [ ] **Move Recorder** — offer an eligible missed level-up move.
- [ ] **Fossil Catalyst** — apply a disclosed modifier during fossil revival.
- [ ] **DNA Stabilizer** — improve DVs within bounded shiny-safe rules.
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

- [x] `make package` creates a minimal updater-compatible
      `dist/gen1recomp_dscrete_items-X.Y.Z.zip` with the manifest/entrypoint at archive
      root and derives `X.Y.Z` from `manifest.json`.
- [x] GitHub Actions runs standalone tests and builds the versioned ZIP on pushes and
      pull requests.
- [x] Validate numeric `X.Y.Z` manifest versions plus the
      `dscrete/gen1recomp_dscrete-items` GitHub update source in standalone tests.
- [x] On `main`, publish exactly one non-prerelease `vX.Y.Z` GitHub release when that
      manifest version has not already been released; ordinary commits at the same
      version do not publish another update.
- [x] Attach `gen1recomp_dscrete_items-X.Y.Z.zip` so Gen1Recomp's updater selects its
      preferred exact `<mod-id>-<version>.zip` asset.
- [x] Keep player-facing release history in `CHANGELOG.md` and require completed release
      work to verify the matching tag, release, asset, CI, and final `main` commit.
