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
range is `>=0.2.5 <1.0.0`, which includes current 0.3.x releases such as **v0.3.3**.
The minimum-version verifier still targets the `v0.2.5` tag; `1.0.0` is reserved as the
next explicit compatibility-review boundary rather than imposing an arbitrary minor
version ceiling.

Current numbered release: **v0.5.0**.

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

## Battle tools

### Prototype Ball

A consumable experimental Poké Ball whose power depends on how badly the wild target
has been weakened. It keeps ordinary Poké Ball throw/HP/wobble behavior, but changes
the effective species catch-rate input before the normal Gen-1 calculation:

- above 50% HP: **0.5×**;
- 26–50% HP: **1×**;
- 11–25% HP: **2×**;
- 10% HP or less: **3×**, capped at 255.

That makes careless throws deliberately worse than a normal Poké Ball, while a target
pushed into critical HP gives the Prototype Ball a substantial advantage over an Ultra
Ball. Normal status catch bonuses still stack afterward.

### EXP Battery

A field-use consumable that arms a persistent **2× battle EXP** charge. The charge
survives save/load and applies to every normal EXP share produced by the next defeated
Pokémon, including multiple participating recipients, then disarms when that payout
turn finishes. Turns with no positive EXP do not waste it, and non-battle growth such
as Rare Candy does not consume or receive the bonus. A second Battery cannot be used
while one is already armed.

### Trainer Beacon

A consumable rematch signal used while facing an already-defeated ordinary trainer.
Gym Leaders, Elite Four, rivals and other story-critical classes are excluded by
default. One successful use rebuilds the trainer's current merged original party with
a badge-tier **+5 / +10 / +15 / +20** level boost. Pokémon that have reached ordinary
level-evolution thresholds evolve naturally; stone, trade and other special evolutions
are not inferred from level alone.

Rematches award normal EXP and roughly half normal prize money. Each trainer has a
configurable step cooldown, defaulting to **500 steps**. Dialogue is keyed to the
actual trainer class: every supported ordinary Gen-1 class has 10 first-rematch and 10
later-rematch variants, while unknown/modded classes receive a generic fallback.
Generated lines can reference the rebuilt team, including its strongest Pokémon.

## Pokémon tools

### Link Cable

A consumable that simulates the evolution trigger of a completed trade without
hard-coding a species list. The selector only displays party Pokémon whose merged
evolution method accepts the standard trade trigger, so compatible Fakemon/modded
trade evolutions work automatically.

Target selection and the final **USE CABLE** confirmation can be cancelled without
consuming anything. After confirmation the Bag and parent Start menu close automatically,
the Cable is consumed, a short link connection message is shown, and Gen1Recomp's
native evolution presentation runs with genuine trade semantics. That means the
committed evolution cannot be cancelled with B.

### Move Recorder

A consumable that recovers one missed natural move. Its party selector only displays
Pokémon that currently have something eligible to recall. The move list is built from
the merged evolutionary ancestry: starting moves and level-up moves at or below the
Pokémon's current level are eligible even when they belonged to an earlier stage, so an
early evolution can still recover a skipped pre-evolution move. Already-known moves
and non-natural sources such as TM/HM/tutor/event moves are excluded.

After a move is selected, Gen1Recomp's native learn/forget flow takes over. Pokémon
with fewer than four moves learn it normally; Pokémon with four moves get the standard
replacement screen and HM-forget protection. Cancelling either selector or abandoning
the native learn flow keeps the Recorder. One Recorder is consumed only when the move
is actually learned.

### Fossil Catalyst

A consumable Cinnabar Lab upgrade offered while collecting a completed fossil revival.
If accepted, the revival is overclocked to a progression target of **Lv.35 / 40 / 45 /
50** across the same four broad badge tiers used by Trainer Beacon. A modded revival
that already starts above that target is never lowered.

The overclocked level recursively applies only ordinary level evolutions that have been
reached. The resulting Pokémon then goes through Gen1Recomp's normal gift construction,
storage, nickname and Pokédex path, so its natural starting/level-up moves are the
normal four-move set appropriate to the resulting species and reconstructed level.
Stone, trade and other special evolutions are not inferred. The integration keys off
the pending Cinnabar fossil state rather than a fossil-species whitelist, allowing
compatible modded fossil revivals to participate. Declining the offer or failing to
store the revived Pokémon consumes nothing; one Catalyst is spent only after a
successful handover.

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
| Prototype Ball | Consumable | Battle | Half-strength above 50% HP, scaling to 3× catch-rate input at <=10% HP. |
| EXP Battery | Consumable | Battle | Doubles the full next defeated-Pokémon battle EXP payout. |
| Trainer Beacon | Consumable | Battle | Rematches a faced defeated ordinary trainer with a progression-boosted evolved team. |
| Link Cable | Consumable | Pokémon | Triggers any compatible semantic trade evolution in the party. |
| Move Recorder | Consumable | Pokémon | Recalls one missed natural starting/level-up move from the current evolutionary ancestry. |
| Fossil Catalyst | Consumable | Pokémon | Overclocks Cinnabar revival to Lv.35/40/45/50 with reached level evolutions. |
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
tools. Prototype Ball, EXP Battery, Trainer Beacon, Link Cable, Move Recorder and
Fossil Catalyst also have direct GET ITEMS entries, and INSPECT shows whether an EXP
Battery charge is currently armed.

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
