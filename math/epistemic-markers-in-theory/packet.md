---
proposition: "The five epistemic markers (fact, hypothesis, judgment, unknown, proven) appear in `theories/epistemic.md`. The theory of epistemic markers **contains** the markers it defines. "
antithesis: "If the theory file omits a marker, axiom Accounting's implementation is silent. axiom Accounting is implemented in `core/check/verify.sh`, which checks for marker **membership** in the allowed set. If the allowed set is "
synthesis: "`tests/run.sh` Case 17 asserts that all five markers appear in `theories/epistemic.md`: ``` "
axiom: 
substrate: none
---

# epistemic-markers-in-theory

## Thesis

The five epistemic markers (fact, hypothesis, judgment,
unknown, proven) appear in `theories/epistemic.md`. The
theory of epistemic markers **contains** the markers it
defines.

## Antithesis

If the theory file omits a marker, axiom Accounting's
implementation is silent. axiom Accounting is implemented
in `core/check/verify.sh`, which checks for marker
**membership** in the allowed set. If the allowed set is
stale (missing a marker), the verifier silently accepts the
missing marker as invalid.

A typo in the theory (e.g. "hypothises" instead of
"hypothesis") would not be caught unless someone reads the
theory file manually.

## Synthesis

`tests/run.sh` Case 17 asserts that all five markers
appear in `theories/epistemic.md`:

```
if grep -q "fact" "$REPO_ROOT/theories/epistemic.md" && \
   grep -q "hypothesis" "$REPO_ROOT/theories/epistemic.md" && \
   grep -q "judgment" "$REPO_ROOT/theories/epistemic.md" && \
   grep -q "unknown" "$REPO_ROOT/theories/epistemic.md" && \
   grep -q "proven" "$REPO_ROOT/theories/epistemic.md"; then
    PASS
else
    FAIL
fi
```

The test is **content-based**, not structural. It catches
typos, missing words, and accidental deletions.

## Worked example

A contributor adds a new marker "conjecture" to the
allowed set in `convention-spec.yaml` but forgets to add
it to `theories/epistemic.md`. axiom Accounting's spec is
extended; the verifier accepts "conjecture". The test
catches this only if it also asserts that the **five
canonical** markers are in the theory file.

This test is **conservative**: it asserts the **canonical
five** markers are present, not that **only** the five are
present. Future extensions (new markers) require a test
update, which is **explicit** and **visible** in a commit.

## Surface impact

touches: `theories/epistemic.md` (canonical content),
`tests/run.sh` (Case 17), axiom Accounting (the theory
of epistemic markers)

## Proof

The test runs at every commit (CI and locally). If the
theory file loses a marker, the test fails, the commit is
blocked (in CI), and the convention stays self-consistent.
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