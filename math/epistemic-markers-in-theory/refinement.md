# Refinement: epistemic-markers-in-theory

## State

- pre: theories/epistemic.md contains five markers
  (manually verified at genesis). A typo would not be
  caught.
- post: a self-test asserts the five markers are present.
  Typo caught at commit time.

## Operation

`tests/run.sh` Case 17:

```
markers_found=0
for m in fact hypothesis judgment unknown proven; do
    if grep -q "$m" "$REPO_ROOT/theories/epistemic.md"; then
        markers_found=$((markers_found + 1))
    fi
done
if [ "$markers_found" = "5" ]; then
    PASS
else
    FAIL
fi
```

## Mapping

| marker      | role                                    |
|-------------|-----------------------------------------|
| fact        | B(P) >= 0.95                            |
| hypothesis  | 0.5 < B(P) < 0.95                       |
| judgment    | B(P) in {0, 1}                          |
| unknown     | B(P) = 0                                |
| proven      | end-to-end verified (axiom A6)          |

## Invariant preservation

- All five markers are present in theories/epistemic.md.
- axiom Accounting is consistent with its theory.

## Test obligation

The test runs at every commit. Failure blocks the commit
(in CI). The convention's theory stays self-consistent.

## Runtime check

None. The test runs at commit time.