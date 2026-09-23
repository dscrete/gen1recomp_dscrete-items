## Git workflow

This repository is maintained through Codex Cloud.

- Do not suggest or require local checkout, local application of changes, or local dependencies.
- Perform implementation and testing in the cloud environment.
- When instructed to push changes, push them to GitHub rather than leaving them only in the cloud task.
- Unless explicitly told otherwise, push completed changes directly to the remote `main` branch.
- A task requiring a push is not complete until the commit is visible on GitHub.

## Project tracking

- `docs/CHECKLIST.md` is the ordered source of truth for implementation status and remaining work.
- Whenever implementation completes a checklist item, update the checklist in the same task/commit so completed work is marked accurately.
- Whenever requirements, naming, architecture, compatibility targets, or delivery plans change, revise the affected checklist text rather than leaving the old requirement in place.
- Add newly discovered required work to the appropriate checklist section when it materially affects delivery or compatibility.
- Do not mark engine/in-game validation complete unless it was actually exercised against the stated Gen1Recomp target.

## Versioning and delivery

- `manifest.json` is the single source of truth for the player-facing mod version and GitHub update repository.
- Use numeric semantic versions in `X.Y.Z` form. While the mod is pre-1.0, feature releases normally bump the minor version and focused fixes bump the patch version.
- Do not bump the version or publish a release for every intermediate commit. Bump it when a completed user-facing change should become an install/update target.
- Prefer one completed `main` push for a user-requested change rather than publishing intermediate work when practical.
- After the final `main` push, verify the **Standalone tests and versioned release** workflow succeeds.
- A new manifest version on `main` must publish exactly one matching `vX.Y.Z` GitHub release with `gen1recomp_dscrete_items-X.Y.Z.zip` attached. Ordinary later commits at the same manifest version must test/package without creating another release.
- A release task is not complete until the matching tag, non-prerelease GitHub release, updater-compatible ZIP asset, and final `main` commit are all visible on GitHub.
