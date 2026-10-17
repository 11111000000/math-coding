# Per-task descriptions for sub-agents

> One section per (project, task) pair. The orchestrator substitutes
> the matching section into each sub-agent's prompt.

---

## click / T1 — bootstrap documentation

Goal: make the first decision on this project. Pick a commitment
that already exists implicitly in the project and formalise it.

Suggested commitment: *"click supports the Python versions listed in
`setup.cfg` classifiers."* Verify the claim by reading
`setup.cfg` / `pyproject.toml` classifiers; quote the actual version
range in the decision's `commitment:` field.

Procedure:

1. `cd /home/az/Projects/math-coding-experiment/click`
2. `mkdir -p .math-coding/decisions .math-coding/attestations`
3. `MATH_CODING_DECISIONS_DIR=.math-coding/decisions
    MATH_CODING_ATTESTATIONS_DIR=.math-coding/attestations
    /home/az/.local/bin/mathc new-decision python-version-support-2026-10
    --template=minimal --write`
4. Fill in `intent:`, `commitment:`, `counterexample:`, `outcomes:`,
   `scope.paths:`, `obligations[].acceptance:`. The `acceptance`
   should reference a real verifiable path, e.g.
   `tests/cli/python-version-classifiers.t` — but since click uses
   pytest, also acceptable: `acceptance.verifier: tests/python-version
   exists and asserts the classifier list`.
5. `mathc validate` until accept.
6. `mathc self-check` — expect verdict `unknown`.
7. Fill the report section.

## click / T2 — small change

Make a real small change in `click/__init__.py` (or wherever fits),
documented as a decision. The change must be visible in the repo
(e.g. fix a typo in a docstring; correct a deprecated import; add a
`__all__` entry). After the change:

1. `mathc new-decision <change-id> --template=minimal --write`
2. Add an obligation whose verifier references a real file: e.g.
   `acceptance.verifier: tests/cli/<change-id>.t` — write a one-line
   test that asserts the change.
3. Generate the attestation:
   `mathc attest-batch --from=.math-coding/decisions --kind=review
   --producer=human:opencode-agent`
4. `mathc self-check` — the new decision should transition from
   `unknown` to `pass` (or stay `unknown` if any obligation is
   uncovered).
5. Fill the report.

## click / T3 — lifecycle

Write a `decisions/waivers/<id>.yaml` requesting an exception on a
non-blocking nit (find one by grep — a stale `# TODO` that has been
there for years, or a deprecated doc URL that can't be fixed without
breaking docs build). Run it through `mathc validate`. Note that
`mathc validate` should accept a waiver decision only if it has
`expires_at:` — see existing waiver decisions under
`/home/az/Projects/math-coding/decisions/waivers/` for the schema.

Fill the report.

---

## express / T1 — bootstrap documentation

Suggested commitment: *"express follows semantic versioning; the
current major version (4.x) signals breaking changes in the public
API."* Verify by reading `package.json` `"version"` field.

Procedure: same shape as click / T1. Decision id:
`semver-policy-2026-10`.

## express / T2 — small change

Make a small change to `lib/express.js` or `index.js`. Example:
correct a JSDoc typo in one exported function. Document as decision
`jsdoc-typo-<short-id>-2026-10` with an obligation that the change
landed (verifier: `tests/cli/jsdoc-typo-<short-id>.t` — write a
golden test).

Note: express has 91 Mocha test files; the sub-agent should *not*
attempt to run the full test suite. The obligation only needs to
verify the changed file's content. If a test can't run, use
`acceptance.verifier: file-contains <path> <needle>` style.

## express / T3 — lifecycle

Pick an existing docs/CHANGELOG entry and write a decision
`changelog-policy-2026-10` that documents the maintenance
convention. State-transition it through `mathc decision-state` (read
`mathc decision-state --help` first). Fill the report.

---

## cobra / T1 — bootstrap documentation

Suggested commitment: *"cobra supports the Go versions listed in
`go.mod`'s `go` directive."* Verify by reading `go.mod`.

Decision id: `go-version-support-2026-10`.

## cobra / T2 — small change

Add a missing GoDoc to one exported function in `cobra/cmd.go` or
similar (find an exported function whose comment starts with the
function name on the same line — Go convention). Document as
decision `godoctidy-<func>-2026-10`. Obligation: file contains the
godoc.

## cobra / T3 — lifecycle

Write a `migrations/<from>-to-<to>.yaml` migration plan (read
`/home/az/Projects/math-coding/decisions/migration-mechanism-2026-10.yaml`
or similar for the schema). Don't execute it — just produce the
plan. Fill the report.

---

## ripgrep / T1 — bootstrap documentation

Suggested commitment: *"PCRE2 is a build-time optional feature gated
by `--features pcre2`."* Verify by reading `Cargo.toml` `[features]`
and `README.md` build instructions.

Decision id: `pcre2-feature-flag-2026-10`.

## ripgrep / T2 — small change

Fix a doc typo in `README.md`. Document as decision
`readme-typo-<short>-2026-10` with an obligation that the typo is
gone. The verifier can be `acceptance.verifier: file-contains
README.md <new-string>`.

## ripgrep / T3 — lifecycle

Write a decision `feature-flag-policy-2026-10` documenting how
optional features are gated. Then mark one of its obligations
as `waived` via `decisions/waivers/<id>.yaml` to exercise the
waiver path.

---

## sinatra / T1 — bootstrap documentation

Suggested commitment: *"sinatra follows semantic versioning; the
public API is stable across minor versions."* Verify by reading
`CHANGELOG.md` and `VERSION` files.

Decision id: `semver-policy-2026-10`.

## sinatra / T2 — small change

Fix a doc typo in `README.md`. Document as decision
`readme-typo-<short>-2026-10`.

## sinatra / T3 — lifecycle

Run `mathc re-evaluate` on a recent decision and report the output.
The re-evaluate command is read-only; it just produces verdicts.

---

## Control arm (orchestrator executes inline)

The orchestrator (this agent) runs *one* of T1/T2/T3 *without*
math-coding on each project, recording the same metrics. The
choice of which T rotates:

- **click**: T1-control (formalise a commitment as plain Markdown
  in CONTRIBUTING.md instead of a math-coding decision)
- **express**: T2-control (fix the same docstring typo without
  writing a decision)
- **cobra**: T3-control (write the migration plan as plain YAML,
  no decision file)
- **ripgrep**: T1-control (document the PCRE2 feature flag in
  README.md as a paragraph)
- **sinatra**: T2-control (fix the same README typo without math-c)

Wall-clock is recorded. No `decisions/*.yaml` are written.
`experiment-report.md` for each project gets a "Control arm"
section appended.