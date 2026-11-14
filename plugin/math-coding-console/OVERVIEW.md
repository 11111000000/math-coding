# Math Coding v5 map

Math Coding v5 map turns a project's Math Coding specification into an explorable evidence map inside Paseo. It shows the canonical verdict, each claim state, uncovered paths, the next action, source and requirement links, and the history of observations behind a claim.

The plugin is a view over Math Coding v5. It does not calculate a second verdict. Verdict and claim states always come from the project's `mathc` command, while claim definitions and evidence provide the context needed to understand them.

## What it shows

The workspace panel has four linked views:

- **Map** draws the proof structure from goal and source to claims and requirements. A separate scope view shows declared scopes and uncovered paths without presenting them as dependencies.
- **Claims** provides search and filters for state, register, kind, phase, owner, and source.
- **Evidence** shows observation outcomes and their provenance. Observation outcomes remain separate from current claim states.
- **Coverage** lists the goal scope, declared claim scopes, and uncovered paths.

Selecting a claim opens its falsifier, negative control, requirement tree, waiver information, and linked observations.

## Setup and permissions

The plugin needs Math Coding v5 installed as `mathc` on the daemon machine. An absolute path to a different binary can be configured in the plugin settings. The selected binary must report `mathc 5`.

The daemon reads the workspace's `spec.json` and `.math/v5/evidence.jsonl`, and executes `mathc` in the workspace. It does not send project data to an external service.

Opening, refreshing, filtering, and navigating are read-only. **Run checks** is disabled by default and is the only action with side effects. After it is enabled in the plugin settings, the action still requires explicit confirmation, executes the verifier and negative-control commands declared by the project, and appends local evidence.

## Limits

Math Coding v5 does not yet contain claim-to-claim or ADR-to-ADR dependency data, so the plugin does not draw those relationships. File coverage is not presented as a percentage because the canonical map does not expose a total file count. A green verdict always remains visible separately from uncovered paths and human acceptance.
