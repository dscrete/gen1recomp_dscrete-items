# Changelog

All notable player-facing changes to DScrete Items are recorded here.

Versions follow semantic versioning while the mod is pre-1.0: feature releases bump the minor version and focused fixes bump the patch version.

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
