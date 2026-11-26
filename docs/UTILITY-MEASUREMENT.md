# Utility measurement contract

Math Coding has three different measurements. They are not interchangeable.

## 1. Implementation readiness

The repository proves that the tool is executable and that its map, controls,
bundle, archive, and agent boundary behave as declared. This is necessary, but
it does not prove usefulness.

## 2. In-repo overhead

`mathc-stand` and `.math/v7/runs.jsonl` can measure the cost of the protocol
against direct verifier execution. This answers "what does the gate cost?", not
"does it reduce rework?". A high overhead is a reason to simplify; zero overhead
is not evidence of utility.

## 3. External usefulness

Usefulness is measured only by the preregistered comparison in
`docs/measurements/BENCHMARK-PROTOCOL.md`: Protocol versus Checklist on the
same task, revision, model, build, and budget, with an independent reviewer and
an observation window.

The primary outcome is `reopened`. Secondary outcomes are post-acceptance
defects, handoff time, repeated investigations, false-green declarations, and
full cost. The owner's preregistered rule is:

1. at least a 30% reduction in `reopened`;
2. at least a 20% reduction in median `handoff_seconds`;
3. no more than a 15% increase in full cost;
4. no decision from an incomplete arm or rejected ledger.

Until those data exist and are reviewed, the honest state is **not measured**.
`method-usefulness` in `spec.json` is a human judgment, not a machine fact.

## 4. Run the pilot

The owner starts the experiment; the kit only validates and summarizes records:

```sh
sh docs/measurements/pilot-kit.sh prereq
sh docs/measurements/pilot-kit.sh selftest
sh docs/measurements/pilot-kit.sh validate LEDGER.jsonl
sh docs/measurements/pilot-kit.sh summary LEDGER.jsonl
```

The kit never invents data, accepts a missing reviewer, or turns a dry run into
a field result.
