# Attest-handshake rescue recipe

> **Status:** active.
> **Author:** orchestrator, 2026-10-18 (codified at
> `decisions/attest-handshake-rescue-2026-11@1`).
> **Companion decision:** `decisions/attest-handshake-rescue-2026-11.yaml`.
> **Enabling principle:** `decisions/process-principles.yaml@5::P9`.

When a sub-agent dies mid-task from a Token Plan rate-limit
interrupt (HTTP 429 retry exhaustion), the parent orchestrator
runs this recipe. The recipe is deterministic and auditable;
every step is recorded as either a `paseo_*` tool call or a
git operation that shows up in `git log`.

## When to run

- The child sub-agent's run has failed with an HTTP 429
  retry-exhaustion error (not a logic failure, not a
  parser rejection).
- The child sub-agent has produced at least one
  `scaffold(<id>): ...` commit per P9 (the typical case;
  absent scaffold commit, the rescue cannot recover any
  kernel edits).
- The child sub-agent may have produced partial commits
  beyond the scaffold commit; the recipe inspects the
  worktree's `git log` for any work after the scaffold.

## The 5-step recipe

1. **Archive the dead agent.**

   ```bash
   paseo_archive_agent --agentId <dead-agent-id>
   ```

   The dead agent's terminal output is preserved by Paseo
   for post-mortem; archiving removes it from the active
   list. The agent's worktree (under
   `~/.paseo/worktrees/<uuid>/<slug>/`) is preserved.

2. **Inspect the worktree's git status.**

   ```bash
   git -C <worktree-path> status
   git -C <worktree-path> log --oneline release/v3.3.2-2026-10..HEAD
   ```

   The diff between the integration branch and the topic
   branch HEAD shows what the dead agent committed. If
   only the scaffold commit is present, the agent died
   before any kernel edit (jump to step 4). If kernel
   edits are present, proceed to step 3.

3. **Partial-commit rescue (if applicable).**

   a. Read the worktree's `bin/Mathc.ml`, scripts, and
      decision YAML for the partial work. The dead agent's
      intent is recoverable from the file contents even if
      the run did not finish.
   b. Commit that work as a single atomic change on the
      topic branch:

      ```bash
      git -C <worktree-path> add <partial-files>
      git -C <worktree-path> commit -m "rescue(<sub-decision-id>): partial kernel edit from rate-limit-killed sub-agent"
      ```

      The commit message MUST start with `rescue(<id>):`
      so the rescue is auditable from `git log`.
   c. Stamp the resulting attestations with
      `producer.identity: human:<parent-agent>` and a
      `rescue_reason: token-plan-rate-limit` field. The
      `human:` prefix distinguishes the rescued
      attestation from an auto-generated one.
   d. Recompute `body_sha` / `yaml_sha` if the agent's
      partial work modified the decision file. The
      standard algorithm in
      `scripts/counterexample-seed.py::recompute_sha` and
      `scripts/axiom-link-seed.py::recompute_sha` is the
      reference implementation.

4. **Mark the sub-decision as `state: archived` (when no
   kernel edit was attempted).**

   If the dead agent produced only the scaffold commit
   and no kernel edits, the work is not partial-commit
   worthy. The orchestrator updates the scaffold commit's
   decision file to `state: archived` with a
   `reversal_note: rate-limit-killed-before-kernel-edit`
   field, then re-spawns the sub-agent from scratch on
   the next-budget model. The next-budget model is named
   in `bin/data/time-distribution.yaml`; if no model is
   named there, the orchestrator asks the human
   maintainer.

5. **Append a one-line entry to the incidents log.**

   Append one row to the "Incidents" table at the bottom
   of this file. The row contains: date (YYYY-MM-DD),
   sub-decision ID, rescue outcome (partial-commit / no-
   partial), parent agent ID, and (if re-spawned) the new
   sub-agent ID.

## Why this is deterministic

Per `decisions/process-principles.yaml@5::P9`, the
scaffold-commit pattern guarantees that no sub-agent
dies without SOMETHING on disk. The scaffold commit is
the recovery seed: the orchestrator can always run
`git log` against the topic branch and see what the dead
agent intended to change, even if the agent's terminal
output is gone.

Per `decisions/process-principles.yaml@4::P8.5`, the
sub-agent's declared dependencies are checked at launch
time; if the integration branch has not landed the
sub-agent's dependencies, the launch aborts with a
structural dependency error. This prevents the
rate-limit-induced rescue from happening in the first
place for sub-agents with stale dependencies.

## Acceptance

- `nix develop .#test --command 'dune test'` exits 0
  after this file lands.
- `mathc self-check` reports no NEW unknown subjects
  after this file lands.
- Every rescue invocation appends one row to the
  incidents log below.

## Incidents

| date       | sub-decision-id          | rescue outcome | parent agent id | new sub-agent id |
|------------|--------------------------|----------------|------------------|------------------|
| _none yet_ | _none yet_               | _none yet_     | _none yet_       | _none yet_       |