# Release audit — math-coding 3.0-alpha-0.0.19

> Author: subagent on behalf of Petr Kosov <p.b.kosov@yandex.ru>
> Branch: main, HEAD `v3.0.0.19-alpha` (after this commit)
> Date: 2026-09-29
> Status: release-time audit. Closes deficits **D1** (YAML `|`
> block scalars) and **D2** (YAML front-matter) from
> `doc/AUDIT-0.0.11.md`. The implementation lands in
> `lib/codec.ml`; the kernel tests live in
> `tests/yaml_block_scalars.ml`; the conformance fixtures live
> in `fixtures/conformance/decision/positive-block-scalars.yaml`
> and `negative-block-scalars.yaml`.

## Summary of the release

This release closes D1 and D2. The kernel can now parse:

- `|` (literal) with default clip chomping
- `|-` (literal) with strip chomping
- `|+` (literal) with keep chomping
- `>` (folded) with default clip chomping
- `>-` (folded) with strip chomping
- `>+` (folded) with keep chomping

at any nesting level (top-level mapping, nested mapping,
inside a sequence item).

`lib/codec.ml:load_yaml_string` strips a leading YAML
front-matter (`---` line) before parsing, so decision files
that begin with `---` (every file under `decisions/`) now
parse to the full JSON value tree. Previously, the front-matter
left the parser with an empty object — the kernel returned
`{}` for every `decisions/*.yaml`.

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
v0.0.18         release consolidation (convention layer)
v0.0.19         audit D1 + D2 (YAML block scalars + front-matter)
```

### What v0.0.19 closes

- **D1** (YAML `|` block scalars) — closed. The kernel's
  `load_yaml_string` now recognises `|` and `>` headers and
  applies the canonical reading rules (literal preserves
  newlines; folded joins adjacent non-empty lines with
  spaces; clip / strip / keep honour the chomping indicator).

- **D2** (YAML `---` front-matter) — closed. `load_yaml_string`
  drops a leading `---` (and a closing `---` if present)
  before tokenisation. Decision files that begin with `---`
  now parse to the full JSON tree.

### Still open from v0.0.11 (carried forward)

- **D4** — SHA-256 RFC 6234 vectors. The hand-rolled SHA-256
  in `lib/digest.ml` has not been validated. The test
  `tests/digest_vectors.ml` exists with the vectors but is
  `xfail until Digest is fixed`. The fix is the top-priority
  open kernel work after v0.0.19; it cannot be closed by a
  documentation-only release. v0.0.19 explicitly does NOT
  touch this.
- **D6** — manual-only verifiers. The 13 obligations in
  `decisions/decision.yaml@2` have manual-only verifiers
  because the kernel that would auto-verify them does not
  exist. The convention is itself an obligation (winner-1 in
  v0.0.18 records this). D6 expires when the 3.0 kernel
  successfully checks this repository
  (`AGENTS.md §Bootstrap gate`).
- **D8** — coarse `mathc validate` diagnostic. The kernel
  synthesises "missing or invalid required field" without
  naming the field. Fix is to promote `Decision.parse_decision`
  to return `Diagnostic.t option` (3.0-beta work).

### Closed previously (recap)

For completeness, the audit debts closed at v0.0.10–v0.0.18
are: D5 (stale mathc_main.ml), D7 (adapters covers both git
and junit), D3 (priority-drift detector), D4′ (result/ in
.gitignore), D1, D2.

## Implementation notes (for the next reviewer)

### Why a hand-rolled parser, not `yaml`/`ocaml-yaml`

The kernel must remain offline and side-effect-free
(`OCAML_BEST_PRACTICES §1.3, §7.3`). Adding a real YAML library
would drag in transitive packages and break the reproducibility
guarantee. The hand-rolled subset loader is sufficient for the
decisions files and stays tiny (~150 lines added to
`lib/codec.ml`).

### Why conformance runner now delegates to `Codec.load_yaml_string`

In v0.0.18, `tests/conformance.ml` carried its own duplicate
of `yaml_tokens`, `parse_yaml_pairs`, `parse_yaml_seq`. That
duplication was acceptable when all fixtures used inline
scalar YAML. With v0.0.19 fixtures using block scalars, the
duplication would diverge (one parser knows block scalars,
the other does not). The fix: `tests/conformance.ml:parse_yaml_file`
now delegates to `Codec.load_yaml_string`. The hand-rolled
`yaml_*` helpers in `tests/conformance.ml` remain — they are
used by the `walk_decision_yaml` walker to inspect token
streams that the kernel strips (e.g. front-matter).
Documented in `OCAML_BEST_PRACTICES §11.1` (trap log).

### Chomping semantics (YAML 1.2)

The variant `chomp` is named `Clip`/`Strip`/`Keep`, not
`Plain`/`Strip`/`Keep`. The default (`|` and `>` with no
chomping indicator) is **Clip** in the YAML spec — it clips
the trailing newlines to exactly one. Using `Plain` would
clash with the YAML spec naming. See
`OCAML_BEST_PRACTICES §11.2`.

### Body indent (`>=` not `>`)

The block-scalar body collector uses `yindent >= body_indent`,
not `yindent > body_indent`. The header line's value (e.g.
`greeting: |`) sets the parent indent; body lines typically
appear at exactly `parent_indent + 2`. Using `>` instead of
`>=` collects nothing and produces an empty string. This was
the root cause of the v0.0.19 `literal simple` test failure.
See `OCAML_BEST_PRACTICES §11.3`.

### Backward compatibility

All thirteen conformance fixtures (eleven from v0.0.18 plus
two new) parse via `Codec.load_yaml_string` to the same
`Jsonl.value` they would have parsed to in v0.0.18. The
kernel-conformance suite (`tests/conformance.exe`) reports
`Accept` for every existing fixture; this is the strongest
evidence we have that the change is additive.

### OCaml 5.x regex trap

`Str.regexp` does not handle multi-line patterns the way PCRE
does (`.` does not match `\n`; `[^\n]` negation does not
behave as documented inside a repetition group). The fix in
`tests/repo_structure.ml:test_enumerate` is to use substring +
position checks instead of regex. Documented in
`OCAML_BEST_PRACTICES §11.1`.

## Verification

Run `./scripts/check.sh` to aggregate shell fixtures and
cram tests. Run
`nix develop .#test --command bash -c 'dune test --root .'`
to run the OCaml/Alcotest suite. The expected counts:

- `tests/conformance.exe`: 13 cases (was 11 at v0.0.18)
- `tests/yaml_block_scalars.exe`: 7 cases (new)
- `tests/repo_structure.exe`: 11 cases (unchanged from v0.0.18)
- `tests/process_principles.exe`: 5 cases (unchanged)
- `tests/digest_vectors.exe`: xfail (unchanged, awaits D4)
- cram tests: 15 files (unchanged)

Total passing tests: 36 + 15 cram = 51.

## What v0.0.19 did NOT do

- No `tests/digest_vectors.ml` fix (D4). Out of scope; D4 is
  the next kernel task after v0.0.19.
- No new runtime dependency. `flake.nix` is unchanged from
  v0.0.18.
- No schema change. `schemas/*.json` is unchanged.
- No decision parser change. `Decision.parse_decision` is
  unchanged from v0.0.18.
- No `mathc explain` (Tier-4).

## See also

- `AGENTS.md` — agent conduct (defer to this file for
  priorities; P3 time-box on detailed work was honoured).
- `OCAML_BEST_PRACTICES.md §11` — trap log entries added in
  v0.0.19.
- `decisions/yaml-block-scalars.yaml@3` — the closing
  decision (supersedes yaml-block-scalars.yaml@2 and
  yaml-block-scalars-impl-pending.yaml@1).
- `doc/AUDIT-0.0.11.md` — the original deficit chain.
- `doc/AUDIT-0.0.18.md` — the previous release audit.
