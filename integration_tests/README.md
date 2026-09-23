# Engine integration tests

These checks require an external Gen1Recomp checkout pinned to **v0.2.74** / commit
`9545ebbb839a8a7ea28472b626681154ab222623`. Set `GEN1RECOMP_ROOT` and run:

```sh
make test-integration
```

The target first verifies the exact upstream revision, then runs Gen1Recomp's own
`modkit.py validate` against this repository with the imported Gen 1 base. That is
the authoritative load/schema/cross-reference check; the standalone Lua tests do
not pretend to validate engine hooks.

## Existing field-effect smoke matrix

- developer boot: Pallet Town debug NPC exists; release boot: it does not;
- GET ITEMS uses the real bag path and obeys slot/stack limits;
- Prism Scent activates from the bag and consumes exactly one copy on success;
- use in battle refuses and consumes nothing;
- a second active field effect follows the replacement flow and never double-consumes;
- legal player steps decrement timed effects; wall bumps, menus, warps and scripted
  movement do not;
- expiration is announced once after movement finishes;
- ordinary grass/water/fishing encounters reflect the configured active effect;
- gifts, trades, static encounters and trainer parties remain unchanged unless a
  feature explicitly targets them;
- save/reboot persistence restores only documented persistent state; and
- debug INSPECT and RESET expose/clear the expected DScrete state.

## Pokedex Chip smoke matrix

- unlock Pokedex Chip and confirm its GADGETS row explains native Pokédex access;
- a species that is not SEEN cannot expose encounter data;
- highlight a seen species directly in the normal Pokédex list and press SELECT;
  AREA DATA opens without first entering the DATA side-menu option;
- confirm SELECT also works from that species' normal DATA entry page and that
  B/SELECT returns correctly from AREA DATA;
- highlight an unseen dashed Pokédex row and confirm SELECT does nothing;
- verify land, surf and Old/Good/Super Rod rows on representative maps, including
  long map names and scrolling beyond three rows;
- verify displayed level ranges match native slots and update while Prototype
  Resonator is active;
- verify percentages change appropriately under Elusive Scent, Mystery Lure, Species
  Whistle and Safari Kit, including local/non-local Whistle fishing; and
- confirm a species with no current merged habitat shows `NO CURRENT HABITAT` rather
  than stale or invented locations.

## Rocket Decoder smoke matrix

- with the Decoder locked, normal steps never spawn incidents or runtime Rocket actors;
- unlock it, then verify natural scheduling uses reachable progression and maintains at
  most one active incident globally;
- force and play **Intercepted Shipment**, **Hidden Cache**, and **Illegal Experiment**
  once each to validate runtime actor placement and cleanup on their authored maps;
- open ACTIVE SIGNAL before entering the region, within the broad region, and on the
  incident map to verify staged transmission decoding;
- confirm conversation reply menus are compact bordered overlays that leave the
  overworld visible rather than opaque full-screen lists;
- exercise multiple conversation paths, including Ronnie's bluff/radio branches,
  Milo's talk/fight paths, and Cass's ask/machine/sabotage paths;
- on a first Milo encounter, confirm no cooperative split is offered; beat Milo in an
  actual trainer battle, meet him again, and confirm the split becomes available;
- after Milo later beats the player, confirm the split is unavailable again until the
  player wins another trainer battle against him;
- verify Ronnie, Milo and Cass use distinct named trainer parties rather than the same
  vanilla Rocket party;
- exercise early/mid/late badge states and confirm their teams move through the four
  authored progression tiers without matching the player's exact Pokémon levels;
- verify battle victory, alternate resolution, battle loss and timer expiry produce
  distinct terminal outcomes and remove the live incident;
- save/reload with an active incident and confirm location, stage, remaining steps,
  phase and rolled prototype cargo remain stable rather than rerolling;
- after later Ronnie/Milo/Cass encounters, confirm actual battle records and incident
  outcomes independently change dialogue and OPERATIVE DATA counters appropriately;
- confirm TRANSMISSIONS retains completed incident summaries while expired incidents
  remain distinguishable from direct Rocket victories; and
- verify a full DScrete persistent-state reset clears active incident state, archives,
  operative memory and temporary actors.

## Prototype Ball smoke matrix

- grant a Prototype Ball through the developer NPC and confirm it occupies a normal bag
  slot, cannot be tossed outside battle, and decrements exactly once when thrown;
- throw against a target above 50% HP and verify the effective species catch-rate input
  is halved before the stock Gen-1 HP/status calculation, making it deliberately worse
  than a normal Poké Ball;
- test the HP boundaries directly: 50% uses 1×, 25% uses 2×, and 10% or less uses 3×;
- compare a badly weakened low-catch-rate target against Ultra Ball behavior and verify
  the <=10% Prototype Ball band provides the intended substantial advantage;
- apply a major status at low HP and confirm the engine's ordinary status catch bonus
  still stacks after the Prototype Ball's HP-based rate adjustment;
- test a high-catch-rate species at <=10% HP and confirm the adjusted species rate caps
  at 255;
- throw one at a trainer-owned Pokémon and confirm the normal trainer-ball refusal,
  animation, item consumption, and turn cost remain stock behavior;
- capture with a full party and confirm normal party/PC storage, Pokédex registration,
  nickname prompt, and post-capture cleanup are unchanged.

## EXP Battery smoke matrix

- use an EXP Battery in the field and confirm one copy is consumed and INSPECT reports
  `EXP BAT ARMED`; attempting to use a second while armed must fail without consumption;
- save and reload while armed and confirm the charge remains armed;
- defeat a wild Pokémon with one participant and confirm the displayed battle EXP is
  exactly doubled, then verify the charge is no longer armed;
- switch between two or more participating party members before the knockout and verify
  every normal share from that defeated Pokémon receives the same 2× multiplier rather
  than only the first recipient;
- where EXP.ALL is available, verify its additional payout shares belong to the same
  one-charge distribution;
- complete ordinary battle turns without defeating anything and confirm the Battery is
  not consumed;
- verify trainer battle EXP also doubles and that subsequent enemy Pokémon in the same
  trainer battle receive ordinary EXP after the first charged payout;
- verify a charged payout can cross a level-up and move-learning prompt without losing
  or double-applying the multiplier;
- use Rare Candy or another non-battle growth path while armed and confirm it neither
  receives nor consumes the Battery bonus;
- verify full DScrete persistent-state reset clears an armed Battery.

## Trainer Beacon smoke matrix

- defeat ordinary trainers from several classes, face each trainer afterward, use a
  Trainer Beacon, and confirm one copy is consumed only after a valid signal is accepted;
- use the Beacon on an undefeated trainer, while not facing a trainer, and on excluded
  story classes such as a Gym Leader; each must fail without consuming the item;
- test 0-1 / 2-3 / 4-5 / 6+ badge states and verify the rematch party starts from that
  trainer's current merged original party with +5 / +10 / +15 / +20 levels respectively;
- choose trainers whose Pokémon cross one and multiple ordinary level-evolution
  thresholds after the boost and verify those species evolve while stone/trade
  evolutions do not occur merely because of level;
- verify normal battle EXP is retained while prize money is approximately half the
  equivalent rebuilt party's ordinary trainer payout;
- confirm the first rematch draws only from that trainer class's first-rematch pool and
  later fights draw only from its later-rematch pool;
- sample Bug Catcher, Swimmer, Scientist, Channeler and at least three other classes to
  verify class voice, humor/darker variants, text wrapping and generated
  strongest-Pokémon references all render correctly;
- verify an unknown/modded trainer class receives generic fallback dialogue rather than
  an error, and a compatible trainer-party mod composes before the Beacon level boost;
- after a rematch, confirm that trainer refuses another Beacon until the configured
  step cooldown expires, that other defeated trainers remain independently available,
  and that the countdown/rematch count survives save/reload;
- exercise player win, loss and blackout paths and confirm no Beacon state leaks into
  unrelated later trainer battles.

## Link Cable smoke matrix

- grant a Link Cable and verify its selector lists only party Pokémon whose current
  merged evolution data accepts the standard trade trigger;
- with Kadabra, Machoke, Graveler and Haunter in representative parties, confirm the
  selector identifies each without any species-specific compatibility path;
- cancel from the target list and from the USE CABLE confirmation and verify the item
  remains in the bag and no evolution begins;
- confirm USE CABLE consumes exactly one item, displays the short link connection text,
  and opens the native evolution presentation;
- press B during the committed evolution and verify it cannot be cancelled, matching a
  genuine trade evolution;
- verify the evolved species receives normal Pokédex seen/owned updates and any move it
  should learn from the native evolution flow;
- install a compatible modded/Fakemon species whose merged evolution method accepts
  `{ kind = "trade" }`; confirm it appears automatically and evolves without a DScrete
  species whitelist;
- test a custom non-trade evolution method and verify it stays absent from the selector;
- save/reload before use and after a completed evolution to verify no transient Link
  Cable selection/pending state persists incorrectly.

As more items land, engine-facing regression drivers should be added beside this
matrix rather than duplicating Gen1Recomp internals in standalone Python models.
