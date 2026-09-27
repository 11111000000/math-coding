# Math-coding 3.0-alpha semantics

## Authoring vs Canonical

Authors submit a compact request:

```yaml
intent: Search remains available when Redis is unavailable.
decision: Fall back to origin.
subjects:
  - capability:search-availability
preserve:
  - Cached responses are no older than 60 seconds.
unknowns:
  - Can origin sustain full fallback traffic?
reconsider_when:
  - Origin error rate exceeds 5%.
```

`mathc draft` compiles it into the canonical intermediate
representation. The agent does not write:

- digests;
- revision identifiers;
- timestamps;
- freshness;
- trust levels;
- derived risk tier;
- gate results.

Invariant: `AgentNeverAuthorsDerivedData`.

## Evaluation

For obligation `o`, change `c`, gate `g`, active policy `p` and
evaluation time `t`:

```text
current(a) iff
  a.revisions resolve
  a.materials_digest equals digest(relevant materials of c)
  a.validity interval contains t
  a.method satisfies Req(p, o, g)
```

```text
Pass(o, c, g) iff
  some a is current and a.result = pass
  and no policy-defined decisive failure
Fail(o, c, g) iff
  some current decisive a reports fail
Unknown(o, c, g) iff
  otherwise
```

The kernel MUST create or report an AssuranceGap for every applicable
`Fail`, `Unknown`, `Stale`, `AtRisk` or `InfrastructureError`.

A valid Waiver changes gate disposition only:

```text
disposition(gap) = waived
```

It MUST NOT change the underlying assurance result.

## Friction

```text
silent < record < ask < block
```

The kernel requires:

- `block` when a gate has a blocking, unwaived AssuranceGap;
- `ask` when a declared unknown can change behavior, obligation, risk,
  recovery, authority or gate disposition;
- `record` for meaningful work covered by active decisions and
  sufficient evidence;
- `silent` only when deterministic checks establish no semantic or
  protected change.

Human or advisor review MAY raise the mode. Only authorized policy
MAY lower a policy default, and only through a valid Waiver.

## Merge Gate

A change MAY merge only if:

1. its schema, references, relations and digests are valid;
2. change coverage is complete under deterministic policy;
3. every required obligation is `pass` or has a valid merge waiver;
4. no non-waivable merge gap exists;
5. required reviews and authorities are present;
6. protected transitions satisfy the prior-policy rule;
7. all kernel-enforced normative changes have positive and negative
   fixtures.

A merge with a Waiver MUST report `open-with-waiver`, never `pass`.

## Release Gate

A revision MAY release only if:

1. every included change satisfies the merge gate;
2. the release artifact digest is attested;
3. all release-required obligations pass;
4. no release-blocking gap is missing, stale, failed, inconclusive or
   infrastructure-error without a waiver;
5. every remaining waiver is explicitly allowed at release, unexpired,
   scoped, has an owner and a follow-up deadline;
6. migration and recovery evidence exists for irreversible or
   protected changes;
7. the released kernel passes the complete conformance corpus;
8. the kernel successfully checks the repository under the policy
   being released.

The release verdict MUST be one of `pass`, `open-with-waiver`, or
`block`.

## Revisions

A new revision MUST:

- reference its immediate predecessor by digest;
- preserve prior accepted revisions;
- state changed fields and resulting verdict changes;
- invalidate attestations whose bounded material changed.

A changed commitment MUST use `supersedes`, not merely `revises`.

## Protected Policy Transition

For transition `(P0 -> P1)`:

```text
Adopt(P0, P1) valid iff
  P0 authorizes the transition
  the authorizing decision was accepted under P0
  P1 contributes no authority to its own adoption
  countercase, fixtures, migration, recovery and verdict diff exist
  K_P0(P1) = allow
```

After adoption, an activation boundary is recorded. Changes before
that boundary evaluate under `P0`; later changes under `P1`.

## CLI subcommands

The `mathc` CLI (executable `bin/mathc.exe`, module `Mathc`) ships
the following subcommands as of HEAD. The list is normative: an
implementation MUST NOT add a new subcommand without first adding
a row here, and MUST NOT change a subcommand's documented exit
code without a corresponding spec edit. The header comment in
`bin/Mathc.ml` remains the implementation summary; this section
is the authoritative contract.

Exit codes follow `OCAML_BEST_PRACTICES.md` §4.3:

| Code | Meaning |
|---|---|
| 0 | accept / pass |
| 1 | block / reject |
| 2 | input error (file missing, malformed JSON/YAML, bad CLI args, bad git ref) |
| 3 | internal error (uncaught exception) |

For every subcommand the spec names five things: synopsis, input
arguments, output shape (text vs JSON and the field set), exit
code, and the bootstrap decision that justifies the subcommand's
existence. Output JSON objects use sorted keys for reproducibility.

### `version`

- **Synopsis**: `mc version`
- **Input**: none.
- **Output**: text. Prints `math-coding 3.0-alpha: bootstrap`
  and a trailing newline.
- **Exit code**: `0`.
- **Justification**: `bootstrap/validate-and-context.md`
  obligation `cli-version-preserved` (the v0.0.5 hello-string
  is reachable as a subcommand instead of being the bare
  default).

### `validate FILE [--format=text|json]`

- **Synopsis**: `mc validate FILE [--format=text|json]`
- **Input**: `FILE` is the path to a Decision in `.json`,
  `.yaml`, or `.yml`. `--format` selects the output renderer;
  default `text`.
- **Output**:
  - text: `accept | reject: <path>` followed by indent-indented
    fields (`decision`, `revision`, `obligations`, `assumptions`,
    or `code`, `severity`, `message`).
  - json: a single JSON object on stdout. Verdict `accept` carries
    `verdict`, `path`, `decision`, `revision`, `obligations`,
    `assumptions`, and optionally `diagnostics[]` when extra
    diagnostics fire (e.g., `MC-AMBIGUOUS-ACCEPTANCE`). Verdict
    `reject` carries `verdict`, `path`, `code`, `severity`,
    `message`. Extra diagnostics for an accept verdict print
    on stderr but do not change the verdict.
- **Exit code**: `0` accept, `1` reject, `2` input error
  (missing file, unparseable JSON/YAML, bad CLI args),
  `3` internal error.
- **Justification**: `bootstrap/validate-and-context.md`
  obligations `cli-validate-decision` and
  `jsonl-array-parser-fixed`.

### `context BASE HEAD --budget N`

- **Synopsis**: `mc context BASE HEAD --budget N`
- **Input**: `BASE` and `HEAD` are positional git refs (commit,
  branch, tag); `--budget N` is the maximum byte budget for the
  capsule (default 8192). `BASE..HEAD` selects the candidate
  tree.
- **Output**: a single JSON object on stdout containing at
  least these top-level keys: `base`, `change` (object with
  `base`, `head`, `items[]`), `decisions[]`, `head`, `items[]`,
  `now`, `obligations[]`, `omitted[]`, `total_bytes`, `truncated`.
  Items are sorted and truncated by the priority order in the
  next section. Each item carries `detail_ref`, `summary`,
  `priority` (one of the six priority names), and optional
  `freshness` (ISO 8601 UTC). Omitted items appear in `omitted[]`
  with an `expansion` command of the form `mc explain <detail_ref>`.
  `truncated` is `true` iff `omitted` is non-empty.
- **Exit code**: `0` always on a successful git invocation;
  `2` on input error (missing positional, bad `--budget`,
  bad git ref).
- **Justification**: `bootstrap/validate-and-context.md`
  obligations `cli-context-capsule` and
  `capsule-byte-budget-tracked`.

### `assess BASE HEAD`

- **Synopsis**: `mc assess BASE HEAD`
- **Input**: `BASE` and `HEAD` are positional git refs
  (commit, branch, tag).
- **Output**: a JSON array on stdout listing the file paths
  changed in `BASE..HEAD` (one path per element, double-quoted
  JSON string). The empty array `[]` means `git diff
  --name-only` reported no changes.
- **Exit code**: `0` on success; `2` on input error
  (missing positional, bad git ref, git command fails).
- **Justification**: `bootstrap/adapters.md`
  obligation `git-changed-files-adapter`.

### `attest FILE`

- **Synopsis**: `mc attest FILE`
- **Input**: `FILE` is the path to a JUnit-format XML report.
- **Output**: a single JSON object on stdout summarising the
  JUnit report. Soft parse errors (malformed XML inside an
  existing file) populate an `error` field and still exit `0`;
  only a missing or unreadable `FILE` triggers a non-zero exit.
  Fields when present: `suite_name`, `test_count`,
  `failure_count`, `error_count`, `skip_count`, `tests[]`
  (each entry: `classname`, `message` (optional string), `name`,
  `result` (one of `pass` / `fail` / `error` / `skip` /
  `unknown`), `time` (numeric seconds, may be `null`)).
- **Exit code**: `0` on success (including soft parse errors);
  `2` only when `FILE` is missing or unreadable.
- **Justification**: `bootstrap/adapters.md`
  obligation `junit-attestation-import`.

### `gate BASE HEAD`

- **Synopsis**: `mc gate BASE HEAD`
- **Input**: `BASE` and `HEAD` are positional git refs
  (commit, branch, tag).
- **Output**: a single JSON object on stdout with the keys
  `verdict`, `base`, `gaps`, `head`, `now`, `obligations`
  (count). `verdict` is `pass`, `block`, or `unknown` in this
  scaffold iteration; `gaps[]` lists each applicable obligation
  with `kind` (`MissingEvidence` / `StaleEvidence` /
  `MissingReview` / `NoAttestationStore` / `Unknown`),
  `causes[]`, `obligation_id`, `remedies[]`. This is the
  scaffold: without an attestation store, applicable
  obligations surface as `Unknown` and the verdict is
  `unknown` (informational, not blocking). Full blocking
  arrives with the attestation store.
- **Exit code**: `0` always today (the gate verdict is
  informational in the scaffold; `mc gate` does not yet block
  merges). The disposition-vs-exit-code mapping documented
  above (1 = block) is forward-looking; today the JSON
  verdict carries the disposition and the exit code is 0.
- **Justification**: `bootstrap/gate-decision.md` (the
  scaffold).

### `session-start`

- **Synopsis**: `mc session-start`
- **Input**: none.
- **Output**: text. The current UTC instant as an ISO 8601
  timestamp (`YYYY-MM-DDThh:mm:ssZ`) is written to
  `.local/session-start` inside the project root, overwriting
  any prior value. The same timestamp is printed on stdout.
  When the environment variable `MATH_CODING_FIXED_TIME` is
  set to a non-empty value, that value replaces the wall clock
  (test/determinism hook; see `OCAML_BEST_PRACTICES.md` §11.16).
- **Exit code**: `0`.
- **Justification**: `bootstrap/time-honesty-storage.yaml`
  obligation `session-start-valid`.

### `record --decision-id ID [--revision REV] --scale S [--class C] [--value N]`

- **Synopsis**:
  `mc record --decision-id ID [--revision REV] --scale S [--class C] [--value N]`
- **Input**:
  - `--decision-id ID` — the Decision identifier this event
    attaches to. Required.
  - `--revision REV` — the Decision revision (a digest or a
    label). Optional; defaults to `current`.
  - `--scale S` — the scale of the recorded value.
    Required. One of `wall-clock-minutes` or `step-count`.
  - `--class C` — the task class name from
    `bin/data/time-distribution.yaml`. Optional.
  - `--value N` — a numeric value. Accepted only for
    `step-count`; rejected for `wall-clock-minutes` (the
    value is auto-computed from `now - session_start`).
- **Output**: a single JSON object is appended to
  `bootstrap/execution-logs.jsonl` and echoed on stdout.
  Fields (sorted): `class` (optional), `decision_id`,
  `decision_revision`, `observed_by`, `recorded_at`, `scale`,
  `value`, `v` (= 1). `wall-clock-minutes` rejects the
  `--value` flag with exit 2 and a diagnostic on stderr.
- **Exit code**: `0` on append; `2` on missing required flag,
  invalid `--scale`, rejected `--value`, missing session-start
  file (`MC-SESSION-MISSING`), unparseable timestamp, or write
  failure.
- **Justification**: `bootstrap/time-honesty-storage.yaml`
  obligation `record-no-user-value-for-wallclock`.

### `stats [--scale S] [--class C] [--since ISO]`

- **Synopsis**: `mc stats [--scale S] [--class C] [--since ISO]`
- **Input**: optional filters:
  - `--scale S` — restrict to one scale
    (`wall-clock-minutes` or `step-count`).
  - `--class C` — restrict to one task class.
  - `--since ISO` — ISO 8601 UTC timestamp; events
    `recorded_at` before it are filtered out.
- **Output**: a single JSON object on stdout. Fields:
  `class` (string, may be empty), `n` (int — the number of
  events that matched), `quantiles` (object — present only
  when `n >= 30`, containing `p50`, `p80`, `p95`, `p99`),
  `scale` (string, may be empty), `since` (string, may be
  empty), `source` (always
  `bootstrap/execution-logs.jsonl`), `threshold` (always
  `30`), and an optional `warning` field naming the declared
  floor when `n < 30`. The declared floor in
  `bin/data/time-distribution.yaml` remains the recommended
  reference below that sample size.
- **Exit code**: `0`.
- **Justification**: `bootstrap/time-honesty-storage.yaml`
  obligation `stats-n-threshold`.

### `time-estimate --class C [--count N] [--percentile p50|p80|p95|p99] [--multiplier NAME]...`

- **Synopsis**:
  `mc time-estimate --class C [--count N] [--percentile P] [--multiplier NAME]...`
- **Input**:
  - `--class C` — the task class name from
    `bin/data/time-distribution.yaml`. Required.
  - `--count N` — number of artefacts in scope. Default 1.
  - `--percentile P` — `p50` | `p80` (default) | `p95` | `p99`.
    Estimates between the declared `p50` and `p95` are
    linear-interpolated; `p99` extrapolates beyond `p95`.
  - `--multiplier NAME` — repeatable. One of
    `per_artifact_over_first`,
    `mixed_class_scope`,
    `cross_language_non_ocaml`,
    `test_required_with_runtime`.
- **Output**: a single JSON object on stdout with fields
  (sorted): `applied_multipliers[]`, `caveat`
  ("declared distribution; SWE-bench-V 2025-Q4; update via
  Decision"), `class`, `count`, `estimate_value`, `percentile`,
  `reference` ("SWE-bench Verified (n=500, 2025-Q4)"), `scale`
  (always the declared `unit` from the distribution file,
  typically `minutes`), `source`
  (`bin/data/time-distribution.yaml`). An unknown `--class`
  emits a JSON diagnostic on stderr with fields `class`, `code`
  (= `MC-CLASS-UNKNOWN`), `known_classes[]`, `message`.
- **Exit code**: `0` on success; `2` when `--class` is missing,
  the class is unknown (`MC-CLASS-UNKNOWN`), the multiplier
  is unknown, the percentile token is unrecognised, or the
  YAML cannot be loaded.
- **Justification**: `bootstrap/time-honesty.yaml` (the
  reference-class estimator obligation).

## Context-prioritisation

The `mc context BASE HEAD --budget N` command produces a JSON
capsule of artefacts relevant to evaluating a change. Items in the
capsule are sorted and truncated by the following priority order.
The order is normative; an agent MUST NOT silently reorder or
rebucket items.

```text
RequiredForGate > Changed > HighRisk > Unresolved > Supporting > Historical
```

| Priority | Source class | Inclusion rule |
|---|---|---|
| `RequiredForGate` | bootstrap/decision.yaml; the active policy | Always included if present. The capsule still completes when this is the only item that fits in budget. |
| `Changed` | `git diff BASE..HEAD --name-only`; commit log BASE..HEAD | Included in priority order. Order within the bucket is stable on input order. |
| `HighRisk` | Decisions whose `risk.declared_triggers` is non-empty; axioms/invariants.md | Included when budget allows. |
| `Unresolved` | Assumptions with `state: unknown` | Included when budget allows. |
| `Supporting` | spec/*, OCAML_BEST_PRACTICES.md | Included when budget allows. |
| `Historical` | axioms/* (rarely changed) | Included when budget allows. |

When the budget is exhausted, items are dropped in reverse priority
order. The dropped items appear in the JSON `omitted` array with an
`expansion` command (e.g., `"mc explain decision:Foo"`) so an LLM
agent can fetch the missing context on demand.

The capsule MUST log the byte count under `total_bytes` so the
budget is observable. The `truncated` flag MUST be `true` iff the
`omitted` array is non-empty.

A change to the priority order is itself a protected policy
transition (see above); the table above is the v3-alpha-0.0.7
ordering and may only be revised through the bootstrap gate.

## Kernel Output

For every rule the kernel emits:

- rule identifier;
- subject and exact revision;
- verdict;
- machine-readable reason;
- artifact references;
- remedies when the verdict blocks a gate;
- retryability;
- autofix safety;
- next actions.

Verdicts are reproducible from canonical inputs and the explicit
evaluation time.
