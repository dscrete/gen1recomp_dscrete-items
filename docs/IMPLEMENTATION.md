# DScrete Items implementation status and contracts

Target compatibility: Gen1Recomp **>=0.2.5 <0.3.0**, Mod API 2, Gen 1.
The minimum-version verifier targets tag `v0.2.5`; the repeatable integration harness
currently pins v0.2.74. The ordered delivery backlog lives in
[CHECKLIST.md](CHECKLIST.md).

## Shared runtime and delivery

- `main.lua` is a Mod API 2 content entrypoint with a canonical Lua catalogue.
- Real consumables use the engine bag and commit consumption only after successful
  activation.
- Permanent/reusable gadgets use versioned `mod.save` state rather than bag slots.
- Encounter-modifying timed effects share one active slot, replacement confirmation,
  eligible-step countdown and exact save/load persistence.
- The developer-only Pallet Town harness supplies GET ITEMS, WARP, INSPECT and RESET.
- `manifest.json` is the player-facing semantic-version and GitHub-update source of
  truth. Standalone tests and updater-compatible packaging run on every push/PR; a new
  manifest version on `main` publishes one matching stable `vX.Y.Z` release with
  `gen1recomp_dscrete_items-X.Y.Z.zip` attached.

## Encounter foundation

### Prism Scent

Prism Scent is a timed consumable that gives eligible natural wild encounters a
configurable shiny-DV roll. It generates only DV shapes accepted by Gen1Recomp's
`Stats.isShiny`, excludes trainer/gift/trade/static sources, persists its exact
remaining eligible steps, and optionally propagates the same DVs through Wilds of
Kanto visible spawns.

### Elusive Scent

Elusive Scent compresses the local rarity curve without adding species, changing
encounter frequency, or changing levels. Species are combined before rarity weighting;
the commonest species remains the 1x baseline and progressively rarer species approach
the configured MILD/STRONG/EXTREME strength.

### Mystery Lure

Mystery Lure reserves a configured successful-encounter share for one randomized
nonlegendary habitat candidate. Selection is retained per habitat while active and can
be restricted to Pokédex-seen candidates. It applies to normal land/water encounters
and fishing, but refuses Safari activation.

### Species Whistle

Species Whistle opens an in-bag seen-species selector. A local target receives a
configured weight boost; optional non-local mode reserves a small explicit replacement
share. The selected species is remembered, cancellation consumes nothing, and the
active call applies to normal encounters, fishing and optional Wilds visible spawns.

### Prototype Resonator

Prototype Resonator preserves native species probabilities and relative level spread,
then shifts the area's encounter levels toward the first conscious party Pokémon. The
maximum shift is capped by the selected +10/+20/+35 preset and never lowers a native
level. Safari activation is refused.

### Safari Kit

Safari Kit is consumed only when an entry-time Safari choice commits. BAIT currently
compresses Safari rarity for the entire session; PASS adds configured steps and Safari
Balls; SAVE KIT/cancel locks out use for that session without consumption. Session
state persists until the underlying Safari session ends.

### Glitch Detector

Glitch Detector creates one to five visible anomaly entrances on real nearby grass
cells. Any entrance starts the same one-shot guaranteed nonnative encounter and ends
the effect. It never changes blocks/collision/warps and exposes a save-safe activation
seam for later authored content.

## Detection tools

### GADGETS and Silph Tracker

The Start menu gains GADGETS once an implemented permanent/reusable gadget is unlocked.
Silph Tracker reads the current effective/merged encounter view and reports coarse
species signal bands. Unseen species stay UNKNOWN. Its dedicated screen avoids generic
list clipping and reflects DScrete's live encounter modifiers.

### Treasure Detector

Treasure Detector reads only current-map uncollected hidden-item markers from
`mod.world:mapOverview()`. Passive audio pulses repeat while stationary and become
faster/higher as Manhattan distance closes. It does not reveal item identity or a
direction arrow; its passive toggle persists in reusable gadget state.

### Pokedex Chip

Pokedex Chip is a permanent gadget that extends the *experience* of a normal seen
Pokédex entry without replacing the native screen.

- Only Pokédex-seen species expose AREA DATA.
- Pressing SELECT on the native `DexEntryMenu` opens a dedicated scrolling screen.
- The screen aggregates all locations present in the merged encounter/fishing data and
  shows map, method, effective species share and effective level range.
- Land and surf rows use the effective encounter-table preview when available, then
  mirror DScrete's own live Elusive Scent, Mystery Lure, Species Whistle and Safari Kit
  weighting.
- Prototype Resonator changes the displayed effective level range.
- Fishing previews model Mystery Lure/Species Whistle as post-selection replacement
  probabilities, matching their runtime hook semantics.
- Rod percentages describe species share conditional on a successful catch selection;
  they do not include the rod's separate no-bite probability.

The compatibility floor has no public dex-entry decoration/action hook. The Chip uses
a narrow `input.step` seam to identify the exact native `src.ui.DexEntryMenu` state
and open a separate screen on SELECT. This is documented in `API_GAPS.md` and should
move to a public dex hook if one becomes available.

### Rocket Decoder

Rocket Decoder is both a permanent gadget and an extensible authored-incident
framework. Incidents do not exist before the Decoder is unlocked. Once unlocked, the
scheduler can create one active incident globally; the event then exists independently
until resolved or expired.

#### Scheduling and persistence

- A cooldown plus semi-random ready window controls incident frequency.
- Eligibility is progression-gated. Gen1Recomp's `save.visited` is a fly-town bitset,
  so incident definitions use nearby visited towns, optional required inventory items,
  and current-region presence instead of nonexistent route/dungeon visit flags.
- The active incident ID, chosen location, decode stage, phase, remaining steps, rolled
  cargo, archive and operative memory all persist under the Decoder reusable-state
  key.
- Prototype cargo is rolled once when an incident spawns and cannot be rerolled by
  save/load.
- Completion starts a generous cooldown before another incident may appear.

#### Data-driven incident contract

`lib/rocket_incidents.lua` owns content. A new incident primarily declares:

- ID/title and eligibility locations;
- broad-region maps and local anchor;
- optional progression requirements and minimum trainer tier;
- authored transmission stages;
- additive temporary actors/interactables;
- a curated implemented-consumable prototype pool; and
- interaction functions containing dialogue branches and outcomes.

Named operative records also own distinct trainer IDs and four authored party tiers.
`lib/rocket_decoder.lua` registers those trainer classes using the normal Rocket
portrait and selects the effective party tier from badge progress plus the incident's
minimum tier. It deliberately does **not** inspect the player's current Pokémon levels,
so underleveled players can lose and overleveled players can eventually outgrow early
encounters instead of meeting invisible rubber-banding.

`lib/rocket_decoder.lua` otherwise owns scheduling, serialization, runtime NPC
lifecycle, decoder screens, battle/item command adapters and operative memory. Future
incidents should add content to the catalogue rather than introduce another bespoke
scheduler.

#### Decoder stages and UI

The initial decode is deliberately broad. Entering the relevant region improves the
signal, entering the incident map reveals the local fragment, and incident-specific
interactions can expose further stages. The Decoder provides:

- **ACTIVE SIGNAL** — all currently decoded transmission pages and remaining window;
- **TRANSMISSIONS** — recent completed/failed/expired incident summaries; and
- **OPERATIVE DATA** — records for recurring named Rockets already encountered.

Developer mode also exposes a force-incident menu for deterministic live testing.
Decoder/archive management remains a full-screen list where that is appropriate.
Incident *conversation choices* use the compact bordered `mod.ui.Menu` surface so the
NPC and overworld remain visible while the player chooses a reply.

#### Operative memory, conditioned dialogue and outcomes

The initial recurring cast is Ronnie, Milo and Cass. Memory is intentionally small and
authored: encounter count, incident wins, Rocket wins, alternate resolutions, last
incident outcome, actual trainer-battle wins/losses, last trainer-battle result and
selected boolean flags. It is enough for later dialogue to remember being fooled,
beaten, victorious or sabotaged without introducing a numeric relationship simulation.

Conversation rows may also carry authored conditions, allowing a later option to be
shown only when the incident/operative state warrants it. Hidden Cache uses actual
battle history rather than overall incident completion for negotiation: Milo's split
becomes available only when the player's **most recent trainer battle against Milo was
a win**. If Milo later beats the player, that offer closes again until the player wins
a subsequent battle.

Terminal outcomes remain distinct:

- `RESOLVED_WIN`
- `RESOLVED_ALTERNATE`
- `ROCKET_SUCCESS`
- `EXPIRED`

A direct loss can therefore affect later dialogue while an incident that simply
expired does not falsely become a remembered battle victory.

#### Initial incidents

1. **Intercepted Shipment** — Ronnie transports a randomly selected implemented
   DScrete prototype. Multiple conversation paths include direct confrontation,
   questioning, a boss bluff, and exposing the intercepted radio traffic. Ronnie's
   dialogue leans nervous/incompetent without making every Rocket scene a joke.
2. **Hidden Cache** — Milo and a Rocket dead drop emphasize decoded environmental
   clues, finding the cache first, history-conditioned negotiation and optional combat.
   Milo's voice is dry and pragmatic rather than generic interrogation text.
3. **Illegal Experiment** — Cass and a scientist test a mis-tuned attractor. The player
   can investigate, fight or reason through the setup; retuning produces an authored
   wild encounter and an alternate resolution. Cass remains more controlled and
   threatening while the scientist supplies much of the absurdity.

The three templates deliberately exercise different framework capabilities so later
incidents can expand content without first expanding the core engine.

## Shared encounter-weight contract

`lib/encounter_weights.lua` remains the single source of truth for Gen-1 slot weights,
species distributions, rarity compression, targeted boosts, reserved replacement
shares and signal bands. New encounter tools should reuse it rather than inventing
another normalization implementation.

For a normal Gen-1 table, cumulative buckets become per-slot weights; duplicate
species slots are summed; species-level modifiers are calculated; multipliers are
reapplied to original slots; and cumulative buckets are rebuilt with the final
threshold fixed at 256.

## Compatibility contract

Compatibility is optional and composable rather than dependency-based.

- Registry-based encounter changes are observed through merged content.
- Live field effects pass through normal encounter hook chains.
- `mod.world:effectiveEncounters()` is preferred for read-side table previews when
  available.
- Wilds of Kanto is discovered only through its public exports and remains optional.
- Rocket incidents use public runtime-NPC/map-script/world surfaces and never require a
  companion mod.
- Pokedex Chip's native-entry identification is the one documented narrow internal UI
  seam required by the compatibility floor.

## Test strategy

Standalone deterministic tests cover catalogue metadata, persistence/migrations,
field-effect transactions, encounter weighting, all current encounter tools, detector
logic, Pokedex Chip level/fishing calculations and native-entry wiring, plus Rocket
Decoder serialization, progression gates, placement, conditioned dialogue, compact
conversation UI, authored party tiers, reward pools and memory paths.

Those tests are not a substitute for engine execution. The unchecked matrix in
`integration_tests/README.md` still covers controller navigation, rendering, native
Pokédex behavior, runtime actor placement, dialogue/battle flows, save/reload and
cleanup.

## Next implementation order

With the current detection items implemented, the ordered backlog moves to the battle
tools: **Prototype Ball -> EXP Battery -> Trainer Beacon**. The checklist remains the
source of truth when later dependencies require reordering.
