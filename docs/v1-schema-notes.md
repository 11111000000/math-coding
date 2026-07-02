# Migrating from math-coding v1 to v2

This document is a field guide for projects that adopted
math-coding v1 (lived in `~/Desktop/math-coding-new/`) and want
to move to v2 (this repository, v2.0.0+). The full rationale
for every change is in `CHANGELOG.md`; here we focus on
**mechanical migration steps**.

## What changed between v1 and v2

The structural invariants and packet lifecycle are the same.
v2 adds provenance and an action protocol on top of v1. The
mechanical delta for any existing v1 packet is:

| File | v1 | v2 | Action |
|------|----|----|--------|
| `packet.json` | JSON manifest | replaced by `packet.yaml` | convert, rename |
| `problem.md` | one section | replaced by `task.md` with three sections | rename, split into `## Problem` / `## Desired outcome` / `## Constraints` |
| `assumptions.yaml` | 4 entries without epistemics | 4+ entries with `epistemology` field | add `epistemology` to each entry |
| `Model.tla` | optional | unchanged | none |
| `verify.sh` | optional | unchanged | none |
| `verifier-output.yaml` | absent | required for `lifecycle: verified` | create from verifier log |
| `refinement.md` | absent | recommended | create from existing code comments |
| `traceability.json` | absent | recommended | create from existing code links |

## Mechanical conversion script (sketch)

A v1 packet directory looks like:

```
my-feature/
├── packet.json
├── problem.md
├── assumptions.yaml
└── Model.tla
```

After migration it should look like:

```
my-feature/
├── packet.yaml
├── task.md
├── assumptions.yaml
├── refinement.md
├── traceability.json
├── verifier-output.yaml
├── Model.tla
└── verify.sh
```

Suggested migration sequence (one packet at a time):

1. `mv packet.json packet.yaml` and convert JSON to YAML.
   Both are line-for-line equivalent for the manifest fields.
2. Rename `problem.md` → `task.md` and add the three section
   headers. Each section must contain at least 10 words or the
   verifier reports `task-md-has-content` as a violation.
3. In `assumptions.yaml`, add `epistemology: <marker>` to every
   entry. Pick `fact` if you can point to a source, `hypothesis`
   if it is an inference, `judgment` if it is a design decision,
   `unknown` if it is an open question. See
   `core/01-Theory/07-Epistemic.md` for the action protocol.
4. Run the structural verifier:

   ```sh
   sh examples/self-application/verify-consistency.sh
   ```

   The verifier lists every missing field and every section that
   fails the 10-word threshold. Fix and re-run until `OK`.
5. If the packet was previously "done" in v1, decide what
   verdict to assign in v2. Five options are listed in
   `core/01-Theory/06-Verdict.md`. The convention does not
   silently promote v1-`done` to v2-`VERIFIED`; you must
   record the verdict with provenance.
6. Add `verified_at`, `scope`, `tool`, `evidence` to the verdict
   record. Without these, `verified-requires-verification-output-fields`
   fails.

## What v2 does not change

- The five-state FSM (`sketch → working → verified → deprecated → archived`).
  See `core/core.md` §State machine.
- The four epistemic markers. See
  `core/01-Theory/07-Epistemic.md`.
- The principle that a packet is a directory with the same
  required files. v2 only **adds** provenance and a recommended
  refinement map; it does not move any required file.

## Common migration pitfalls

1. **Treating `lifecycle: verified` as self-explanatory.** v2
   requires `verifier-output.yaml.verdict == VERIFIED`. A v1
   packet marked verified without a verdict record will fail
   the `verified-requires-verdict` check.
2. **Forgetting the section word count.** v1 did not check
   section length. v2 enforces 10 words per section in
   `## Problem`, `## Desired outcome`, `## Constraints`.
3. **Putting epistemics as plain comments.** The action
   protocol lives in `agents/agents.md`; the YAML field is
   `epistemology:` with one of the four enum values.
4. **Ignoring ADR changes.** The convention went from 6 ADRs
   to 10. The four new ones (0007-theory-as-foundation,
   0008-epistemic-protocol, 0009-extended-packet-fields,
   0010-extended-fsm-triggers) are normative in v2.

## Force-TLA+ edition

If you adopted the Force-TLA+ edition that lived in
`~/Desktop/MathCodingFractal/` (also published as
`11111000000/math-coding-force-tla`), the migration path is
the same as v1, with one extra step: every packet must keep
its `Model.tla` or downgrade its lifecycle to `sketch`. v2
makes TLA+ optional; the Force-TLA+ edition made it mandatory.

## See also

- `CHANGELOG.md` for the full list of additions.
- `core/core.md` for the v2 convention source of truth.
- `core/01-Theory/` for the eight theory documents that ground
  every rule.