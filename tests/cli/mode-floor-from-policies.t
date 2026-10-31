The `mode_floor` a project declares in `policies.yaml` is READ BY
THE KERNEL.

The claim is not about a file being present. It is about the file
CHANGING WHAT THE KERNEL ANSWERS. `mathc mode PATH` prints the
effective mode of a change, and the effective mode is
`max(risk_to_mode(risk(c)), mode_floor(c))` (spec/kernel-contract.md §2).
The second term comes from `policies.yaml`. If the kernel does not
read that file, the second term is always `tiny`, every change in the
repository is classified as the silent baseline, and the friction
ladder has exactly one rung.

IT DID NOT READ IT. The resolver that answered "where are the
policies" named `.math-coding/policy.yaml` and `decisions/decision.yaml`
-- both of which are DECISION documents, not policy sequences. Parsing
either as a sequence of policy records yields an empty list, the
policy cache stayed empty, and the floors were dead. The symptom was
visible in one command: `mathc mode lib/gate.ml` answered `tiny` for
a path whose policy said `standard`.

The fixture pins BOTH directions, because a resolver that finds the
file and a resolver that ignores it are the same code path read
differently, and only the second one is the defect:

with the file    the declared floor is the answer;
without it       the answer is the silent baseline, and the file's
absence is not a crash.

MATH_CODING_POLICIES and MATH_CODING_POLICY are unset so the fixture
reads the default location (`policies.yaml` at the project root) and
not an operator's override.

  $ cd "$DUNE_SOURCEROOT"
  $ unset MATH_CODING_POLICIES
  $ unset MATH_CODING_POLICY
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ touch dune-project
  $ cat > policies.yaml <<'YAML'
  > - policy_id: floor-fixture
  >   scope_paths:
  >     - "lib/**"
  >   mode_floor: standard
  >   override_probability: 0.0
  >   obligations: []
  >   transitive_into: []
  >   data_flow_edges: []
  > YAML
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml | jq -c '{mode}'
  {"mode":"standard"}

The floor is per PATH, not per file: a path the policy does not name
keeps the baseline.

  $ $INSIDE_DUNE/bin/mathc.exe mode docs/readme.md | jq -c '{mode}'
  {"mode":"tiny"}

The `policies:` WRAPPER is the same document as a bare sequence. The
shape in the wild is not one shape, and a resolver that reads only one
of them answers "the project declared no floors" for the other.

  $ cat > policies.yaml <<'YAML'
  > policies:
  >   - policy_id: floor-fixture
  >     scope_paths:
  >       - "lib/**"
  >     mode_floor: standard
  >     override_probability: 0.0
  >     obligations: []
  >     transitive_into: []
  >     data_flow_edges: []
  > YAML
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml | jq -c '{mode}'
  {"mode":"standard"}

Without the file the answer is the silent baseline, and the absence
is not a crash (kernel contract §9: `policy(p) = default-policy`).

  $ rm policies.yaml
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml | jq -c '{mode}'
  {"mode":"tiny"}
  $ cd /
  $ rm -rf "$tmp"
