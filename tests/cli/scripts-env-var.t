`scripts/axiom-link-seed.py` and `scripts/counterexample-seed.py` honour
`MATH_CODING_DECISIONS_DIR` (with `MATH_CODING_ROOT` overriding the
script's default `<scripts>/..`). Pre-fix the scripts hard-coded
`<scripts>/../decisions/` at the top of each file (lines 63-65 and 75
respectively), silently mutating the host checkout even when a user
routed their tree to `.math-coding/decisions/` via env-var.

The fix routes the path lookup through `repo_root()` /
`decisions_dir()` helpers that mirror the precedence
`scripts/generate-attestations.py` (F11-A4 reference impl): env > default.
The kernel additionally considers the new `.math-coding/` default
discovered on disk (`lib/path_config.ml::resolve_decisions_dir`),
but the Python scripts have no `mathc init` integration so they honour
`env > repo/default` only.

Setup: isolated project at `$tmp` with a `dune-project` so
`MATH_CODING_ROOT` is a valid project root, and one synthesised
decision in `.math-coding/decisions/`. Both env vars are exported so
the scripts under test write to `.math-coding/decisions/`, not the
legacy `decisions/` path.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ echo '(lang dune 3.0)' > "$tmp/dune-project"
  $ mkdir -p "$tmp/.math-coding/decisions"
  $ cat > "$tmp/.math-coding/decisions/scripts-env-var-probe-2026-11.yaml" <<'YAML'
  > schema: math-coding/3.3
  > id: scripts-env-var-probe-2026-11
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Probe decision for tests/cli/scripts-env-var.t; the script
  >   under test appends `axiom_link:` to it.
  > commitment: |
  >   The probe carries `axiom_link: [A0]` after the sweep.
  > outcomes:
  >   - id: env-var-routing
  >     statement: |
  >       scripts/axiom-link-seed.py reads
  >       `MATH_CODING_DECISIONS_DIR` (and `MATH_CODING_ROOT`)
  >       and writes to that path.
  > obligations:
  >   - id: probes-env-var
  >     claim: |
  >       The probe is consumed by the cram fixture.
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/scripts-env-var.t
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > YAML
  $ export MATH_CODING_ROOT="$tmp"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"

`scripts/axiom-link-seed.py` with env-var routes its I/O to
`<root>/.math-coding/decisions/`. The probe decision gains an
`axiom_link:` block. The legacy `<root>/decisions/` is never
created.

  $ python3 "$DUNE_SOURCEROOT/scripts/axiom-link-seed.py" 2>&1 | grep -E "axiom-link-seed|axiom_link added|SKIP-"
  axiom-link-seed: 1 files
    OK (axiom_link added):            1
    SKIP-PRESENT (idempotent):        0
    SKIP-RETIRED (state != active):   0
    SKIP-META:                        0
  $ grep -c '^axiom_link:' "$tmp/.math-coding/decisions/scripts-env-var-probe-2026-11.yaml"
  1
  $ test ! -d "$tmp/decisions" && echo "no legacy decisions/: ok"
  no legacy decisions/: ok

Idempotency: re-running with the same env-var produces zero
`OK (axiom_link added)` changes (everything is `SKIP-PRESENT`).
The script's top-of-file constants are resolved once at module
import; env-var changes between runs do NOT take effect
(`os.environ` is captured by the top-level `repo_root()` /
`decisions_dir()` calls). This is acceptable: the env-var is
process-level, and a fresh `python3` invocation per
subprocess preserves the same env state.

  $ python3 "$DUNE_SOURCEROOT/scripts/axiom-link-seed.py" 2>&1 | grep -E "axiom_link added|SKIP-"
    OK (axiom_link added):            0
    SKIP-PRESENT (idempotent):        1
    SKIP-RETIRED (state != active):   0
    SKIP-META:                        0

`scripts/counterexample-seed.py` with env-var routes its I/O to
`<root>/.math-coding/decisions/`. Swap the probe for a decision
whose id is in the script's `ONE_LINERS` table
(`3-2-cli-catalog`), confirm the sweep applies on the first
run and is SKIP-PRESENT on the second, and verify the legacy
`decisions/` is never created.

  $ mv "$tmp/.math-coding/decisions/scripts-env-var-probe-2026-11.yaml" \
  >    "$tmp/.math-coding/decisions/3-2-cli-catalog.yaml"
  $ sed -i 's/id: scripts-env-var-probe-2026-11/id: 3-2-cli-catalog/' \
  >    "$tmp/.math-coding/decisions/3-2-cli-catalog.yaml"
  $ python3 "$DUNE_SOURCEROOT/scripts/counterexample-seed.py" 2>&1 | grep -E "sweep applied|SKIP-PRESENT|NO-LOOKUP"
    OK (sweep applied):                  1
    SKIP-PRESENT (idempotent re-run):    0
    NO-LOOKUP (extend table!):           0
  $ grep -c '^counterexample:' "$tmp/.math-coding/decisions/3-2-cli-catalog.yaml"
  1
  $ python3 "$DUNE_SOURCEROOT/scripts/counterexample-seed.py" 2>&1 | grep -E "sweep applied|SKIP-PRESENT|NO-LOOKUP"
    OK (sweep applied):                  0
    SKIP-PRESENT (idempotent re-run):    1
    NO-LOOKUP (extend table!):           0
  $ test ! -d "$tmp/decisions" && echo "no legacy decisions/: ok"
  no legacy decisions/: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
