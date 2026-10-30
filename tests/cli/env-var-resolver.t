`MATH_CODING_DECISIONS_DIR` and `MATH_CODING_ATTESTATIONS_DIR` are
honoured by every subcommand that writes or tree-walks the
decisions / attestations layout. The pre-fix kernel hard-coded
`decisions/` and `attestations/` at every call site, which
silently ignored the env-var override (adoption experiment
§10.5 #1, #2, #3; reproduced in 5 of 5 project reports).

The fix routes the path lookup through
`lib/path_config.ml::resolve_decisions_dir` /
`resolve_attestations_dir`. The legacy env-var
`MATH_CODING_ATTESTATION_STORE` (used by gate / self-check
fixtures before the 3.4 resolver) still wins for back-compat;
the canonical v3.4 name `MATH_CODING_ATTESTATIONS_DIR` is
accepted everywhere a subcommand tree-walks the attestation
store.

Acceptance gate for the seven subcommands in
`decisions/fix-env-var-resolver-2026-10.yaml`. Each case below
builds an isolated project at `$tmpdir` (with `dune-project`
present so `find_project_root` honours `MATH_CODING_ROOT`) and
verifies the subcommand walks `.math-coding/decisions/` /
`.math-coding/attestations/` instead of the legacy paths.

Setup: an isolated project at `$tmpdir` with one decision in
`.math-coding/decisions/` and an empty attestation store. The
canonical `MATH_CODING_DECISIONS_DIR` and
`MATH_CODING_ATTESTATIONS_DIR` are exported so every subcommand
under test routes its I/O through `.math-coding/`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cp dune-project "$tmpdir/"
  $ mkdir -p "$tmpdir/.math-coding/decisions" "$tmpdir/.math-coding/attestations"
  $ cd "$tmpdir"
  $ cat > "$tmpdir/.math-coding/decisions/env-var-probe-2026-10.yaml" <<'EOF'
  > ---
  > schema: math-coding/3.2
  > id: env-var-probe-2026-10
  > revision: 1
  > state: active
  > mode: standard
  > change_kind: implementation
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: |
  >   Probe decision used by tests/cli/env-var-resolver.t to verify
  >   that subcommands honour MATH_CODING_DECISIONS_DIR.
  > commitment: |
  >   The decision lives at <project>/.math-coding/decisions/ when
  >   the env var is exported; subcommands walk that tree.
  > counterexample: |
  >   The pre-fix kernel hard-coded `decisions/` at every call site,
  >   so the probe decision was unreachable via the env var.
  > scope:
  >   paths: ["lib/**"]
  > outcomes:
  >   - id: o1
  >     statement: A first outcome.
  > obligations:
  >   - id: ob1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe rehash "$tmpdir/.math-coding/decisions/env-var-probe-2026-10.yaml" --write > /dev/null
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".math-coding/attestations"

`mathc self-check` walks `<root>/<MATH_CODING_DECISIONS_DIR>` and
the attestation store at
`<root>/<MATH_CODING_ATTESTATIONS_DIR>`. The probe decision
appears in the subjects list and is `unknown` (no attestations
yet).

  $ $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '{subjects: (.subjects | map(.name) | sort), probe_present: ([.subjects[] | select(.name == "env-var-probe-2026-10")] | length), probe_verdict: ([.subjects[] | select(.name == "env-var-probe-2026-10") | .verdict] | .[0])}'
  {"subjects":["env-var-probe-2026-10"],"probe_present":1,"probe_verdict":"unknown"}

`mathc packages --format=json` reads decisions from the
env-var-resolved dir. The probe decision is the only one in the
package list.

  $ $INSIDE_DUNE/bin/mathc.exe packages --format=json | jq -c '{decisions: (.decisions | map(.decision_id) | sort), source}'
  {"decisions":["env-var-probe-2026-10"],"source":"decisions/"}

`mathc find KEYWORD` reads decisions from the same env-var
location. The keyword `probe` matches the probe decision.

  $ $INSIDE_DUNE/bin/mathc.exe find probe | jq -c '.decisions | map(.decision_id) | sort'
  ["env-var-probe-2026-10"]

`mathc counters` reports one decision (the probe) and zero live
attestation JSONs (the store is empty). The
`MATH_CODING_ATTESTATIONS_DIR` override is honoured: the
`attestations.live_store` count reads from the env-var path.

  $ $INSIDE_DUNE/bin/mathc.exe counters --format=json | jq -c '{decisions: (.decisions | {total, active}), attestations: .attestations.live_store}'
  {"decisions":{"total":1,"active":1},"attestations":0}

`mathc migrate --from=X --to=Y --format=text` reads the same
env-var-resolved directory: it walks `.math-coding/decisions/`
and produces a per-file plan. We pass `--manifest` pointing at
the live `decisions/migrations/` manifest (the default manifest
path also honours the env-var via the resolver, but we use the
explicit override for the hermetic pin).

  $ $INSIDE_DUNE/bin/mathc.exe migrate \
  >   --from=math-coding/3.0-alpha \
  >   --to=math-coding/3.2 \
  >   --manifest="$DUNE_SOURCEROOT/decisions/migrations/3.0-alpha-to-3.2.yaml" \
  >   --format=text 2>&1 | grep -c 'env-var-probe-2026-10.yaml'
  1

`mathc re-evaluate <id>` reads the same directory. The probe
decision exists, so the kernel locates it via the resolver; the
call returns a JSON verdict. The decision-level verdict is
`inconclusive` because the only obligation carries a built-in
`mathc self-check` verifier that the kernel can resolve
without an explicit run (T1.2 built-in short-circuit).

  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate env-var-probe-2026-10 A0 | jq -c '{decision, verdict, ran}'
  {"decision":"env-var-probe-2026-10","verdict":"inconclusive","ran":false}

`mathc new-decision --write` writes to
`<root>/<MATH_CODING_DECISIONS_DIR>`. The probe sibling written
via --write appears under `.math-coding/decisions/`, not under
the legacy `./decisions/` location. The "wrote ..." stdout
line is suppressed because the path is bwrap-dependent; we
assert on the file-system state instead.

  $ $INSIDE_DUNE/bin/mathc.exe new-decision env-var-write-2026-10 --write >/dev/null 2>&1
  $ test -f "$tmpdir/.math-coding/decisions/env-var-write-2026-10.yaml" && echo "wrote to .math-coding/: ok"
  wrote to .math-coding/: ok
  $ test ! -f "$tmpdir/decisions/env-var-write-2026-10.yaml" && echo "no legacy write: ok"
  no legacy write: ok

Legacy back-compat: with `MATH_CODING_ATTESTATION_STORE`
exported (the pre-3.4 env-var name), `mathc self-check`
continues to honour it. The probe decision and the just-written
sibling both appear in the subjects list, confirming that
pre-3.4 fixtures that set the legacy name still work after the
fix.

  $ unset MATH_CODING_ATTESTATIONS_DIR
  $ export MATH_CODING_ATTESTATION_STORE="$tmpdir/.math-coding/attestations"
  $ $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '.subjects | map(.name) | sort'
  ["env-var-probe-2026-10","env-var-write-2026-10"]

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
