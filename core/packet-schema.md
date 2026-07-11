# packet-schema.md — packet field schema (markdown)

This document is the **canonical schema** for `packet.yaml`.
It is OS (operating-system), not a packet. It is authorized
by the convention as a whole (the convention declares that
every packet has a `packet.yaml` with this shape).

When the convention grows enough to need machine-readable
schema, a JSON Schema file will be added at `core/schemas/`
and authorized by a packet. For now, this markdown table is
sufficient.

## Required fields

| Field | Type | Required | Allowed values |
|-------|------|----------|----------------|
| `task_id` | string | yes | `^[a-z][a-z0-9-]*$` |
| `title` | string | yes | any human-readable string |
| `lifecycle` | enum | yes | `sketch`, `working`, `verified`, `deprecated`, `archived`, `superseded` |
| `substrate` | enum | yes | `none`, `shell`, `tla`, `typescript`, `pbt`, `alloy`, `coq`, `bpmn`, `pbt-prism` |
| `rigor` | enum | yes | `light`, `property`, `temporal`, `proof` |
| `decision` | enum | yes | `needed`, `made` |
| `created` | ISO date | yes | `YYYY-MM-DD` |
| `verifier` | null or object | yes | `null` or `{command, verdict_file}` |
| `depends_on` | list | yes | list of task_ids, may be empty `[]` |

## Conditional fields

`supersession` is present **only** when `lifecycle: superseded`:

| Field | Type | Notes |
|-------|------|-------|
| `supersession.supersedes` | task_id | the packet being replaced |
| `supersession.reason` | string | why the replacement happened |
| `supersession.type` | enum | `replaced`, `archived`, `deprecated` |
| `supersession.deprecated_at` | ISO date | when the replacement happened |

## Defaults

When a packet is created via `init-packet.sh`:
- `lifecycle: sketch`
- `substrate: none`
- `rigor: light`
- `decision: needed`
- `verifier: null`
- `depends_on: []`
