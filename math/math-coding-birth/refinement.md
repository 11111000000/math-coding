# Refinement: math-coding-birth

## State

- **pre**: vibe-coding (intent in chat, no formal artifacts)
- **post**: math-coding (intent in packets, agents follow protocol)

## Operation

- Declare the convention's first decision as a packet.
- Install agents.md at repo root as the agent contract.
- 5 files per packet, mandatory from commit 1.
- 11 theory docs in core/theories/ as foundation.

## Invariant

- Every directory in `math/` has exactly 5 files.
- `agents.md` exists and is ≤ 50 lines.
- Each assumption has 4 fields (status, epistemology, confidence,
  evidence).
- **Recursive observability**: every packet in `math/` can be
  verified against the repo at its commit. The verifier reads
  `decision.md` and checks: "Does this packet's claims match
  reality?" (see A4 evidence).

## Convention categories (14 axes)

This packet declares the existence of the following convention
dimensions. Each is currently implemented as a default; future
packets may refine any of them.

### 1. Decision artifact

A packet documents one decision with intent. Format: thesis →
antithesis → synthesis. Five file types per packet.

### 2. Packet structure

Five files per packet: packet.yaml (manifest), decision.md
(what this packet decides), task.md (problem/outcome/constraints),
assumptions.yaml (epistemic context), refinement.md (how this
packet extends or supersedes).

### 3. Epistemics (4 fields per assumption)

- `status`: user-confirmed | agent-inferred | open
- `epistemology`: fact | hypothesis | judgment | unknown
- `confidence`: 0.0 to 1.0 (optional for judgment and unknown)
- `evidence`: free-form text + one structured ref
  (`See: packet:<path>#<section>`)

### 4. Verdicts (5 types, currently no verifier)

- VERIFIED — claim proved by tool
- NEEDS_REVISION — counterexample found
- UNVERIFIABLE:TOOL_MISSING — tool unavailable
- UNVERIFIABLE:OUT_OF_SCOPE — human review required
- UNVERIFIABLE:DEFERRED — data not yet available

### 5. Lifecycle (6 states)

sketch → working → verified → deprecated → archived → superseded

### 6. Rigor (4 levels)

light (structural only) → property → temporal → proof

### 7. Substrate (9 options)

none (no formal tool) → shell → tla → typescript → pbt → alloy →
coq → bpmn → pbt-prism

### 8. Packet kinds (3 types)

decision (documents convention rule) → feature (working
example) → tool (utility)

### 9. Coverage / recursive observability

Every decision about the convention is itself a packet,
declared in `coverage.yaml` (or equivalent). Critical gaps
fail CI. Self-check verifier enforces recursive observability.

### 10. Refinement pattern

Every packet includes `refinement.md` with: State (pre/post),
Operation, Invariant, Test obligation, Runtime check.

### 11. Schema location

`core/packet-schema.md` — markdown table of packet fields.
Future: JSON Schema at `core/schemas/`, authorized by a packet.

### 12. Rendering (human-facing)

- `README.md` — entry point
- `agents.md` — protocol for agents
- Each packet's `decision.md` — human-readable explanation
- No external renderer required; git + plaintext is enough

### 13. Mathematical theories (11 OS files)

Convention grounded in 11 mathematical theories documented in
`core/theories/`: predicate, fsm, ltl, refinement, assumption,
verdict, epistemic, deprecation, curry-howard, modal, confidence.
Each theory is an OS file authorized by the convention as
foundation.

### 14. Operating system (minimal)

Outside `math/`, files are OS. They support convention but do
not declare decisions.

OS files in commit 1:
- `README.md`, `agents.md`, `.gitignore` (root)
- `core/packet-schema.md` (schema table)
- `core/theories/*.md` (11 theory docs)

In brownfield mode, most existing files are OS files. Only
files that document architectural decisions need packets.

## Field semantics (packet.yaml)

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `task_id` | string | yes | `math-coding-birth` |
| `title` | string | yes | human-readable name |
| `lifecycle` | enum | yes | `sketch`, `working`, `verified`, `deprecated`, `archived`, `superseded` |
| `substrate` | enum | yes | `none`, `shell`, `tla`, `typescript`, `pbt`, `alloy`, `coq`, `bpmn`, `pbt-prism` |
| `rigor` | enum | yes | `light`, `property`, `temporal`, `proof` |
| `decision` | enum | yes | `needed`, `made` |
| `created` | ISO date | yes | `2026-07-11` |
| `verifier` | null or object | yes | `null` or `{command, verdict_file}` |
| `depends_on` | list | yes | list of task_ids, may be empty `[]` |

Conditional: `supersession` present only when
`lifecycle: superseded`.

## Edit protocol

- **Cosmetic edit of packet** (typo, format): direct edit,
  commit "fix: <msg>"
- **Structural edit of packet**: NEVER edit. Create new packet
  with `supersession:` pointing at the old one
- **Code change driven by packet**: git commit with packet id
  in message ("<packet-id>: change <thing>")

## Brownfield mode

In existing projects, convention applies selectively:
- Most existing files are OS files (no packet needed)
- Only files that document architectural decisions need packets
- Convention adds `math/` directory; existing structure preserved

## Test obligation

- This packet is the test: any reader can verify by counting
  files in `math/`.

## Runtime check

- None required yet (no code to verify at seed stage).
- Deferred to a future packet that introduces a verifier.
