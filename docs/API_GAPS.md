# Public API integration gaps

DScrete Items targets Gen1Recomp v0.2.74, Mod API 2. Engine-independent item data,
state rules, transactions, and the debug menu model can be tested in this standalone
repository. The following Phase 4 work must not be connected by guessing private
symbols:

- registering the debug-only NPC in Pallet Town;
- rendering its menu and text;
- granting items through the public inventory registry;
- mapping curated warp names to verified public map IDs and safe coordinates; and
- compiling debug registrations out of release packages.

The Shiny Finder additionally needs the public wild-DV-generation hook and the
runtime's public shiny predicate. Its engine-independent logic accepts that
predicate as an adapter and treats packed DVs as opaque; it does not duplicate or
guess the engine's shiny formula.

Each adapter will be implemented after its hook is confirmed in the tagged
`docs/modding.md` or public v0.2.74 headers. If no public hook exists, the feature
will remain unavailable and the missing capability will be recorded here rather
than implemented through an engine-internal dependency.
