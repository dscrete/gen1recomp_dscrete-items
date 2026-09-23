# DScrete Items

**DScrete Items** is a Gen1Recomp expansion built around strange, useful pieces of
late-1990s Pokémon technology. Rather than backporting later-generation features, it
adds gadgets and consumables that create new decisions and activities while fitting
the existing game's presentation.

The guiding loop is:

> find a gadget -> gain a capability -> discover a new way to play

How players obtain most gadgets is intentionally separate from the behavior framework.
Oak research, Silph prototypes, Safari ecology, Rocket incidents, shops or later
reward systems can distribute the same item definitions without rewriting their logic.

## Engine compatibility

DScrete Items is a standalone **Mod API 2** mod for Gen1Recomp. The supported engine
range is `>=0.2.5 <0.3.0`; the minimum-version verifier targets the `v0.2.5` tag.
Full in-game smoke testing at the compatibility floor remains tracked separately from
standalone implementation status.

Current numbered release: **v0.2.2**.

## Versioning and updates

`manifest.json` is the source of truth for the mod version and GitHub update source.
Versions use numeric semantic versioning (`X.Y.Z`). While DScrete Items remains pre-1.0,
feature releases normally bump the minor version and focused fixes bump the patch
version.

Gen1Recomp's mod updater reads the manifest's
`github: "dscrete/gen1recomp_dscrete-items"` field, checks that repository's GitHub
releases, compares semantic versions, and downloads the release ZIP. Numbered releases
therefore use:

- tag: `vX.Y.Z`;
- release: non-prerelease GitHub release for that tag; and
- asset: `gen1recomp_dscrete_items-X.Y.Z.zip`.

The asset name intentionally matches Gen1Recomp's preferred `<mod-id>-<version>.zip`
pattern. Ordinary commits still run tests and build the package, but they do not create
another release unless the manifest version has changed. This avoids treating every
commit as an update while keeping completed versions directly updatable from the repo.

See [CHANGELOG.md](CHANGELOG.md) for player-facing release history.

## Design principles

1. **Gen 1 first.** Reuse the existing bag, text boxes, palettes, sounds and map
   vocabulary wherever possible.
2. **Capabilities, not conveniences.** A feature should create a new decision or
   activity rather than merely shorten a menu operation.
3. **One shared framework.** Timed encounter effects, gadgets, persistence and debug
   tooling share the same state model.
4. **Respect the encounter table.** Most encounter tools bias an area's identity
   instead of silently replacing it.
5. **Compatibility first.** Compose through public hook chains and merged data where
   possible; companion mods are optional integrations, never requirements.
6. **Content should scale.** Rocket incidents and similar authored systems separate
   reusable framework code from scenario/dialogue data.

## Storage and ownership

- **Permanent:** unlocked once, never consumed, and shown through **GADGETS**.
- **Reusable:** persistent gadget usable repeatedly.
- **Consumable:** normal bag item; one copy is removed only after successful use.
- **Consumable pair:** linked consumable states such as placing and using a beacon.

Only one normal encounter-modifying field effect may be active at a time. Replacing a
different active effect requires explicit confirmation.

## Playable encounter tools

### Prism Scent

A timed consumable that gives eligible natural wild encounters a configurable chance
to receive valid Gen-1 shiny DVs. It excludes trainer parties, gifts, trades and static
encounters. Optional Wilds of Kanto integration carries successful shiny DVs through
visible overworld spawns into battle.

### Elusive Scent

Compresses the native rarity curve without adding species, changing encounter
frequency or changing levels. MILD / STRONG / EXTREME presets increasingly favor the
rarer species already present in the area's table.

### Mystery Lure

Temporarily reserves a small share of successful encounters for one random
nonlegendary species from a curated habitat pool. It can be restricted to Pokédex-seen
candidates and works with normal land/water encounters and fishing outside Safari.

### PKMN Whistle

Lets the player choose a Pokédex-seen nonlegendary species. Native targets receive a
weight boost; optional non-local mode gives the target a small explicit replacement
chance. The selected target persists until changed.

### Prototype Resonator

Raises local encounter levels toward the first conscious party Pokémon while
preserving native species probabilities and the area's relative level spread. Its
configured cap is native maximum +10 / +20 / +35.

### Safari Kit

Offers one entry-time choice per Safari session. The current BAIT mode compresses
Safari rarity for the whole session; PASS adds configured Safari steps and Balls;
SAVE KIT keeps the item and locks out the choice for that run.

### Glitch Detector

Creates one to five intermittent anomaly spots on real nearby grass. Reaching any one
starts the same guaranteed nonnative one-shot encounter and clears every remaining
spot. It never mutates map collision or permanent map data.

## Detection gadgets

### Silph Tracker

Scans the current map and reports every local species using coarse signal bands:

`NO SIGNAL / FAINT / WEAK / STRONG / VERY STRONG`

Unseen species display as **UNKNOWN** while retaining their signal strength. Tracker
readings reflect DScrete's active encounter modifiers.

### Treasure Detector

Passively emits increasingly urgent electronic pulses near an uncollected hidden item.
It uses distance only: no direction arrow and no item-name reveal. A GADGETS screen
shows the current signal and toggles passive mode.

### Pokedex Chip

Adds live encounter research to **seen** Pokémon. Highlight a seen Pokémon directly in
the normal Pokédex list and press **SELECT** to open a dedicated AREA DATA screen.
SELECT also works from that Pokémon's normal DATA entry page. The screen shows every
currently represented encounter location, encounter method, effective species
percentage and effective level range. The readout reflects DScrete's active encounter
weighting and Prototype Resonator level shifts.

Fishing percentages are the species share conditional on a successful catch selection;
they do not include the separate chance that a rod produces no bite.

### Rocket Decoder

Unlocking the Decoder enables a semi-random authored Rocket incident system. At most
one incident exists globally at once. Signals begin vague, decode more detail as the
player reaches the relevant region, and can reveal further fragments through the
incident itself.

The Decoder keeps:

- **ACTIVE SIGNAL** — the currently decoded transmission and remaining window;
- **TRANSMISSIONS** — recent incident history; and
- **OPERATIVE DATA** — lightweight persistent records for recurring named Rockets.

The initial recurring operatives are **Ronnie**, **Milo**, and **Cass**. They remember
selected outcomes such as beating the player, being beaten, alternate resolutions and
a few authored events, allowing later dialogue to react without becoming a full
relationship simulator.

The first three incident templates are:

- **Intercepted Shipment** — track Ronnie and a randomly selected implemented DScrete
  prototype shipment through multiple conversation paths.
- **Hidden Cache** — decode an environmental clue, find or negotiate over a Rocket dead
  drop, and potentially avoid combat.
- **Illegal Experiment** — investigate Cass and a scientist's badly tuned attractor,
  with battle, observation and sabotage paths.

Incidents can end as a normal player resolution, an alternate/non-battle resolution,
a Rocket success after a direct loss, or expiry if the player never resolves the
event. Those outcomes persist separately so later dialogue can remember what actually
happened.

## Item catalogue

| Item | Type | Category | Intended effect |
| --- | --- | --- | --- |
| Prism Scent | Consumable | Encounters | Configurable shiny odds through valid Gen-1 shiny DVs. |
| Elusive Scent | Consumable | Encounters | Compresses the rarity curve of species already present. |
| Mystery Lure | Consumable | Encounters | Reserves a temporary share for one habitat mystery species. |
| PKMN Whistle | Consumable | Encounters | Calls one selected remembered species. |
| Prototype Resonator | Consumable | Encounters | Raises local encounter levels toward the conscious lead. |
| Safari Kit | Consumable | Encounters | Applies one selected Safari-session enhancement. |
| Glitch Detector | Consumable | Encounters | Creates visible, safe one-shot encounter anomalies. |
| Silph Tracker | Permanent | Detection | Reports coarse current-map species signals. |
| Treasure Detector | Permanent | Detection | Gives stronger audio feedback near hidden items. |
| Pokedex Chip | Permanent | Detection | Adds live encounter statistics to seen Pokédex entries. |
| Rocket Decoder | Permanent | Detection | Enables and decodes authored temporary Rocket incidents. |
| Prototype Ball | Consumable | Battle | Applies a documented modifier to normal capture calculation. |
| EXP Battery | Consumable | Battle | Arms a bonus for a future eligible EXP award. |
| Trainer Beacon | Consumable | Battle | Allows an eligible defeated trainer to be challenged again. |
| Link Cable | Consumable | Pokémon | Evolves the four Gen-1 trade-evolution species. |
| Move Recorder | Consumable | Pokémon | Offers an eligible missed level-up move. |
| Fossil Catalyst | Consumable | Pokémon | Applies a disclosed modifier during fossil revival. |
| DNA Stabilizer | Consumable | Pokémon | Improves DVs within bounded shiny-safe rules. |
| Mutation Capsule | Consumable | Pokémon | Rerolls one random DV with preview. |
| Blank TM | Consumable | Pokémon | Records and teaches one compatible move. |
| PC Transfer Unit | Consumable | Travel | Opens portable PC access once and safely returns. |
| Emergency Teleporter | Consumable | Travel | Returns to the last valid Pokémon Center. |
| Map Beacon | Consumable pair | Travel | Records a valid field tile and later returns to it. |

## Development access

Current acquisition remains deliberately development-oriented while behavior is being
stabilized. The developer Pallet Town NPC provides **GET ITEMS**, **WARP**,
**INSPECT**, and **RESET**. **ALL IMPLEMENTED** grants implemented consumables through
the real inventory path, while **UNLOCK GADGETS** unlocks all implemented permanent
tools.

Rocket Decoder also exposes a developer-only force-incident entry so each authored
scenario can be tested deterministically rather than waiting for the normal scheduler.

## Testing and release build

`make test` runs the standalone Lua/static suite. `make test-integration` validates
against the pinned Gen1Recomp integration checkout when its imported Gen-1 cache is
available.

`make package` builds the updater-compatible ZIP for the version currently declared in
`manifest.json`. Every push and pull request runs the tests and builds that ZIP. A
push to `main` publishes a new numbered GitHub release only when the manifest version
has not already been released; later commits at the same version do not publish again.

## Delivery

The ordered source of truth is [docs/CHECKLIST.md](docs/CHECKLIST.md). Detailed
behavioral contracts and integration notes live in
[docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).

With the current detection tools implemented, the next ordered items are
**Prototype Ball**, **EXP Battery**, and **Trainer Beacon**.
