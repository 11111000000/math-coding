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