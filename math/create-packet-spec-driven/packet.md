---
proposition: "A packet can be created from a single YAML spec via one shell call. The agent writes one spec, the convention produces the five files atomically. "
antithesis: "The current `core/author/init-packet.sh` produces only **placeholders** — five files containing "<your thesis here>". The agent must then **separately** open each file and fill it. This is **eight operations** for one packet: "
synthesis: "A spec is a YAML document with a fixed shape: ```yaml name: cache-ttl "
axiom: 
substrate: none
---

# create-packet-spec-driven

## Thesis

A packet can be created from a single YAML spec via one
shell call. The agent writes one spec, the convention
produces the five files atomically.

## Antithesis

The current `core/author/init-packet.sh` produces only
**placeholders** — five files containing "<your thesis
here>". The agent must then **separately** open each file
and fill it. This is **eight operations** for one packet:
init + five writes + verify + commit.

A convention should **reduce** the number of operations,
not expand them. The five-file packet is **one** atomic
proposition; it should be **one** atomic operation to
produce.

## Synthesis

A spec is a YAML document with a fixed shape:

```yaml
name: cache-ttl
mode: standard
thesis: "Cache entries expire after 60 seconds."
antithesis: "Users may need manual invalidation."
synthesis: "TTL is fixed; manual invalidation is a separate
         endpoint."
surface_impact: "touches: --cache-invalidate [FROZEN]"
proof: "tests/contract/test_cache_ttl.spec"
problem: "Stale data is served indefinitely after upstream
         changes."
outcome: "After 60s, cache is refreshed."
constraints:
  - TTL must be configurable
  - Invalidation must be idempotent
assumptions:
  - id: A1
    statement: "60s is acceptable for this endpoint"
    status: user-confirmed
    epistemology: fact
    confidence: 0.95
    evidence: "SLA allows 60s for /cache"
state:
  pre: cache miss
  post: cache hit
operation: "On read, check TTL. If age > 60s, refresh."
mapping: "raw bytes -> dict entry"
invariant: "Cache entries never served beyond TTL."
test_obligation: "tests/contract/test_cache_ttl.spec"
runtime_check: "errors to stderr"
```

`core/author/create-packet.sh` reads this spec, parses it,
generates the five files, and exits 0. The agent writes
**one** spec, the convention writes **five** files.

## Worked example

A human agent wants a packet:

```
$ cat > /tmp/spec.yaml <<'EOF'
name: my-feature
mode: standard
thesis: "The feature does X."
...
EOF
$ sh math-coding create my-feature --from /tmp/spec.yaml
Created packet: math/my-feature
  - packet.yaml      (manifest)
  - decision.md      (proposition)
  - task.md          (intent)
  - assumptions.yaml (epistemic context)
  - refinement.md    (state/op/mapping/invariant/test)
```

One call. Five files. The convention does the rest.

## Surface impact

touches: `core/author/create-packet.sh` (new script),
`math-coding` dispatcher (new `create` command), the
five-file packet format (now produced by spec, not by
init template)

## Proof

The evidence is the test: `tests/run.sh` runs a case that
calls `create-packet.sh` with a minimal spec, then asserts
the five files exist and pass `core/check/verify.sh`.
The test exits 0 iff the spec-driven path produces a valid
packet. axiom Self-Application holds iff the new path
satisfies the existing convention — i.e., the new path
must produce a packet that probe.sh accepts.
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