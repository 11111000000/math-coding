# math-coding

> A discipline of recording decisions before code.

**Verifiable decision recording for AI coding agents.**
*Agent claims were answers. Decisions are now receipts.*

math-coding is the only ADR convention whose packets are bound to the
code through a git SHA, with drift detected by a static kernel: when
an AI coding agent (Cursor, Claude Code, Copilot Workspace, or any
other) commits a decision alongside its code, `mathc check` reads
it back from git history and warns if the code moves without a
supersession. The kernel ships as a single static binary; packets
are plain text and live in `math/`; signing modes bind authorship
cryptographically so a packet's `actor` field cannot drift silently.

## What it is

math-coding is a discipline in which the proposition is recorded
before the code is written. A decision exists as a proposition (a
type, by Curry-Howard), the code as its realisation (a term), and
the witness as proof of inhabitation. Every non-trivial
architectural decision in a project becomes a packet verified by
the kernel.

What math-coding does with a decision as it passes through the
convention:

- **fixes the proposition** — recorded in `packet.md` before the
  code is written;
- **binds it to code** — through `witness` (a git SHA), the
  proposition and code become a verifiable link;
- **checks it via the kernel** — `mathc check` detects drift
  (code changes without proposition update), structural errors
  (empty proposition, FSM violations, SPO violations);
- **evolves through supersession** — a change of proposition
  spawns a new packet; the previous chain is preserved as
  lineage;
- **records the actor** — who made the decision (human, agent or
  system), optionally verified through signatures;
- **requires care** — for human decisions, potential harm is
  explicitly considered (reversibility, mitigation).

## What's inside

Eight packets that the kernel `S` verifies, all under one binary.

- **curry-howard** — decision = (proposition, code, witness)
- **temporal** — lifecycle computed from git history
- **constructive** — proof = re-run and exit code
- **categorical** — supersession = strict partial order
- **motivation** — register and why; care for human decisions
- **process-fsm** — three states, one forbidden transition
- **dialectic-tas** — thesis, antithesis, synthesis for judgments
- **actor-discipline** — signed commits fix who decided

The convention applies to itself: foundations are packets verified
by the same kernel.

## Under the hood

- Five foundations + three extensions = eight packets, all verified by
  the same kernel `S` over the same git history.
- ~700 lines of OCaml, one static binary (`mathc`).
- Plain text + git, no servers, no databases, no frameworks.

## Quick start

```sh
mathc init
mathc record my-decision "TTL = 60s with manual invalidation"
git add math/my-decision/ && git commit -m "my-decision: ttl policy"
mathc amend my-decision
git add math/my-decision/witness && git commit -m "my-decision: witness"
mathc check
# my-decision: applied ✓
```

## Commands

| command | purpose |
|---|---|
| `mathc init` | bootstrap project (structure + pre-commit + .mathrc) |
| `mathc record <name> "<proposition>"` | create a packet |
| `mathc amend <name>` | set witness to current commit |
| `mathc supersede <old> <new> "<proposition>"` | replace decision |
| `mathc check` | verify all packets |
| `mathc status --json` | state and next steps in JSON |
| `mathc render` | generate HTML site |
| `mathc review <name>` | transition to `state: reviewed` (signed) |
| `mathc find <substring>` | search packets by substring |
| `mathc grep <pattern>` | grep over proposition and name |
| `mathc show <name>` | show full packet |
| `mathc list` | list all packets |
| `mathc history <name>` | packet history and versions |
| `mathc graph <name>` | mermaid supersession chain |
| `mathc stats` | drift rate and applied/total |
| `mathc migrate-convention` | update packets to current convention schema |

## Install

```sh
# Easiest: binary drop with agent-skill auto-install.
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
```

This installs `mathc` to `~/.local/bin/`, drops `SKILL.md` into
`~/.claude/skills/math-coding/`, `~/.config/opencode/skills/math-coding/`,
and similar dirs for Cursor and Continue.

If no GitHub Release is available for your OS/arch, the script
falls back to building from source via opam or nix.

### Source build

```sh
git clone https://github.com/11111000000/math-coding
cd math-coding
nix develop --command sh scripts/install.sh
# or
opam switch create 5.2.0 && opam install dune
sh scripts/install.sh
```

Binary lands at `$XDG_DATA_HOME/math-coding/current/mathc`.
Wrapper `./mathc` at the project root resolves to it.

## Documentation

- [MANIFESTO.md](MANIFESTO.md) — eight principles, academic exposition
- [FOUNDATIONS.md](FOUNDATIONS.md) — packet descriptions
- [WORKFLOW.md](WORKFLOW.md) — how to work, brownfield, migration
- [FAQ.md](FAQ.md) — ten frequent questions
- [math/modeling/](math/modeling/) — formal model (LaTeX)
- [AGENTS.md](AGENTS.md) — protocol for AI agents
- [skills/math-coding/SKILL.md](skills/math-coding/SKILL.md) — bootstrap for opencode / claude-code

## License

Living Beings License — see [LICENSE](LICENSE).