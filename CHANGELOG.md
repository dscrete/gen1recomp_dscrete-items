# Changelog

All notable player-facing changes to DScrete Items are recorded here.

Versions follow semantic versioning while the mod is pre-1.0: feature releases bump the minor version and focused fixes bump the patch version.

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
