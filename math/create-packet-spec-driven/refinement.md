# Refinement: create-packet-spec-driven

## State

- pre: agent writes 1 spec → 1 init call + 5 file edits =
  8 operations to create a packet.
- post: agent writes 1 spec → 1 create call = 2 operations
  (the spec write + the create call). Convention does the rest.

## Operation

`sh math-coding create <name> --from <spec.yaml>` reads the
spec, parses it, generates the five files atomically. The
agent writes the spec; the convention fills the packet.

For shell pipelines: `sh math-coding create <name> --from -`
reads the spec from stdin, enabling heredoc:

```
sh math-coding create my-feature --from - <<'EOF'
name: my-feature
mode: standard
...
EOF
```

## Mapping

| spec field | packet file |
|------------|--------------|
| name | packet.yaml:task_id |
| mode | (workflow only; not in file) |
| thesis | decision.md:## Thesis |
| antithesis | decision.md:## Antithesis |
| synthesis | decision.md:## Synthesis |
| surface_impact | decision.md:## Surface impact |
| proof | decision.md:## Proof |
| problem | task.md:## Problem |
| outcome | task.md:## Desired outcome |
| constraints | task.md:## Constraints |
| assumptions | assumptions.yaml (list of dicts) |
| state.pre | refinement.md:## State pre |
| state.post | refinement.md:## State post |
| operation | refinement.md:## Operation |
| mapping | refinement.md:## Mapping |
| invariant | refinement.md:## Invariant preservation |
| test_obligation | refinement.md:## Test obligation |
| runtime_check | refinement.md:## Runtime check |

## Invariant preservation

- All five files exist after `create` exits 0.
- The produced packet passes `core/check/verify.sh`.
- The spec's `thesis` appears verbatim in
  `decision.md:## Thesis`.
- axiom Self-Application holds for the new packet
  (probe.sh accepts it).
- `init-packet.sh` continues to work unchanged.

## Test obligation

`tests/run.sh` adds a case:

```
create-packet-spec-driven: create a packet from a minimal
  spec, assert five files exist, assert verify.sh exits 0,
  assert probe.sh exits 0.
```

The test exits 0 iff the new path satisfies the existing
convention. If the new path produces a packet that probe.sh
rejects, axiom Self-Application fails.

## Runtime check

None. The creation is commit-time. The runtime check is
the standard probe.sh axiom-Self-Application invocation
at every commit.