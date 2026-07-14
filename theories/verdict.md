# Verdict (axiom A5)

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

## Mapping to verifier behaviour

| verdict | verifier exit code | convention artefact |
|---------|--------------------|--------------------|
| VERIFIED | 0 | `core/check/verify.sh` exits 0 |
| NEEDS_REVISION | 1 | `verify.sh` finds a missing file or invalid field |
| UNVERIFIABLE:TOOL_MISSING | 69 (EX_UNAVAILABLE) | a substrate (TLA+, Coq) is required but not installed |
| UNVERIFIABLE:DEFERRED | 64 (EX_USAGE) | data not yet available |
| UNVERIFIABLE:OUT_OF_SCOPE | 76 (EX_PROTOCOL) | requires human review |

Exit codes follow POSIX sysexits.h convention.

## Why it matters

Anything outside these five is "looks fine" — the failure
mode axiom A5 forbids.

A verifier that prints "all checks passed" without
naming a verdict fails axiom A5. A reviewer who reads
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
  `core/self/probe.sh` — axiom A6 self-application