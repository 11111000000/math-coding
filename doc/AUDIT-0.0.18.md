# Release audit — math-coding 3.0-alpha-0.0.18

> Author: subagent on behalf of Petr Kosov <p.b.kosov@yandex.ru>
> Branch: main, HEAD `1473001` (tag `v3-alpha-0.0.17`)
> Date: 2026-09-27
> Status: release-time audit. This document records the consolidated
> state of the v0.0.18 release (5 commits since v0.0.17), closes the
> v0.0.18-1 through v0.0.18-5 plan steps, and explicitly carries
> forward the open audit debts that are NOT closed in this release.
> No kernel change is included in v0.0.18. No dependency is added.
> The release is documentation + convention only.

## Summary of the release

| Step | What | Commit |
|------|------|--------|
| v0.0.18-1 | cleanup: remove `legacy/`, add `result/` to `.gitignore` | `f2f527f` |
| v0.0.18-2 | rename `bootstrap/` → `decisions/` (single atomic commit) | `8bcc97a` |
| v0.0.18-3 | codify the onboarding convention (Winner-1) | `d034a14` |
| v0.0.18-4a | add canonical onboarding record (ONBOARDING.md) | `8aac261` |
| v0.0.18-4b | codify the formal-verifier-prefix convention (Winner-2) | `1473001` |

## Status

### Tag chain (post-release)

```
v0.0.10         consolidation
v0.0.11         foundation audit
v0.0.12         priority drift detector
v0.0.13         spec-cli-catalog
v0.0.14         audit D7 (adapters covers both git and junit)
v0.0.15         documentation consolidation
v0.0.16         process principles as enforceable obligations
v0.0.17         UX cleanup: rename .md → .yaml in decisions/
v0.0.18         release consolidation (this audit)
```

### Convention layer (the new content of v0.0.18)

`decisions/agent-onboarding.yaml` (rev 1, 4 obligations, RESOLVED):
- codifies the convention that ADRs are `decisions/<topic>.yaml`
- codifies the convention that the first file a new agent reads
  is ROADMAP.md
- codifies the convention that the convention is recorded as
  a decisions/ file (A3 self-application)
- codifies the discoverability requirement (row in PACKAGES.md)

`decisions/ONBOARDING.md` (rev 1, no schema, 2 obligations, RESOLVED):
- the canonical onboarding record for a new agent
- the structural map of the repository (one place to read for
  the full file inventory and the read-first order)
- 8 sections: Status, Purpose, Directory map, Read-first order,
  Axioms, Protocol surface, Conventions, State
- 771 lines, self-applies to the convention (this file is itself
  a decisions/ file, the convention is recorded as a
  decisions/<topic>.yaml file)

`decisions/formal-verifier-conventions.yaml` (rev 1, 2 obligations,
RESOLVED):
- codifies the `tla:/coq:/alloy:` prefix convention for formal-
  verifier artefacts
- codifies the file path convention
  `decisions/<topic>/formal/<lang>.<ext>`
- the convention is documentation only; no tool is added
- codifies the no-tool rule (P5-cram-retired already establishes
  the no-tool precedent; this is a sibling convention)
- codified in `OCAML_BEST_PRACTICES.md §10.6` (the convention
  index in that file)

## Carry-forward audit debts (open from v0.0.11)

### Closed in v0.0.18

- **D4′** (D4-prime, result/ in .gitignore) — closed at v0.0.18-1
  (commit `f2f527f`).

### Newly open

None. v0.0.18 does not open any new audit debt.

### Still open from v0.0.11 (carried forward)

- **D1** — YAML `|` block scalars. Decision recorded
  (`bootstrap/yaml-block-scalars.yaml@2`; now
  `decisions/yaml-block-scalars.yaml@2` after the v0.0.18-2
  rename). Implementation pending; the kernel change is in
  `lib/codec.ml`. The deferral is recorded in
  `decisions/yaml-block-scalars-impl-pending.yaml@1`.
- **D2** — YAML `---` front-matter. Same decision; same status.
  D1 and D2 are tied: the kernel change is one PR.
- **D4** — SHA-256 RFC 6234 vectors. The hand-rolled SHA-256
  in `lib/digest.ml` has not been validated. The test
  `tests/digest_vectors.ml` exists with the vectors but is
  `xfail until Digest is fixed`. The fix is the top-priority
  open kernel work; it cannot be closed by a documentation-only
  release. v0.0.18 explicitly does NOT touch this.
- **D6** — manual-only verifiers. The 13 obligations in
  `bootstrap/decision.yaml@2` (now `decisions/decision.yaml@2`)
  have manual-only verifiers because the kernel that would
  auto-verify them does not exist. The convention is itself an
  obligation (winner-1 in v0.0.18 records this). D6 expires
  when the 3.0 kernel successfully checks this repository
  (`AGENTS.md §Bootstrap gate`).
- **D8** — coarse `mathc validate` diagnostic. The kernel
  synthesises "missing or invalid required field" without
  naming the field. Fix is to promote `Decision.parse_decision`
  to return `Diagnostic.t option` (3.0-beta work).

### Closed previously (recap)

For completeness, the audit debts that were closed at
v0.0.10 / v0.0.14 are: D5 (stale mathc_main.ml), D7
(adapters covers both git and junit). D3 (priority-drift
detector) is closed (the detector exists; the
`tests/repo_structure.ml:verify_spec_vs_bp_priority` fixture
exercises it). D2′ was closed at v0.0.18-1.

## Convention enforcement (added in v0.0.18)

Two new OCaml tests in `tests/repo_structure.ml` (planned in
v0.0.18-5b, not part of the audit commit):

- `verify_agent_onboarding_conventions` — asserts that
  `decisions/agent-onboarding.yaml` exists, AGENTS.md has
  the "Read first" section, and PACKAGES.md has a row for
  `agent-onboarding`.
- `verify_formal_verifier_prefixes` — asserts that
  `OCAML_BEST_PRACTICES.md §10.6` exists with the
  tla:/coq:/alloy: prefix table, and that
  `decisions/formal-verifier-conventions.yaml` exists.

These tests are planned for v0.0.18-5b as a follow-up commit
because the underlying convention is now documented and the
implementation can be added without re-deriving the convention.

## What v0.0.18 did NOT do

- No kernel change. `lib/` is unchanged from v0.0.17. The
  reason: v0.0.18 is a documentation/consolidation release; the
  next kernel work (D1/D2 yaml blocks, D4 SHA-256 verification,
  D8 coarse diagnostic) is in v0.0.19.
- No new runtime dependency. `flake.nix` is unchanged from
  v0.0.17 (modulo shell wrappers in `nix develop` to find
  Ocaml packages).
- No schema change. `schemas/*.json` is unchanged.
- No TLA+, Coq, or Alloy tool integration. The conventions
  recorded in v0.0.18-4b are documentation only; a tool is
  invoked manually by the human author.
- No new decision file in `decisions/` other than
  `agent-onboarding.yaml` and `formal-verifier-conventions.yaml`
  and `ONBOARDING.md`. The convention layer is the focus of
  v0.0.18; the protocol layer (kernel work) is the focus of
  v0.0.19.

## Verification (release-time)

Run `./scripts/check.sh` to aggregate shell fixtures and Cram
tests, or `nix develop .#test --command bash -c 'dune test --root .'`
to run the OCaml/Alcotest suite. The conformance runner is at
`tests/conformance.ml`; the structural convention checks are at
`tests/repo_structure.ml`. The P1-P7 process-principles fixture
is at `tests/process_principles.ml` (Alcotest). The current tag
chain is in `git tag --list | grep v3-alpha`. The current decision
chain is in `git log --oneline decisions/`. The audit chain is in
`doc/AUDIT-0.0.18.md` (this file).
