# Changelog

All notable player-facing changes to DScrete Items are recorded here.

Versions follow semantic versioning while the mod is pre-1.0: feature releases bump the minor version and focused fixes bump the patch version.

## 0.9.0 — 2026-10-28

### Added

- Map Beacon, a one-point persistent field anchor storing exact map, tile and facing. First use offers SET BEACON; later uses offer RETURN / RELOCATE / CANCEL.
- SET, RELOCATE and RETURN each consume exactly one Beacon only after the action commits successfully. A successful return keeps the saved anchor for later reuse.
- RETURN previews the saved map name, relocation confirms the old/new location, and successful placement reports that the Beacon location was recorded.
- Shared destination validation now rechecks merged map/tileset collision, bounds, warp/door cells, engine-exposed map markers and visible objects before Beacon travel; active-map destinations additionally reject live NPC occupancy.
- Beacon placement/return refuses Safari, link rooms, S.S. Anne and Vermilion Dock, one-way Elite Four progression rooms, and busy/scripted field states, while allowing ordinary permanent interiors, gyms, caves and dungeons independently of Escape Rope rules.
- Map Beacon remains pure travel: HP, status, money and active DScrete effects are preserved, and changed/invalid/occupied destinations fail without consumption.
- Direct developer grant supplies two Beacons for immediate SET+RETURN testing, with deterministic coverage for persistence, relocation, successful-only consumption, collision/object/NPC validation and failed warps.

### Changed

- The shared travel-safety layer now supports reusable exact-tile destination validation for player-defined travel anchors.
- Every planned catalogue item now has an implemented behavior path; catalogue-wide validation, naming, balance/source decisions and in-game smoke work remain tracked separately.

## 0.8.0 — 2026-10-28

### Added

- PC Transfer Unit, a one-use portable Pokémon-storage link that opens Gen1Recomp's native Bill's PC storage menu directly rather than exposing the full PC or item storage.
- A brief **Connecting to POKEMON STORAGE...** handoff after the Bag/Start flow closes and the normal field-safety gate confirms free-roam control.
- PC Transfer Unit uses the shared Safari/link/busy-state travel guards and refuses battle, scripts, forced movement, transitions and other unsafe field states.
- The storage session is an in-place UI overlay rather than a temporary warp, so map position/facing, party HP/status, money, DScrete timed effects and unrelated incident/world state remain unchanged.
- Successful native storage opening consumes exactly one Unit; invalid context, persistent busy state or native storage-open failure consumes nothing.
- Direct developer-harness grant and deterministic tests for open timing, successful-only consumption, state preservation, Safari/link/busy refusal and native Pokémon-storage-only routing.

### Changed

- The implemented travel catalogue now includes Emergency Teleporter and PC Transfer Unit.

## 0.7.0 — 2026-10-28

### Added

- Blank TM, a consumable recorder that copies one currently known non-HM move without removing it from the source Pokémon and converts into a persistent, non-overwritable RECORDED TM.
- RECORDED TM teaching is data-driven from merged species data: ordinary machine compatibility plus natural starting/level-up learn data qualify, including compatible modded Pokémon and moves. The final teach uses Gen1Recomp's native learn/forget flow and consumes the recorded copy only after a move is actually learned.
- Multiple recorded moves can coexist behind the protected RECORDED TM bag entry; their move identities persist independently and are removed only with the matching successfully used copy.
- Emergency Teleporter, a consumable safe-field travel tool that returns to the canonical exterior landing associated with the save's last valid Pokémon Center heal point.
- Emergency Teleporter refuses Safari, link rooms, battle and busy/scripted field states, but works from ordinary caves/buildings/dungeons without Escape Rope restrictions. It preserves HP, status, money and DScrete runtime effects, and consumes only after the public warp request succeeds.
- Direct developer-harness grants for Blank TM and Emergency Teleporter plus cleanup for recorded-TM test state.

### Changed

- The implemented Pokémon-tool catalogue now includes Blank TM, and the travel catalogue now includes Emergency Teleporter.
- Added a shared conservative travel-safety helper for link-room, Safari and public field-readiness checks that later travel tools can reuse.

## 0.6.0 — 2026-09-24

### Added

- DNA Stabilizer, a consumable party genetics tool that improves non-shiny Pokémon by +1 in each stored primary Gen-1 DV, capped at 15, then immediately rebuilds the derived HP DV and party stats.
- Existing shiny Pokémon use a stricter preservation rule: Defense/Speed/Special stay at the engine-required value of 10 and Attack advances only to the next higher Attack DV accepted by Gen1Recomp's shiny predicate. If no shiny-safe improvement remains, the Pokémon is not offered as a target.
- Mutation Capsule, a consumable party tool that randomly chooses one of Attack/Defense/Speed/Special and rerolls it uniformly to one of the other 15 possible DV values. The exact DV change, derived HP DV change, and shiny-status change are previewed before confirmation.
- Mutation Capsule previews are persisted by Pokémon/DV signature. Cancelling keeps the item and preserves that exact pending result across bag reopen, party reordering, and level/EXP changes instead of allowing free reroll fishing; accepting consumes one Capsule and clears the stored offer.
- Both genetics tools immediately recalculate party stats while preserving full-health state, keeping damaged HP as an absolute value, and leaving fainted Pokémon fainted.
- Direct developer-harness grants for DNA Stabilizer and Mutation Capsule.

### Changed

- The implemented Pokémon-tool catalogue now includes Link Cable, Move Recorder, Fossil Catalyst, DNA Stabilizer and Mutation Capsule.

## 0.5.0 — 2026-09-24

### Added

- Move Recorder, a consumable party tool that lists only Pokémon with an eligible missed natural move, then offers starting/level-up moves from the Pokémon's merged evolutionary ancestry at or below its current level. Earlier-stage moves remain available after evolution, including moves skipped by evolving early; TM/HM/tutor/event-only compatibility is excluded.
- Move Recorder delegates the final choice to Gen1Recomp's native move-learning flow, including normal four-move replacement, HM-forget protection, learned-move presentation and cancellation. The Recorder is consumed only after a move is actually learned.
- Fossil Catalyst, an optional consumable offered during the real Cinnabar fossil handover. Accepting it overclocks revival to Lv.35 / 40 / 45 / 50 across the same four broad badge tiers used by Trainer Beacon, never lowering a modded revival that already starts higher.
- Fossil Catalyst recursively applies only ordinary level evolutions reached by the overclocked level. The resulting gift then uses Gen1Recomp's normal Pokémon construction, storage, nickname and Pokédex path, so its natural reconstructed moveset is the normal four-move set appropriate to the resulting species and level.
- Fossil Catalyst is data-driven: the Cinnabar integration keys off the pending lab fossil state rather than a Helix/Dome/Old Amber species list, allowing compatible modded fossil species to participate.
- Direct developer-harness grants for Move Recorder and Fossil Catalyst.

### Changed

- The implemented Pokémon-tool catalogue now includes Link Cable, Move Recorder and Fossil Catalyst.

## 0.4.2 — 2026-09-23

### Fixed

- Link Cable now closes the Bag and parent Start menu immediately after **USE CABLE** is confirmed, so its connection text and native trade-evolution presentation begin without requiring the player to manually back out of the menu first.
- Target selection and confirmation cancellation still leave the menus open and consume nothing.

## 0.4.1 — 2026-09-23

### Fixed

- Expanded the supported Gen1Recomp engine range from `>=0.2.5 <0.3.0` to `>=0.2.5 <1.0.0`, so the mod can load on Gen1Recomp 0.3.3 and later compatible 0.x Mod API 2 releases instead of being blocked by an arbitrary minor-version ceiling.
- Kept `v0.2.5` as the compatibility floor while reserving `1.0.0` as the next explicit engine-compatibility review boundary.

## 0.4.0 — 2026-09-23

### Added

- Trainer Beacon, a consumable rematch tool for defeated ordinary trainers. Use it while facing an eligible trainer to rebuild their current merged original party with a badge-tier +5 / +10 / +15 / +20 level boost, automatically applying ordinary level evolutions that the boosted levels have reached.
- Trainer Beacon rematches keep normal EXP, reduce prize money to roughly half, and use a configurable per-trainer step cooldown with 500 steps as the default.
- Trainer Beacon dialogue includes 10 first-rematch and 10 later-rematch variants for every supported ordinary Gen-1 trainer class, plus generic modded-class fallbacks and generated-party references such as the rematch team's strongest Pokémon.
- Link Cable, a consumable party tool that asks merged evolution methods whether a Pokémon responds to a semantic trade trigger instead of hard-coding the four vanilla trade-evolution species. Compatible modded/Fakemon trade evolutions therefore work automatically.
- Direct developer-harness grants for Trainer Beacon and Link Cable.

### Changed

- Link Cable confirmation now commits to genuine trade semantics: the item is not consumed while selecting/canceling, but after confirmation it uses the native trade-evolution presentation and cannot be B-cancelled during the evolution.

## 0.3.1 — 2026-09-23

### Changed

- Prototype Ball is now health-driven rather than status-driven. Above 50% HP it is deliberately poor at half a Poké Ball's effective catch-rate input; at 26–50% HP it matches a Poké Ball; at 11–25% HP it doubles the catch-rate input; and at 10% HP or less it triples it, giving a substantial payoff over Ultra Ball performance on badly weakened targets.
- Prototype Ball still delegates to Gen1Recomp's normal Gen-1 capture flow after rewriting the catch-rate input, so ordinary HP math and status catch bonuses continue to stack normally.
- EXP Battery behavior is unchanged from 0.3.0.

## 0.3.0 — 2026-09-23

### Added

- Prototype Ball, a consumable experimental Poké Ball that uses ordinary Poké Ball math and doubles the target's effective species catch rate when the target already has a major status condition, capped at 255.
- EXP Battery, a field-use consumable that persists an armed 2× battle-EXP charge through save/load and applies it to every normal EXP share from the next defeated Pokémon before disarming.
- Direct developer-harness grants and EXP Battery armed-state diagnostics for both new battle tools.

### Changed

- EXP Battery deliberately uses the long-standing `exp.gain` hook plus battle lifecycle events instead of the newer `battle.exp_award` hook, preserving the advertised Gen1Recomp 0.2.5 compatibility floor.

## 0.2.2 — 2026-09-23

### Fixed

- Pokédex Chip AREA DATA now opens when SELECT is pressed directly on a highlighted seen Pokémon in the native Pokédex list.
- The existing SELECT shortcut on the Pokémon's DATA entry remains available, while unseen dashed rows stay inert.
- Pokédex Chip help and integration coverage now describe the actual list-first navigation path.

## 0.2.1 — 2026-09-23

### Changed

- Rewrote the first three Rocket incidents' conversations for stronger character voice, more natural player choices, and less placeholder-style dialogue.
- Rocket conversation choices now use a compact bordered menu over the overworld instead of an opaque full-screen list.
- Ronnie, Milo, and Cass now use distinct authored trainer parties that advance through four badge/progression tiers instead of all borrowing the same fixed vanilla Rocket party.
- Rocket trainer difficulty follows campaign progress rather than scaling directly to the player's current Pokémon levels.
- Operative memory now records actual trainer-battle wins/losses separately from overall incident outcomes.
- Milo only offers the cooperative cache split when the player's most recent battle against Milo was a win; if Milo later wins, that offer closes again until he is beaten.

## 0.2.0 — 2026-09-23

### Added

- Pokédex Chip encounter research for seen Pokémon, including locations, methods, effective encounter shares, and effective level ranges.
- Rocket Decoder incident framework with staged transmissions, persistent operative memory, multiple dialogue paths, win/alternate/loss/expiry outcomes, and randomized DScrete prototype cargo.
- Three authored Rocket incidents: Intercepted Shipment, Hidden Cache, and Illegal Experiment.
- Versioned GitHub release packaging compatible with Gen1Recomp's mod updater.

### Changed

- Rocket incident progression gates now use real Gen1Recomp progression evidence instead of treating `save.visited` as route/dungeon history.
- Pokédex Chip fishing previews now match runtime replacement semantics.

## 0.1.0

- Initial development version of the DScrete item framework and encounter/detection foundation.