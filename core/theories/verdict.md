# Verdict (axiom Accounting)

A verdict is the outcome of evaluating the proof
obligation:

```
Spec ⊨ P
```

read as: "the specification entails the proposition".

## math-coding instance

The five canonical verdicts of math-coding:

```
  VERIFIED                    proof accepted under test
  NEEDS_REVISION              counterexample or missing piece
  UNVERIFIABLE:TOOL_MISSING   required tool unavailable
  UNVERIFIABLE:DEFERRED       data not yet available
  UNVERIFIABLE:OUT_OF_SCOPE   human review required
```

## Mapping to verifier behaviour (v0.992)

| verdict | verifier exit code | convention artefact |
|---------|--------------------|--------------------|
| VERIFIED | 0 | `core/check/verify.sh` exits 0 |
| NEEDS_REVISION | 1 | `verify.sh` finds a missing file or invalid field |
| UNVERIFIABLE:TOOL_MISSING | 1 (same as NEEDS_REVISION; substrate check) | a substrate (TLA+, Coq) is required but not installed |
| UNVERIFIABLE:DEFERRED | 1 (same; marked in stdout) | data not yet available |
| UNVERIFIABLE:OUT_OF_SCOPE | 1 (same; marked in stdout) | requires human review |

**Note (v0.992):** the convention does not yet map the
three UNVERIFIABLE verdicts to distinct POSIX exit codes
(64/69/76 per sysexits.h). All `verify.sh` failures exit 1;
the specific verdict is reported on stdout. Distinct
exit codes are a roadmap item, not a v0.992 commitment.

## Why it matters

Anything outside these five is "looks fine" — the failure
mode axiom Accounting forbids.

A verifier that prints "all checks passed" without
naming a verdict fails axiom Accounting. A reviewer who reads
"VERIFIED" knows what passed; a reviewer who reads "looks
fine" knows nothing.

## Worked example

```
$ sh core/check/verify.sh
FAIL: math/my-pkt/: packet.yaml missing field applications
verify: 4 checks, 1 errors
```

The verifier prints the failure cause and exit code 1.
The convention's verdict is NEEDS_REVISION. The reviewer
reads the cause, fixes the packet, re-runs the verifier.

If the verifier printed "ok":

```
$ sh core/check/verify.sh
verify: 4 checks, 0 errors
```

the verdict is VERIFIED. The reviewer knows the packet
satisfies the structure.

## Where this lives

  `math/05-accounting/decision.md` — the axiom packet
  `theories/verdict.md` — this file
  `core/check/verify.sh` — the verifier that produces verdicts
  `core/self/probe.sh` — axiom Self-Application
## Definition

A verdict is the outcome of evaluating the proof obligation Spec ⊨ P. The convention's 5 verdicts (VERIFIED, NEEDS_REVISION, UNVERIFIABLE:TOOL_MISSING, UNVERIFIABLE:DEFERRED, UNVERIFIABLE:OUT_OF_SCOPE) are exhaustive.

## Theorem

The 5 verdicts (VERIFIED, NEEDS_REVISION,
UNVERIFIABLE:TOOL_MISSING, UNVERIFIABLE:DEFERRED,
UNVERIFIABLE:OUT_OF_SCOPE) are exhaustive.

## Proof

By enumeration: the proof obligation Spec ⊨ P has 5
outcomes. (1) Verified: proof holds. (2) Needs revision:
counterexample or missing piece. (3-5) Unverifiable:
tool missing, data deferred, scope out. Any other outcome
collapses to "looks fine" — axiom A5 forbids this. □
