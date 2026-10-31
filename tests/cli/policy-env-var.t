mathc --dispatch honours MATH_CODING_POLICY: the startup
`Policy.load_policies ~path` call at bin/Mathc.ml:6708 now
composes the project root with `Path_config.resolve_policy_path
()` instead of the hardcoded `policies.yaml`. Per F10 fix #7 in
decisions/path-resolver-audit-2026-11.yaml the precedence is
env > `.math-coding/policy.yaml` > legacy `decisions/decision.yaml`.

Setup: a tmpdir project. Export MATH_CODING_POLICY to point at
a sentinel file under the sandbox. MATH_CODING_ROOT pins
find_project_root. Without our fix the dispatcher reads
`policies.yaml` only (silently ignoring the env var), so
setting MATH_CODING_POLICY is a no-op. With our fix the
resolver returns the env value and the dispatcher wires it
into `Policy.load_policies`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cp dune-project "$tmpdir/"
  $ mkdir -p "$tmpdir/decisions"
  $ cat > "$tmpdir/custom-policy.yaml" <<'YAML'
  > policies:
  >   - policy_id: env-var-policy-fixture
  >     scope_paths:
  >       - "tests/**"
  >     mode_floor: light
  >     override_probability: 0.0
  > YAML
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_POLICY="$tmpdir/custom-policy.yaml"

The dispatcher's startup load is silent; the kernel contract
under test is "the file at the env-var path is honoured
without crashing". `mathc self-check` exercises the full
kernel stack (walking decisions/, applying policies through
risk.modes, etc.). With an isolated tmpdir that has zero
decisions the verdict is `unknown` and the subject list is
empty -- but the call exits 0 (no kernel crash, dispatcher
load_policies completes silently per the kernel contract §9 no-policy
declaration default).

  $ $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '{subjects: (.subjects | length), verdict}'
  {"subjects":0,"verdict":"unknown"}

When MATH_CODING_POLICY points at a non-existent file the
dispatcher falls through to the resolver's disk-check (no
crash); the kernel still exits 0 (the `load_policies` call is
explicitly a no-op when the file is absent per kernel contract §9
`policy(p) = default-policy`).

  $ export MATH_CODING_POLICY="/nonexistent/policy.yaml"
  $ $INSIDE_DUNE/bin/mathc.exe self-check | jq -c '{subjects: (.subjects | length), verdict}'
  {"subjects":0,"verdict":"unknown"}

Cleanup.

  $ cd /
  $ unset MATH_CODING_POLICY
  $ rm -rf "$tmpdir"
