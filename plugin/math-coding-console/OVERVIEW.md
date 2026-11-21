# Math Coding v5 attention desk

Math Coding v5 attention desk turns a project's Math Coding specification into a focused queue for people working with coding agents. Its first screen says what only the owner can decide, what an agent can safely do now, and which risks the owner has already accepted.

The plugin is a view over Math Coding v5. It does not calculate a second verdict. Verdict and claim states always come from the project's `mathc` command, while claim definitions and evidence provide the context needed to understand them.

## What it shows

The workspace panel has three top-level views:

- **Attention** separates human-only decisions, grouped work an agent can perform, and risks already accepted by a human.
- **Explore** contains the searchable claim list, the proof graph, and declared scope and coverage.
- **Evidence** shows observation outcomes and their provenance. Observation outcomes remain separate from current claim states.

A changed source, refutation, unmet human review, missing acceptance criterion, or an expired waiver that is still part of an unresolved claim requires a human decision. Outdated or unchecked claims, inconclusive observations, and uncovered paths are work an agent can investigate without changing the intended contract. A canonical `waived` state is shown as an already accepted risk, never as permission to hide a refutation. Identical work is grouped into one item.

Selecting a claim opens its falsifier, negative control, requirement tree, waiver information, linked observations, and an explicit decision boundary between machine checks and human authority.

The frame names the program that produced the map, and every evidence record names the program that produced it. A record carried over from the previous format names an unknown producer instead of an invented one. When the program reports that the observer changed, the claim card says so: the evidence still applies, but the build that produced it is not the build that reads it.

## Agent briefs

A card can copy a structured brief to the local clipboard for an agent. The brief carries the project goal, the canonical verdict, the coverage gap, the accepted risks and the canonical next action, and it separates the human decision from the agent's permitted investigation. It explicitly forbids weakening verifiers, impersonating a reviewer, or recording human decisions. It is not sent to a model provider and does not create an agent.

## The same console without Paseo

The console is written once and hosted twice. The plugin and the local browser page share the interface, the data contracts and the project operations; only the host surface differs. The local page runs a loopback-only server for one fixed project directory, keeps its settings outside the project, and applies the same read-only boundary and the same confirmation before running checks.

## Setup and permissions

The plugin needs Math Coding v5 installed as `mathc` on the daemon machine. An absolute path to a different binary can be configured in the plugin settings. The selected binary must report `mathc 5`.

The daemon reads the workspace's `spec.json` and `.math/v6/evidence.jsonl` in the format `schema_version: 6`, and executes `mathc` in the workspace. A file of another format is refused with an explicit error instead of being read as a green one. It does not send project data to an external service.

A closed action says so. The panel names the switch that opens it and offers the way to the settings of the host, so a grey button is never a button without a reason.

Opening, refreshing, filtering, copying a brief, and navigating are read-only. **Run checks** is disabled by default and is the only action with side effects. After it is enabled in the plugin settings, the action still requires explicit confirmation, executes the verifier and negative-control commands declared by the project, and appends local evidence.

## Limits

Math Coding v5 does not yet contain claim-to-claim or ADR-to-ADR dependency data, so the plugin does not draw those relationships. File coverage is not presented as a percentage because the canonical map does not expose a total file count. A green verdict always remains visible separately from uncovered paths and human acceptance.
