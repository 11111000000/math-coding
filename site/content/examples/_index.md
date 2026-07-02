---
title: "Examples"
description: "Working examples of the convention in action"
---

# Examples

Three reference implementations show the convention in action. Each is a complete packet that has been verified.

| Example | Lifecycle | Rigor | Description |
|---------|-----------|-------|-------------|
| [Modal dialog]({{< ref "modal-dialog.md" >}}) | verified | temporal | State machine for a modal dialog (5 states, 7 transitions) — TLA+ model with TypeScript refinement and tests |
| [Self-application]({{< ref "self-application.md" >}}) | verified | light | The structural verifier itself — demonstration of the fractal property |
| [Schema self-application]({{< ref "schema-self-application.md" >}}) | working | light | Meta-validator for the JSON Schema files |
| [External project]({{< ref "external-project.md" >}}) | sketch | n/a | Demonstrates external-project mode (packets in `specs/`, code in `src/`) |

The modal dialog is the most useful starting point. It demonstrates a complete packet with a formal model, a refinement map, and runtime tests that check the same invariants the model checks.