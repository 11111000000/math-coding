# Math Coding Packets Index

This index lists every packet in the repository. INDEX.md is
the **view** over packets (documented exception, ADR-0006).

For each packet, the index shows: title, lifecycle, substrate,
verifier status. Click through to read the full packet.

## Convention (core/)

| Packet | Lifecycle | Substrate | Verdict |
|--------|-----------|-----------|---------|
| [core](core/) | verified | none | verified structurally |
| [agents](agents/) | verified | none | structural |

## Theory documents (core/01-Theory/)

These are part of the core. They ground every rule in mathematics.

| Document | Mathematical basis | Cited from |
|----------|---------------------|------------|
| [01-Predicate-and-Invariant](core/01-Theory/01-Predicate-and-Invariant.md) | $I : S \to \mathbb{B}$ | core.md: §Invariants |
| [02-State-Machine](core/01-Theory/02-State-Machine.md) | $\mathcal{M} = \langle S, s_0, A, \to, I \rangle$ | core.md: §State machine |
| [03-Temporal-Logic](core/01-Theory/03-Temporal-Logic.md) | `[]P`, `<>P`, `P ~> Q` | core.md: §Temporal properties |
| [04-Refinement](core/01-Theory/04-Refinement.md) | $R : S_{\text{impl}} \to S_{\text{spec}}$ | core.md: §Refinement |
| [05-Assumption-Set](core/01-Theory/05-Assumption-Set.md) | $\Sigma \vdash \text{Spec}$ | core.md: §Assumption set |
| [06-Verdict](core/01-Theory/06-Verdict.md) | $\text{Spec} \models P$ | core.md: §Verdicts |
| [07-Epistemic](core/01-Theory/07-Epistemic.md) | $B : \text{Prop} \times \text{Agent} \to [0,1]$ | core.md: §Epistemics |
| [08-Deprecation](core/01-Theory/08-Deprecation.md) | $P_{\text{old}} \perp P_{\text{new}}$ | core.md: §Deprecation |

## Examples

| Packet | Lifecycle | Substrate | Description |
|--------|-----------|-----------|-------------|
| [examples/hello](examples/hello/) | sketch | none | Minimal sketch packet |
| [examples/self-application](examples/self-application/) | verified | shell | Verifier (fractal property) |
| [examples/schema-self-application](examples/schema-self-application/) | working | shell | Schema validator |

## Architecture Decision Records

| ADR | Title |
|-----|-------|
| [0001-fractal-property](adr/0001-fractal-property/) | The methodology must apply to itself |
| [0002-decision-gate](adr/0002-decision-gate/) | Decision gate for opening packets |
| [0003-plain-text-and-git](adr/0003-plain-text-and-git/) | Plain text and git only |
| [0004-no-cli](adr/0004-no-cli/) | No CLI |
| [0005-soft-conventions](adr/0005-soft-conventions/) | Soft conventions enforced by verifier |
| [0006-self-applying-repository](adr/0006-self-applying-repository/) | Every artifact is a packet |
| [0007-theory-as-foundation](adr/0007-theory-as-foundation/) | Theory documents are part of the core |
| [0008-epistemic-protocol](adr/0008-epistemic-protocol/) | Epistemics as action protocol |
| [0009-extended-packet-fields](adr/0009-extended-packet-fields/) | Extended packet.yaml fields |
| [0010-extended-fsm-triggers](adr/0010-extended-fsm-triggers/) | Extended FSM triggers |

## Development artifacts (artifacts/)

These packets document the development of the convention itself.

| Packet | Lifecycle | Substrate | Purpose |
|--------|-----------|-----------|---------|
| [artifacts/theory-01-predicate-invariant](artifacts/theory-01-predicate-invariant/) | working | none | Theory document development |
| [artifacts/theory-02-state-machine](artifacts/theory-02-state-machine/) | working | none | Theory document development |
| [artifacts/theory-03-temporal-logic](artifacts/theory-03-temporal-logic/) | working | none | Theory document development |
| [artifacts/theory-04-refinement](artifacts/theory-04-refinement/) | working | none | Theory document development |
| [artifacts/theory-05-assumption-set](artifacts/theory-05-assumption-set/) | working | none | Theory document development |
| [artifacts/theory-06-verdict](artifacts/theory-06-verdict/) | working | none | Theory document development |
| [artifacts/theory-07-epistemic](artifacts/theory-07-epistemic/) | working | none | Theory document development |
| [artifacts/theory-08-deprecation](artifacts/theory-08-deprecation/) | working | none | Theory document development |
| [artifacts/core-v2](artifacts/core-v2/) | working | none | Core v2 development |
| [artifacts/schemas-v2](artifacts/schemas-v2/) | working | none | Schemas v2 development |
| [artifacts/agents-protocol](artifacts/agents-protocol/) | working | none | Agents protocol development |
| [artifacts/self-application-v2](artifacts/self-application-v2/) | working | shell | Self-application v2 development |
| [artifacts/hello-v2](artifacts/hello-v2/) | sketch | none | Hello template |
| [artifacts/install-v2](artifacts/install-v2/) | working | shell | Install script development |

## Verification

Run the verifier from the repository root:

```sh
sh examples/self-application/verify-consistency.sh
```

If exit 0, the convention holds. If exit 1, the verifier lists
which packets violated which rule.

## Schemas (exceptions)

`schemas/*.json` are JSON Schema files referenced by the
convention. They are not packets; they are machine-readable
specifications that the convention depends on. They are
themselves verified by `examples/schema-self-application/`.