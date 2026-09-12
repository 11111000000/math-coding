# Substrate Decision Rules (math-coding v1.0)

LLM and developer choose one of eight substrates per packet. The
choice encodes how strongly the proposition is verified.

## The eight substrates

```
none       shell       pbt         tla+
           (single     (property-  (state-
            exec)       based)       machine)
                  
coq        alloy       bpmn        pbt-prism
(formal    (relational (workflow    (probabilistic
 proof)     constraint)  steps)       PBT)
```

## Decision tree

```
Is the proposition about:
├─ Cosmetic / naming / formatting?        → none
├─ One executable check?                  → shell
├─ "For all X, P(X)" with many cases?    → pbt
├─ State machine / concurrency?          → tla+
├─ Critical invariant / safety?           → coq
├─ Relational constraint / config?       → alloy
├─ Workflow / business process?           → bpmn
└─ Probabilistic / randomized system?     → pbt-prism
```

## When to upgrade substrate

Start at `none` if no executable check is feasible. Add
`shell` when a single command can verify the proposition. Move to
`pbt` when edge cases emerge. Reach for `tla+` / `coq` only when
the proposition is critical enough to justify the formal work.

Each upgrade is **observable**: verify reports more verdicts.
`shell` → 1 verdict. `pbt` → 1 verdict per property. `tla+` →
states explored.

## CLI behaviour by substrate

| Substrate | v1.0 behaviour |
|-----------|----------------|
| `none` | No executable check |
| `shell` | Run `run.sh`; check exit code |
| `pbt` | Run QCheck properties |
| `tla+` | Run TLC if installed, else `Skip` |
| `coq` | Run coqc if installed, else `Skip` |
| `alloy` | Run Alloy analyzer if installed, else `Skip` |
| `bpmn` | XML well-formedness check |
| `pbt-prism` | Run Prism if installed, else `Skip` |

## Why all eight, not three

The LLM user base does not have cognitive resistance to formal
verification. If the LLM is told "use `tla+` for concurrency",
the LLM will learn TLA+. The list of eight substrates is **the
menu**, not the **default**. Most packages will use `none`,
`shell`, or `pbt`. But the menu exists for the cases where
formal verification is right.

## What this is NOT

- Not a "best substrate". Each has a domain.
- Not a recommendation to use formal methods everywhere.
- Not a checklist to maximise substrate. Pick the **simplest**
  that gives the right confidence.
