# Theories (math-coding v1.0)

Eight mathematical theories ground math-coding. Each is a compact
runtime spec; the OCaml runtime implements them.

## 1. Curry-Howard (axiom A2)

A packet is a spec. Code is the impl. The witness commit closes the
gap.

In OCaml:

```ocaml
type packet = {
  proposition : string;
  files : string list;
  witness : witness_entry list;
  ...
}

(* Curry-Howard is real when:
   forall sha in witness:
     git_show sha includes all files in packet.files *)
```

## 2. Predicate (axiom A4)

A check is a predicate `I : State -> bool`. Verify runs `I` for
each packet. If all return `true`, the convention holds.

```ocaml
type verdict = Pass of string | Warn of string | Fail of string | Skip of string

val check : packet -> verdict list
```

## 3. FSM (axiom A4)

Lifecycle FSM with six states and computed transitions.

```ocaml
type lifecycle =
  | Draft
  | Applied
  | Drift       (* proposition changed after witness *)
  | Stale       (* files changed after witness *)
  | Retired
  | Abandoned

val compute : packet -> lifecycle
```

## 4. Refinement (axiom A2)

A refinement relates implementation state to specification state.
For each witness commit, verify checks that the commit changes the
files declared in the packet.

## 5. Verdict (axiom A5)

Five verdicts: `Pass`, `Warn`, `Fail`, `Skip`, `Unverifiable`.

| Verdict | Exit code | Meaning |
|---------|-----------|---------|
| Pass | 0 | Check passed |
| Warn | 0 | Check passed with warning |
| Fail | 1 | Check failed |
| Skip | 0 | Check skipped (tool missing) |
| Unverifiable | 64/69/76 | Tool missing / data deferred / scope out |

In v1.0, only `Pass / Warn / Fail / Skip` are emitted.

## 6. Epistemic (axiom A5)

Five markers partition belief states:

```
  fact        B >= 0.95    evidence exists
  hypothesis  0.5 < B < 0.95
  judgment    B in {0, 1}
  unknown     B = 0
  proven      evidence reproducible (re-run gives same result)
```

`proven` requires reproducible evidence. Verify demotes on mismatch.

## 7. Deprecation (axiom A5)

Supersession is a binary relation on packets. Strict partial order
(irreflexive, asymmetric, transitive).

## 8. Agent (axiom A6)

LLM agents are functions over `(chat_history, files_read,
files_written, mode, role)`. In v1.0, the agent reads `AGENTS.md`
and packet files; writes packets and substrate specs.

## Substrate Decision Rules

See `substrate-decision-rules.md` for the full table. Summary:

- `none` — cosmetic / trivial.
- `shell` — one executable spec.
- `pbt` — property-based, many cases.
- `tla+` — state-machine, concurrency.
- `coq` — formal proof, critical invariants.
- `alloy` — relational constraints.
- `bpmn` — workflow steps.
- `pbt-prism` — probabilistic.

LLM chooses substrate based on the rules. CLI accepts any value.
Real verification is implemented for `none / shell / pbt` only.
