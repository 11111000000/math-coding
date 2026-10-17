# Math-coding 3.3 agent protocol

> Project author: Petr Kosov <p.b.kosov@yandex.ru>

This repository implements math-coding 3.3. As of v3.0.0.19
(commit `8fa7fcf`) the bootstrap gate has expired: `mathc self-check`
is a blocking CI step per `constitution.md` Invariant 14. Verdicts
produced by `mathc gate`, `mathc self-check`, and `mathc assess`
reflect the kernel's reading of the live attestation store at
HEAD; they are not hand-written promises, but they are bounded by
the source class of each attestation in the store — `kind_` is one
of `test | review | build | analysis | observation`, and a
`review`-class attestation is a human declaration, not a runtime
observation. Treat the verdict as the sum of its attestations'
source classes, not as an undifferentiated guarantee.

The complete v2.1 source is preserved by the remote Git tag
`v2.1-final`. Do not use v2 packet fields, commands, or lifecycle rules
for new work.
> **OCaml toolchain — host shell forbidden.**
> All `dune`, `ocamlformat`, `ocamlmerlin`, `ocamlfind`,
> `ocamllsp`, `mathc` MUST run inside `nix develop .#test`
> (or via `scripts/dev`). The host shell has none of these tools
> at versions matching `flake.nix`. See §OCaml toolchain — hard
> requirement below and trap §11.34.


> Bootstrap history: between `v3-alpha-0.0.1` and `8fa7fcf` (Sep
> 26–29, 2026) every change had to satisfy the eight manual
> bootstrap checks below in lieu of a working kernel. Those
> checks are now *additive* to automated guarantees: the
> kernel still decides schema/reference/identity/freshness;
> agents still owe counterexamples, evidence plans, and
> recovery paths. See `ROADMAP.md` v3.0.0.20 for status.

## Quickstart (you are inside math-coding)

You're at the math-coding kernel repository. You're a new agent. Do this in order:

  1. `date` — confirm today; the file is dated 2026-10-14.
  2. `cat ROADMAP.md | head -100` — last status snapshot.
  3. `cat AGENTS.md | head -100` — this file's top + Read-first list.
  4. `cat PACKAGES.md | head -100` — what's in the repo.
  5. `cat OCAML_BEST_PRACTICES.md | head -60` — §1-§3 skim.
  6. `nix develop .#test --command bash -c 'scripts/dev doctor'` — verify your shell.
  7. `nix develop .#test --command bash -c 'scripts/dev ready'` — baseline green.
  8. `cat decisions/process-principles.yaml | head -200` — P1-P8.
  9. Pick a Tier-2 task from ROADMAP.md, create a worktree, follow §Definition of Done.

Total budget: 30 minutes wall-clock before any kernel change.

## Read first

Before changing anything in this repository, read in order:

1. `ROADMAP.md` — the single source of truth for priorities, audit
   status, and process principles. Read this first; it supersedes
   any inline priority lists in this file.
2. `PACKAGES.md` — the single source of truth for "what exists in
   this repository": every decision, fixture, kernel module,
   adapter, schema, spec, and axiom. Use this file to **find which
   decision file** to read or which fixture to modify; it supersedes
   the inline "where things live" lists elsewhere.
3. `README.md` — short pitch and pointers.
4. `spec/constitution.md` — invariants of the kernel.
5. `spec/algebra-3.2.md` — formal mathematical specification of the 3.2-ideal kernel (normative alongside prose specs).
6. `spec/domain.md` — entity model (prose; superseded by `algebra-3.2.md` §7).
7. `spec/semantics.md` — gate logic, exit codes, CLI subcommand catalog (prose; superseded by `algebra-3.2.md` §15).
7. `OCAML_BEST_PRACTICES.md` — project-specific OCaml conventions,
   including which conventions are *enforced* by `decisions/decision.yaml`.
   The trap log in §11 is the first place to look when debugging an
   OCaml or dune error.
8. `decisions/*.yaml` — the active decisions; their obligations
   describe the manual checks you must perform and the verifiers
   you must satisfy.
9. `axioms/` — the philosophical and mathematical foundations. Every
   non-trivial change MUST be derivable from at least one axiom.
10. `assets/*.svg` — site illustrations. 33 files, all have viewBox + <title>/<desc>; referenced from `site/*.md`. After editing any SVG, render it via `scripts/render-svgs.sh <name>.svg` (output in `assets/_renders/`) and visually verify no text overflows the right edge. The preventive verifier `scripts/check-svg-overflow.sh` runs in CI; the 2026-10-15 GitHub Pages report (this branch) motivated both.

If any of these contradict each other, the contradiction is a deficit.
Report it; do not silently resolve it.

## Worktree-first (hard requirement)

Every change ships from a dedicated git worktree. The main checkout
(`/home/az/Projects/math-coding`) is read-only. Paseo worktrees,
farm-created `~/.paseo/worktrees/<...>/<branch>/`, and manual
`git worktree add` are all acceptable.

**Branch name:** `<topic>-<YYYY-MM>` format (kebab-case + month).
Examples: `d5-body-canonical-2026-10`, `site-redesign-2026-10`.

**Lifecycle:**
  1. Create worktree (`paseo_create_workspace`, `git worktree add`, or `paseo` agent flow)
  2. Work in that worktree only; do not touch the main checkout
  3. Before push: `scripts/dev ready` inside the worktree
  4. PR or fast-forward to main when reviewer approved
  5. Cleanup: `scripts/dev close-branches` removes merged worktrees

**Convention enforcement:** `.githooks/pre-commit` warns when a
non-YYYY-MM branch is committed (see §Edit-loop prevention for the
broader pattern).

Exceptions: emergency hotfixes that must touch `main` directly (file
via `decisions/hotfix/<date>-<short>.yaml`); pure-doc edits to
`doc/`, `adoption/`, `README.md`, `PACKAGES.md`, `ROADMAP.md`,
`AGENTS.md`, `OCAML_BEST_PRACTICES.md`.

## Before picking work

Read `ROADMAP.md` §"Priority queue" for the active tier ordering.
Use `PACKAGES.md` §"Active policy" to find the matching decision file
and §"Fixtures" to find the matching acceptance test. Do not invent
priorities; pick the highest-priority unblocked task whose Tier matches
your capability and whose dependencies (test infrastructure, decision
files, fixtures) are already in `main`. Each task in the priority queue
names its decision file, fixture, and verifier; do not skip those or
you skip the obligation closure.

## When a dune or OCaml error appears

Before adding a workaround or running `rm -rf _build`:

1. Read `OCAML_BEST_PRACTICES.md` §11 (the trap log). Many recurring
   errors are recorded there with minimal reproducers.
2. If the error is not in the trap log, fix the underlying cause and
   append a new entry to §11 before merging.
3. Never `rm -rf _build` directly. Use `./scripts/dev rebuild`.

## OCaml toolchain — hard requirement

Every command that reads, writes, formats, type-checks, lints, or
compiles an OCaml source file MUST run inside `nix develop .#test`
(or via the `scripts/dev` subcommand wrappers). The host shell has
neither `ocamlformat` nor `ocamlmerlin` nor `ocaml` matching the
project's pinned version; running them outside the nix shell is a
guaranteed mismatch with `flake.nix`. Trap §11.22 documents one
failure mode; trap §11.7 documents another.

**Tool names — use these exactly:**

| Task             | Command (run in nix shell)                     |
|------------------|------------------------------------------------|
| Compile          | `dune build`                                   |
| Test             | `dune test`                                    |
| Format           | `dune fmt`   (uses ocamlformat 0.29.0)         |
| Format-check     | `DUNE_DISABLE_PROMOTION=1 dune fmt --preview`  |
| Type at a point  | `ocamlmerlin type-enclosing pos:file:line:col` |
| Locate a symbol  | `ocamlmerlin locate -look-for definition ...` |
| Occurrences      | `ocamlmerlin occurrences`                      |
| LSP              | `ocamllsp` (editor integration)                |

**Common pitfalls — these names do NOT exist:**

- `merlin` (the binary is `ocamlmerlin`)
- `ocaml-lsp-server` (the binary is `ocamllsp`)

If `command -v ocamlmerlin` fails inside `nix develop .#test`, the
flake is broken; rerun `nix develop .#test` to refresh the shell
closure. Run `scripts/dev doctor` to surface missing tools.

## mathc CLI (the project's own OCaml binary)

Build via `nix develop .#test` or `scripts/dev shell`. Then:

- `mathc validate <file>` — schema check (exit 0/1/2)
- `mathc self-check` — full attestation store verdict (exit 0/1/3)
- `scripts/generate-attestations.py` (reads a TSV manifest from stdin: `decision<TAB>obligation<TAB>kind_<TAB>producer_identity`) — records one attestation JSON per row in `attestations/` (writes the SHA-256 id automatically). Note: `mathc attest FILE` is the *JUnit XML importer*, not the attestation writer.
- `mathc explain-diagnostic MC-CODE` — remediation for diagnostic codes
- `mathc time-estimate --class <name> --count N --percentile p50|p80|p95|p99` — outside-view forecast per `bin/data/time-distribution.yaml`

## No Python for source edits

Python string handling mangles OCaml continuation strings
(`\<newline>`); see trap §11.33 for a real instance. Do not write
`python3 <<PYEOF ... open("lib/...") ... PYEOF` to edit `.ml`
files. Use:

- For one-line edits: `awk` or `sed` line-anchored substitutions.
- For new functions: write the function to `/tmp/foo.ml` via
  `cat <<'EOF'` heredoc (single-quoted to suppress shell expansion),
  then splice into the target file. Verify the splice visually
  (`sed -n 'A,Bp' file.ml`).
- For whole-file rewrites: write the whole file with `cat` heredoc,
  then `mv /tmp/foo.ml path/to/file.ml`, then `dune build` to
  validate.

Python is acceptable for: bulk YAML/JSON data sweeps over `decisions/`
or `fixtures/` (see `scripts/counterexample-seed.py`,
`scripts/axiom-link-seed.py`, `scripts/generate-attestations.py`),
and for cram-harness shell orchestration. It is NOT acceptable for
editing, generating, or rewriting OCaml source.

## Purpose

Math-coding links a concrete change to the obligations it may affect and
to bounded evidence about those obligations. It does not prove software
correctness.

The working chain is:

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

## Before work

Use an isolated branch or worktree. Inspect the current tree before
editing. Do not overwrite unrelated work.

For a meaningful change, state this compact contract before editing:

```yaml
intent: What should become true?
change_kind: implementation | decision | policy | constitution
affected_capabilities: []
must_preserve: []
counterexample: What plausible case would make this change wrong?
unknowns: []
planned_evidence: []
```

For a provably editorial change, state only:

```yaml
change_kind: editorial
reason: Why behavior and policy are unchanged.
```

## Friction

Apply the least sufficient response:

- `silent`: deterministic evidence shows no semantic or protected change.
- `record`: the change is meaningful but covered by existing decisions and evidence.
- `ask`: an answer would change behavior, risk, obligations, or recovery.
- `block`: an explicit policy requirement has an unresolved deficit.

Never block without naming the rule, affected subject, reason, and at
least one remedy. Unknown is not Pass. A waiver is not Pass.

## Edit-loop prevention

If 3 consecutive `dune build` attempts fail with the same error
class (paren mismatch, unbound value, type error in the same
file), STOP. This is a signal the approach is wrong, not a
transient syntax issue.

Replan:

1. Write `tests/probe_X.ml` that calls the failing function
   directly with a debug print, run it via `dune build` then
   `./_build/default/tests/probe_X.exe`.
2. Identify whether the issue is a SYNTAX fix (1-3 lines) or a
   STRUCTURE fix (refactor a deeply nested expression to a helper).
3. For nested match expressions (>3 levels of parens), normalize
   the INPUT in the outer wrapper rather than modifying the BODY
   of the inner match. The body then becomes a 1-line call, not
   a 100-line expansion.

Use `bash scripts/dev edit-loop-detect` to check if recent
commits show the pattern. See `decisions/process-principles.yaml:P8`
for the formal rule. See `OCAML_BEST_PRACTICES.md:§11.24` for
the OCaml-specific symptom.

## Decisions

Create a decision only for a new commitment, tradeoff, assumption,
public contract, risk acceptance, architecture, or policy change.

Do not create a decision for formatting, spelling, generated output,
evidence refresh, implementation of an existing decision, or a
behavior-preserving refactor with adequate characterization evidence.

Decision reasoning is proportional to risk:

- low risk: commitment, obligation, reversal condition;
- consequential: options, countercase, tradeoff;
- critical or irreversible: failure modes, recovery, independent review.

## Evidence

Distinguish sources:

```text
declared != derived != attested != reviewed != observed
```

An agent report is a declaration, not evidence. A passing test only
attests to its named obligation, subject, inputs, environment, and run.
Do not claim stronger assurance than the source supports.

Prefer existing tests, CI, reviews, and standard reports. Do not rerun
or duplicate evidence when relevant material digests are unchanged.

## After work

Report only the knowledge delta:

```yaml
changed: []
preserved: []
evidence: []
new_assumptions: []
remaining_unknowns: []
```

Run all available relevant checks. If a check cannot run, state why.

## Definition of Done (checklist)

Before opening a PR or marking work complete, verify:

- [ ] `scripts/dev ready` exits 0 (full aggregator)
- [ ] `mathc validate decisions/<id>.yaml` exits 0
- [ ] `mathc self-check` exits 0 OR new obligation has `evidence: manual-acceptance` with named owner
- [ ] New obligation paired with attestation at `attestations/<decision-id>-<obligation>.json` (via `scripts/generate-attestations.py` TSV manifest)
- [ ] If version literal changed: `scripts/sync-version.sh --check` exits 0
- [ ] If schema changed: `tests/conformance.ml` updated; positive + negative fixture in `fixtures/conformance/<family>/`
- [ ] If kernel/CLI changed: cram snapshot regenerated via `dune promote` (in worktree)
- [ ] PACKAGES.md counters block re-anchored if decision counts changed
- [ ] No `stub`/`FIXME`/`Phase <N>` in lib/ or bin/ without paired `decisions/<id>.yaml` (run `scripts/check-stub-lint.sh`)
- [ ] Branch is a worktree, not main checkout
- [ ] Commit subject uses Conventional Commits prefix

## Fast path (process-fastpath-2026-10)

The Definition of Done above was designed for `kernel-change`-class
work (P95 ≈ 150 min per the reference-class table). For
`single-file-edit` / `bug-diagnosis` / `trivial` work, every
ceremony entry above is a 5-10× overhead that the agent
should not have to pay. The fast path is the formal
realisation of the existing `silent` friction level (AGENTS.md
§Friction): a change is silent when deterministic evidence
shows no semantic or protected change; the work is then
recorded, not gated.

**Eligibility (all four must hold):**

1. net change ≤ 50 lines, OR change is localisable to ≤ 2 files;
2. no change to `schemas/`, `decisions/`, `policies.yaml`, or
   any `*Constitution*` file;
3. no introduction of a new obligation / new attestation /
   new policy term;
4. you can describe the bug or change in two sentences.

**Fast path obligations (in lieu of the full Definition of Done):**

- [ ] A regression test in the relevant `tests/*.ml` file
      (positive case at minimum; negative case only when
      distinguishing from a sibling case is non-trivial);
- [ ] `scripts/dev test-fast <your-test-binary>` exits 0
      (per-binary, not the full stanza — see
      `OCAML_BEST_PRACTICES §11.34` for why);
- [ ] If the change affects rendered site output, re-render
      once via `scripts/render.sh` and visually verify the
      affected `dist/*.html` file (do not chain multiple
      full re-renders; the probe `scripts/dev probe
      --file site/<name>.md` is the cheaper check);
- [ ] Branch is a worktree, not the main checkout;
- [ ] Commit subject uses Conventional Commits prefix;
- [ ] One-line `Knowledge delta` block in the agent report
      (per the existing "After work" section).

The fast path is opt-in per change: the agent states at the
top of the work log "fast path" plus the four eligibility
assertions, and proceeds. Reviewers can request re-validation
under the full path if any of the four assertions are
contested.

The fast path is the default for `docs-only` and
`single-file-edit` reference classes. It is **not** permitted
when the change touches `lib/decision.ml`, `lib/policy.ml`,
`lib/risk.ml`, or any file the constitution marks as
protected; those changes take the full path regardless of
size.

**P1 and the fast path.** Process-principle P1 (a
`decisions/*.yaml` change must accompany any kernel/spec
change) is enforced at commit time by `.githooks/pre-commit`.
The fast path does not waive P1 — a `lib/*` change still
needs a decision file. What the fast path waives is the
slow verification (stage 3 of `scripts/dev ready`,
`mathc self-check`) and the attestation store write
(stage 4 of the existing Definition of Done). A
fast-path `lib/*` change therefore pairs the smallest
defensible decision (one file, mode: light, no
attestations) with a regression test. Concretely:

  - `lib/decision.ml`, `lib/policy.ml`, `lib/risk.ml` —
    protected files; full path always.
  - Other `lib/*` files — fast path is permitted IF a
    minimal `decisions/<id>.yaml` lands in the same commit
    (P1 closure).
  - `schemas/`, `policies.yaml`, `*Constitution*` — full
    path always.

Each item references an existing verifier; the checklist is not
additional ceremony, it lists the existing checks in order.

## Agent conduct

- Use project memory and a bounded context capsule instead of reading
  every historical decision.
- Suggest failure modes and obligations; do not present inference as
  policy or evidence.
- Ask only questions whose answers change implementation, obligations,
  risk, recovery, or the gate.
- Preserve uncertainty explicitly instead of inventing values.
- Do not store private chain-of-thought, secrets, or unnecessary
  personal data in project artifacts.

## Honest time reporting

When the agent makes a claim about how long a past or future task
"took", "will take", or "should take", it MUST name one of three
observable scales, cite a reference class, and not combine the
three scales into a single natural-language estimate.

The three allowed scales are:

```text
wall-clock-minutes   real seconds/minutes from session start to now
                     (or the runtime harness's own clock)
token-budget         prompt + completion tokens consumed
step-count           tool calls / reasoning rounds performed
```

These three are independently observable. Wall-clock is recorded
by the user or runtime harness; token-budget by the API; step-count
by the harness. No fourth scale is acceptable without an axiomatic
justification (A0 separation).

For a forward-looking estimate (e.g., "this refactor will take
~20 min"), the agent MUST cite a reference class. The default
reference class for software-engineering work in this repository
is `bin/data/time-distribution.yaml`, which is a declared
distribution from SWE-bench Verified (n=500, 2025-Q4 frontier). The
canonical estimator command is:

```text
mathc time-estimate --class <name> --count N --percentile p50|p80|p95|p99
```

The agent MUST NOT replace this estimator with private intuition
or with phrases such as "a few days of focused thought" or "a
month of work" that combine scales or omit a reference class.

Anti-patterns:

- "I have spent days on this." — unless wall-clock is recorded.
- "This is a one-month project." — unless reference-class uplifted
  (P95 of SWE-bench-V for class `kernel-change` is 150 min; a
  one-month claim requires a different reference class with a
  decision citing it).
- "Quick fix, a few minutes." — when actual time is unknown.
- Mixing scales: "a week of careful thinking" confuses wall-clock
  (a week) with subjective attention (careful thinking). Pick
  one scale; the other must be in a separate claim.

This norm is normative (see axiom A1 Feedback — every commitment
must have a path to an observation). The agent's duration claims
are commitments. Without an observable scale + reference class they
are wishes.

## Honest time reference-class table

Reference classes (from `bin/data/time-distribution.yaml`, SWE-bench
Verified n=500, 2025-Q4 frontier models; unit = minutes):

| Class              | P50 | P95 | When to use |
|--------------------|-----|-----|-------------|
| `trivial`          |   1 |   3 | Single-line typo fix |
| `docs-only`        |   2 |   6 | Markdown/AGENTS.md edit, no code |
| `single-file-edit` |   3 |  10 | One .ml file, no kernel change |
| `bug-diagnosis`    |   5 |  18 | Find root cause of an existing bug |
| `multi-file-edit`  |   9 |  30 | 2-5 .ml files, additive |
| `refactor`         |  12 |  45 | Same behaviour, restructured code |
| `feature-add`      |  20 |  70 | New CLI subcommand or capability |
| `schema-change`    |  25 |  90 | JSON-schema + fixture pair |
| `kernel-change`    |  40 | 150 | lib/* type/checking logic |

Multipliers (opt-in; agent must name them): `per_artifact_over_first`,
`mixed_class_scope`, `cross_language_non_ocaml`, `test_required_with_runtime`.
For a 5-file change with mixed scope and tests required:
40 (kernel-change) × 2.2 (per_artifact 4-5) × 1.3 (mixed_class) × 1.2
(test_required) ≈ 137 min (P50 × multipliers). P95 ≈ 515 min.

Reference: `mathc time-estimate --class <name> --count N --percentile p50|p80|p95|p99`.

## Self-application

Changes to this protocol, the constitution, schemas, canonicalization,
kernel, or protected policy controls always require:

1. a decision under the currently active rules;
2. a strongest practical countercase;
3. positive and negative conformance fixtures;
4. a migration and recovery path;
5. authorization by the previous active policy;
6. an explicit list of changed verdicts.

Candidate rules cannot authorize their own adoption.

## Bootstrap gate

The bootstrap protocol expired at commit `8fa7fcf` (v3.0.0.19,
2026-09-29). The eight manual checks below remain *additive*
obligations for agents working on protected policy transitions
(constitution, kernel, gate rules, authority rules, waiver rules);
they are no longer the only enforcement mechanism for routine
work.

For routine changes, automated guarantees apply: `mathc validate`
on the diff checks schema/reference/identity, `mathc gate BASE HEAD`
reports the assurance verdict, and CI blocks merge on a
non-pass verdict via `mathc self-check`. The agent still owes:

- the intended behavior and affected capabilities are explicit;
- known invariants are preserved or deliberately revised;
- the strongest relevant counterexample has been considered;
- planned evidence is available or its absence is declared;
- every known blocking deficit has a remedy;
- rollback or forward recovery exists for irreversible work;
- specification changes include positive and negative fixtures.

For the protected-policy transition checklist (decision under
prior policy, strongest countercase, fixtures, migration,
recovery, prior authorization, verdict diff) see
`AGENTS.md §Self-application`.
