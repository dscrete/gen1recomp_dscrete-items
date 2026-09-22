# Implementation plan

This document translates the design into integration boundaries for Gen1Recomp.
Exact symbol names should be bound to the target revision during integration; the
contracts below deliberately avoid inventing upstream API names.

## 1. Shared runtime model

The gadget framework owns four kinds of state:

```text
GadgetSaveData
  schema_version
  permanent_unlock_bits
  encounter_statistics
  trainer_rematch_state
  placed_beacon

GadgetRuntimeState (not serialized)
  active_field_effect
  remaining_steps
  selected_species
  pending_exp_multiplier
  temporary_context
```

Serializable records use fixed-width fields and explicit bounds. Runtime pointers,
menu cursors, cached encounter-table addresses, and temporary callbacks must never
enter the save. Loading clears runtime-only state unless an effect explicitly has a
serialized counterpart and a migration rule.

### Field-effect contract

Encounter gadgets implement a common definition:

```text
id
duration_steps
can_activate(context) -> reason
transform_encounter_table(context, scratch_table)
on_encounter_generated(context, encounter)
on_step(context)
on_expire(context)
```

The original encounter table is copied to scratch storage before transformation.
Weights are normalized after every modifier, zero-weight slots stay unreachable,
and the vanilla table is never modified in place. A map transition re-evaluates the
effect against the new map; it does not reset the step counter.

Only successful overworld steps decrement duration. Menu movement, wall bumps,
warps, forced movement, and battle turns do not. Expiration is announced once in a
safe overworld text context.

## 2. Encounter behavior

### Rare Lure

1. Group the current table's nonzero slots by species.
2. Sum duplicate-slot weights for each species.
3. Identify the lowest nonzero total weight (ties are all considered rare).
4. Multiply those species' slot weights by the configured factor.
5. Normalize with a largest-remainder allocation so the total remains exact.

The lure changes relative species weights, not encounter frequency, levels, or the
set of species. An area without a valid wild table consumes no item and explains
why it cannot be used.

### Mystery Lure

Mystery candidates are authored by habitat ID, with species, level range, weight,
and progression requirements. The modifier reserves a small configured share of
the table, then normalizes native entries into the remaining share. There is no
global fallback pool: a habitat with no curated candidates rejects activation.

### Species Whistle and Silph Tracker

Both use the same compatibility index. A species is compatible with an area when it
is native to that table or appears in the area's curated habitat pool and its gate
is satisfied. The whistle increases existing combined weight but never inserts an
incompatible species.

The tracker reports coarse bands rather than exact odds:

| Combined weight | Reading |
| --- | --- |
| 0 | NO SIGNAL |
| lowest populated band | FAINT SIGNAL |
| middle bands | SIGNAL FOUND |
| highest populated band | STRONG SIGNAL |

Thresholds are defined centrally and tested against duplicate species slots.

### Shiny Finder

At wild DV generation, roll the configured shiny chance (initial target: 1/100).
On success, choose uniformly from the set of DV combinations recognized as shiny
by Gen1Recomp. Preserve normal species, level, moves, and encounter flow. The finder
does not affect gifts, trades, static encounters, owned Pokemon, or trainer parties
unless a future definition opts those encounter classes in.

## 3. Item-use transaction

Every consumable follows a two-phase transaction:

1. Validate context and display any selection menus.
2. Preview irreversible consequences when relevant.
3. Apply the effect.
4. Consume exactly one item only after successful application.
5. Mark the save dirty and return through the normal item-use result path.

Cancellation, invalid targets, full-party edge cases, failed map validation, and
closed menus consume nothing. A save interruption cannot leave a consumed item with
an unapplied effect.

The Link Cable accepts only Kadabra, Machoke, Graveler, and Haunter. Its transaction
sets the same evolution result expected from a trade and invokes the existing trade
presentation if that presentation can safely return to the bag flow. If not, the
feature remains disabled until a dedicated transition wrapper exists; silently
falling back to a plain text evolution is not the intended release behavior.

## 4. Category boundaries

Every item definition has exactly one implementation category. Categories keep
hooks and shared behavior together without coupling item behavior to a future reward
or progression system:

- **Encounters** owns table transforms, wild generation, habitats, and durations.
- **Detection** owns reusable information tools and overworld feedback.
- **Battle** owns capture, experience, and trainer-rematch integration.
- **Pokemon** owns move, evolution, fossil, and DV operations.
- **Travel** owns map, PC, warp, and safe-return operations.

Cross-category dependencies use explicit interfaces. For example, Detection may
read the normalized encounter view from Encounters, but it must not reproduce the
normalization rules. Adding an item requires assigning a category before its item ID
or save fields are accepted.

## 5. Data definitions

Content belongs in declarative tables wherever behavior can remain generic:

- gadget metadata: item ID, type, category, duration, and text IDs;
- habitat membership and Mystery Lure candidates;
- tracker signal thresholds;
- rematch eligibility and party-scaling policy;
- Prototype Ball condition and modifier;
- Blank TM move compatibility;
- shiny-valid DV combinations; and
- safe/unsafe context flags for travel gadgets.

Build-time validation must reject duplicate IDs, unavailable text, missing or unknown
categories, weights outside their storage type, empty Mystery Lure habitats, invalid
species or move IDs, and permanent gadgets configured as consumables.

## 6. Delivery order

The checkbox status and complete ordering live in [CHECKLIST.md](CHECKLIST.md). This
section summarizes the integration milestones and their exit criteria.

### Phase 0 — integration audit

- Pin the supported Gen1Recomp revision.
- Locate item-use, step, wild-table, DV-generation, capture, EXP, evolution, save,
  trainer-defeat, hidden-item, PC, map-transition, and menu extension points.
- Record calling constraints and decide how mod save data is allocated.
- Add a minimal build and smoke-test target before gameplay work.

### Phase 1 — Shiny Finder vertical slice

- Versioned save block and migrations.
- Shared field-effect lifecycle.
- Transactional consumable item use.
- Shiny Finder activation, wild-DV hook, duration, and expiration.
- Deterministic DV tests and a seeded statistical simulation.

Exit criteria: a fresh or migrated save can use a Shiny Finder without premature
consumption, produce only valid shiny DVs on successful rolls, preserve its state
across save/load as designed, and expire safely.

### Phase 2 — encounter foundation

- Rare Lure and Silph Tracker.
- Mystery Lure and Species Whistle.
- Prototype Repel, Safari Bait / Pass, and Glitch Detector.

### Phase 3 — detection and battle tools

- Permanent GADGETS menu and unlock handling.
- Treasure Detector, Pokedex Chip, and Rocket Decoder.
- Prototype Ball, EXP Battery, and Trainer Beacon.

### Phase 4 — Pokemon tools

- Link Cable with trade presentation.
- Move Recorder, fossil equipment, and bounded DV items.
- Blank TM compatibility and recording flow.

### Phase 5 — travel tools

- Shared unsafe-context validation.
- Emergency Teleporter and PC Transfer Unit.
- Map Beacon placement and return.

## 7. Test strategy

### Deterministic tests

- Encounter normalization preserves the exact total and never revives zero slots.
- Rare selection handles duplicate species, ties, and one-species tables.
- Species compatibility agrees between Tracker and Whistle.
- Step duration decrements only for eligible movement and expires once.
- Item transactions consume once on success and never on cancellation or failure.
- Counters saturate without wrapping.
- Unlock and eligibility gates cannot be bypassed through stale menus.
- Save round trips preserve persistent state and clear runtime caches.
- Every prior schema version migrates to the current schema.
- Shiny-forced DVs pass the runtime's own shiny predicate.

### Statistical tests

Seeded simulations should compare observed encounter and shiny rates to expected
distributions with tolerances selected before execution. They complement rather
than replace deterministic weight and DV tests. A test must not fail merely because
a finite sample did not contain a shiny.

### In-game smoke matrix

Test item use from the overworld and bag, then around map transitions, blackout,
save/load, evolution, full inventory, Safari entry/exit, scripted movement, and each
explicitly unsafe context. Verify both Red/Blue-style and Yellow-specific encounter
data where the supported runtime exposes them.

## 8. Definition of done for each gadget

A gadget implementation is complete only when it has:

1. an item definition and implementation category;
2. use, cancel, invalid-context, active, and expiration text;
3. explicit persistence and stacking behavior;
4. data validation;
5. deterministic tests for its rules;
6. save/load and map-transition coverage;
7. a documented balance knob; and
8. no path that consumes it before its effect commits.
