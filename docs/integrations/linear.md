# Linear Integration

This document describes how math-coding packets work with
Linear (the issue tracker). Linear is the de-facto issue tracker
for AI/agent-driven development in 2025-2026.

## TL;DR

Each math-coding packet references its Linear issue via the
`linear_id` field in `packet.yaml`. Status changes in Linear
flow back to the packet; promotion of lifecycle flows to Linear.

## The `linear_id` field

Add the field to `schemas/packet-manifest.schema.json` (v2.1+):

```json
"linear_id": {
  "type": "string",
  "pattern": "^[A-Z]+-[0-9]+$",
  "description": "Linear issue key, e.g., MATH-123"
}
```

In `packet.yaml`:

```yaml
task_id: modal-dialog
linear_id: MATH-42
title: Modal Dialog State Machine
lifecycle: verified
```

The `linear_id` is optional. Packets can exist without a Linear
issue (useful for theory documents and the convention itself).

## Bidirectional sync

### Direction 1: Linear -> Packet

When a Linear issue changes status, the corresponding packet's
lifecycle is updated:

| Linear state | Packet lifecycle |
|--------------|-------------------|
| Backlog | sketch |
| In Progress | working |
| In Review | working |
| Done | verified |
| Canceled | deprecated |
| Duplicate | archived |

This requires a Linear webhook handler. The convention does
not ship one (it would require a hosted service); instead,
implement it in your project:

```python
# tools/linear-sync.py
import json
import os
import urllib.request

def on_linear_webhook(payload):
    if payload["type"] != "Issue":
        return

    issue_key = payload["data"]["identifier"]   # e.g., MATH-42
    state = payload["data"]["state"]["name"]    # Done, In Progress, ...

    packet_lifecycle = {
        "Backlog": "sketch",
        "In Progress": "working",
        "In Review": "working",
        "Done": "verified",
        "Canceled": "deprecated",
        "Duplicate": "archived",
    }.get(state)

    if not packet_lifecycle:
        return

    # Find and update the packet
    packet_path = find_packet_by_linear_id(issue_key)
    if not packet_path:
        return

    update_lifecycle(packet_path, packet_lifecycle)
```

### Direction 2: Packet -> Linear

When a packet's lifecycle changes (e.g., from `working` to
`verified`), the corresponding Linear issue should also
update. This requires the agent or developer to update Linear
manually, or a hook on push:

```bash
# .git/hooks/post-receive
PACKET_FILE="$1"
LINEAR_ID=$(yq -r '.linear_id // ""' "$PACKET_FILE")
LIFECYCLE=$(yq -r '.lifecycle' "$PACKET_FILE")

if [ -n "$LINEAR_ID" ] && [ -n "$LIFECYCLE" ]; then
    curl -X POST "https://api.linear.app/graphql" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "{\"query\":\"mutation { issueUpdate(id: \\\"$LINEAR_ID\\\", input: { stateId: \\\"$STATE_MAP[$LIFECYCLE]\\\" }) { success } }\"}"
fi
```

## Linear issue template (recommended)

Create a Linear issue template:

```
## What

[short description of the task]

## Math-coding packets

<!-- The packet the agent will create/update -->

- task_id: [e.g. modal-dialog]
- linear_id: [auto-filled: MATH-N]

## Constraints

[bullet list of constraints the implementation must satisfy]

## Adaptations

<!-- If you deviated from these, document here -->

[n/a or explanation]
```

This template mirrors the packet structure. When an agent
reads a Linear issue, it knows what to expect.

## Agent flow

When an AI agent works on a math-coding packet linked to
Linear:

1. Read `linear_id` from `packet.yaml`.
2. Read the Linear issue via API.
3. Apply the epistemic action protocol from `agents/agents.md`.
4. Implement the change.
5. Update Linear status when lifecycle promotes.
6. Document Adaptations in the packet's `task.md`.

The flow is **bidirectional but human-confirmed**. Neither
Linear nor the agent can auto-promote lifecycle without
verifier output.

## What this does NOT solve

- **Does not replace the verifier.** A Linear "Done" status
  does not make a packet verified; only the verifier does.
- **Does not auto-resolve conflicts.** If Linear and packet
  disagree on status, the convention treats the packet as
  canonical and the Linear status as advisory.
- **Does not work offline.** Linear is a hosted service; packet
  files are local. Sync requires network access.

## Setup

1. Create a Linear API key with `read,write` scope on issues.
2. Set `LINEAR_API_KEY` in your CI secrets.
3. Configure webhooks to call your sync service.
4. Update `schemas/packet-manifest.schema.json` to add `linear_id`.

## References

- Linear API:
  <https://developers.linear.app/docs/graphql/working-with-the-graphql-api>
- Linear webhooks:
  <https://developers.linear.app/docs/webhooks>