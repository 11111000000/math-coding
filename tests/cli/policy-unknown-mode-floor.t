A `mode_floor` the kernel cannot read must be NAMED, not silently
downgraded.

WHAT IT DID. `lib/policy.ml::parse_policy` read `mode_floor` and, when
`Codec.parse_mode` did not know the word, used `tiny` - the cheapest
rung of the ladder - without a word to anyone. An operator who wrote
`mode_floor: pci-strict` got the silent baseline instead of their floor, and the only trace was
a promise the kernel did not keep. The vocabulary the dead helper
`mode_floor_of_string` had parsed (silent, baseline, pci-strict,
axiom-touching) was not the vocabulary the kernel uses at all
(tiny, light, standard, strict, exhaustive), and the helper had no
callers: so the one place that could have said "I do not know this
word" said nothing.

WHAT IT DOES NOW. The policy is DROPPED - its floor does not apply -
and the error names the policy, the value and the words the kernel
reads. The record the kernel could not understand is not the same
defect as a record whose shape it did not recognise: the second is
still dropped silently, because a malformed entry and an entry the
kernel read and rejected are different things, and only the second
one can name the value that is wrong.

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
  >   mode_floor: pci-strict
  >   override_probability: 0.0
  >   obligations: []
  >   transitive_into: []
  >   data_flow_edges: []
  > YAML

The error names the value and the vocabulary, on stderr, where the
operator's build log will show it.

  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>&1 >/dev/null | grep -o 'MC-POLICY-UNKNOWN-MODE-FLOOR.*'
  MC-POLICY-UNKNOWN-MODE-FLOOR: policy floor-fixture: unknown mode_floor "pci-strict" (the kernel reads one of: tiny, light, standard, strict, exhaustive)

The floor the kernel cannot honour does not apply: the answer is the
baseline, and the answer is the baseline WITH the error above it, not
instead of it.

  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>/dev/null | jq -c '{mode}'
  {"mode":"tiny"}

A word the kernel DOES read is honoured, with no error at all - the
error is about the value, not about having a policy.

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
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>&1 >/dev/null | grep -c MC-POLICY-UNKNOWN-MODE-FLOOR || true
  0
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>/dev/null | jq -c '{mode}'
  {"mode":"standard"}

The absence of a policies file is not an error either: a project that
declared no floors is a project the kernel reads as the silent
baseline.

  $ rm policies.yaml
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>&1 >/dev/null | grep -c MC-POLICY-UNKNOWN-MODE-FLOOR || true
  0
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>/dev/null | jq -c '{mode}'
  {"mode":"tiny"}

THE NEGATIVE CONTROL, and it is the direction that matters: a floor
the kernel READS must not be named as a floor it does not. If the
kernel ever started reporting a known floor as unknown, the check
below would find the error where there is none - and this case fails.

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
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/gate.ml 2>&1 >/dev/null | grep -q MC-POLICY-UNKNOWN-MODE-FLOOR; echo "exit=$?"
  exit=1
