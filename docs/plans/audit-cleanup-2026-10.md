---
schema: math-coding/3.3
id: audit-cleanup-2026-10
revision: 1
state: active
mode: standard

intent: |
  Close the seven audit deficits identified on HEAD `db69ca2`
  by the 2026-10-17 read-only audit (CHANGELOG entry forthcoming).
  Each item is a `<,=<,20-line` change with a single verifier
  reachable from `scripts/dev ready`; no kernel/protected-file
  changes in this slice.

scope:
  capabilities:
    - p1-strictness
    - self-check-verdict
    - version-banner
    - doc-trap-log-count
    - stub-lint
  paths:
    - "scripts/dev"
    - "ROADMAP.md"
    - "PACKAGES.md"
    - "bin/Mathc.ml"
    - "decisions/considered-mode-migration-2026-10.yaml"
    - "decisions/docker-arm64-image-2026-10.yaml"
    - "attestations/fix-mcp-sigpipe-*.json"
    - "attestations/fix-curl-exit-code-*.json"
    - "attestations/fix-validate-id-*.json"
    - "attestations/render-module-split-*.json"
    - "attestations/constitution-header-3-3-update-2026-10-*.json"
    - "attestations/enable-counters-drift-test-2026-10-*.json"
    - ".gitignore"

commitment: |
  All seven items land in a single PR with one attestation per
  generated obligation. No kernel changes. No protected-file
  changes (`lib/decision.ml`, `lib/policy.ml`, `lib/risk.ml`).
  The bigger follow-ups (kernel widening in
  `lib/re_evaluation.ml::classify_verifier`,
  `render-ordered-lists-2026-10` parser bug) are explicitly
  out of scope and recorded in this file's unknowns.

outcomes:
  - id: p1-pass-clean
    statement: |
      `scripts/dev ready` stage 2 (process_principles.ml) exits 0.
      P1's "every non-meta decision file has body sections" test
      passes for both considered-mode-migration-2026-10 and
      docker-arm64-image-2026-10.
  - id: stub-lint-clean
    statement: |
      `scripts/check-stub-lint.sh` exits 0 on the resulting tree.
      The three `Phase <N>` markers in `bin/Mathc.ml`'s
      telemetry status output are either removed or carry a
      `tracked: decisions/ux-3-telemetry-stub-2026-10.yaml`
      acknowledgement on the same physical line.
  - id: self-check-verdict-up
    statement: |
      `mathc self-check` unknown subject count drops from 16 to
      ~10 (the 4-6 low-hanging-fruit closures flip to pass; the
      rest remain unknown and are tracked separately). Verdict
      may still be `unknown` because some manual-style verifiers
      remain structurally inconclusive (kernel widening, deferred).

counterexample: |
  Adding `mode: light` to `considered-mode-migration-2026-10.yaml`
  is a one-line change to a retired decision. The strongest
  objection: silently weakening the dialectical-slot contract
  for retired decisions. Mitigation: the decision is `state:
  retired` (a historical record, not active guidance); the spec
  at `spec/algebra-3.2.md` §11 only requires counterexample for
  `mode >= standard` in `state: active` decisions. Adding
  `mode: light` to a retired file preserves the contract for
  active decisions and the dialectical-slot content remains in
  the `commitment` block of the decision (line 24-27 of the
  YAML), so the historical record is preserved.

obligations:
  - id: w1-banner-version
    outcome: p1-pass-clean
    claim: |
      `scripts/dev` line ~225 banner literal "3.3.0" → "3.3.1"
      to match `VERSION` and `mathc version` output.
    acceptance:
      all:
        - verifier: scripts/dev line contains "3.3.1"
        - verifier: text-scan-banner-version-3-3-1
  - id: w2-roadmap-p5-trap-count
    outcome: p1-pass-clean
    claim: |
      `ROADMAP.md` §P5 line 319 "trap log has 34 entries
      (§11.1–§11.34, verified by `grep -c '...'`)" updated to
      "39 entries (§11.1–§11.39)". The verification regex
      already returns 39; only the prose is stale.
    acceptance:
      all:
        - verifier: text-scan-trap-log-39
  - id: w3-packages-last-verified
    outcome: p1-pass-clean
    claim: |
      `PACKAGES.md` "Last verified at: HEAD ..." line updated
      to `HEAD db69ca2` and counters refreshed against
      `mathc counters --format=json`.
    acceptance:
      all:
        - verifier: text-scan-head-db69ca2
  - id: w4-decision-risk-blocks
    outcome: p1-pass-clean
    claim: |
      Two decision files gain a `risk:` block (P1 strictness
      requires it for every non-meta non-aggregator decision):
      - `decisions/considered-mode-migration-2026-10.yaml`
        gains `risk: low (retired decision; dialectical-slot
        content preserved in commitment block)`.
      - `decisions/docker-arm64-image-2026-10.yaml` gains a
        `risk:` block sized to the multi-arch build.
    acceptance:
      all:
        - verifier: text-scan-risk-block-present
  - id: w5-stub-markers-bin-mathc
    outcome: stub-lint-clean
    claim: |
      `bin/Mathc.ml` lines 785, 5313, 5327 — three `Phase <N>`
      markers in the telemetry subcommand — are exempted by
      adding `tracked: decisions/ux-3-telemetry-stub-2026-10.yaml`
      on the same physical line. User-visible help text changes
      by appending `; tracked: decisions/ux-3-telemetry-stub-2026-10.yaml`
      to each marker text. Net diff: ≤9 lines.
    acceptance:
      all:
        - verifier: scripts/check-stub-lint.sh
          result: pass
  - id: w6-close-low-hanging-attestations
    outcome: self-check-verdict-up
    claim: |
      Six `unknown` self-check subjects flip to `pass`:
      fix-mcp-sigpipe (1), fix-curl-exit-code (1),
      fix-validate-id (1), render-module-split (1),
      constitution-header-3-3-update-2026-10 (1),
      enable-counters-drift-test-2026-10 (1-3 of 3).
      Mechanism: `scripts/generate-attestations.py` with a
      TSV manifest, `kind_: review` or `kind_: build` as
      appropriate, `producer: human:maintainer`. Negative
      fixtures are not added in this slice (the obligations
      are 1-1, no sibling case to distinguish).
    acceptance:
      all:
        - verifier: mathc self-check --format=json
          result: pass-count-grew-by-6
  - id: w7-gitignore-re-eval-scratch
    outcome: stub-lint-clean
    claim: |
      `.gitignore` adds a line for `attestations/t1-2-A0-*.json`
      so the `mathc re-evaluate-decisions` scratch files
      (552 untracked files in local trees) don't pollute
      `git status` and don't confuse the self-check verdict
      (they're `result: inconclusive` and would mask the
      real `result: pass` count if not git-ignored).
    acceptance:
      all:
        - verifier: text-scan-gitignore-re-eval-scratch

risk: |
  Low. All changes are scoped to documentation, decision-file
  body fields, and a known-trackable stub-lint exemption. The
  strongest residual risk is the attestation-batch writes under
  W6 — these are declarative, but a wrong `kind_` tag could
  regress an obligation from `pass` to `unknown`. Mitigation:
  manifest is built by reading each decision's first verifier
  and tagging `kind_: review` only when no test/build is
  reachable.

reversal:
  signal: any obligation that flips from `pass` to a lower
  verdict under `mathc self-check` after this commit lands.
  remedy: revert the offending attestation, regenerate the
  manifest, re-apply.

unknowns:
  - `lib/re_evaluation.ml::classify_verifier` kernel widening
    to flip the 16 manual-style subjects to pass. Recorded as
    separate decision `audit-cleanup-classify-verifier-widening-2026-10`
    (TODO when this PR lands).
  - `render-ordered-lists-2026-10` parser drops the second
    obligation. Kernel bug, separate decision when triaged.
  - `considered-mode-migration-2026-10.yaml` is `state: retired`
    but still appears in active P1 check; long-term fix may
    warrant an explicit "skip retired" rule in
    `tests/process_principles.ml`. Out of scope for this slice.