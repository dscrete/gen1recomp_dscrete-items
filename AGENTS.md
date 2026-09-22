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
