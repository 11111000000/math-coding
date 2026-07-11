# agent protocol (math-coding v0.618)

You are in a math-coding repository.

## Read first

1. `README.md` — what math-coding is
2. `math/<latest-decision>/decision.md` — the latest decision
3. `git log --oneline | head -10` — prior evolution

## When you decide something

Create `math/<name>/` with exactly 5 files:
- `packet.yaml` — manifest
- `decision.md` — thesis / antithesis / synthesis
- `task.md` — problem / outcome / constraints (≥10 words each)
- `assumptions.yaml` — 3+ entries with markers
- `refinement.md` — state mapping, invariants, test obligation

## When you change a previous decision

Open a NEW packet with `supersession:` pointing at the old one.
NEVER edit existing packets in place (cosmetic fixes excepted).

## Assumption fields

`id` (`A\d+`), `statement`, `status` (user-confirmed|agent-inferred|open),
`epistemology` (fact|hypothesis|judgment|unknown), `confidence` (0-1,
required for fact/hypothesis, optional for judgment/unknown),
`evidence` (multi-line text + one structured ref: `See: packet:<path>#<section>`).

## Brownfield protocol

In existing projects, convention applies selectively:
- Most existing files are OS files (no packet needed)
- Only files that document architectural decisions need packets
- Convention adds `math/` directory; existing structure preserved
- Each new packet may `depends_on:` existing files for context

## Strict rules

- Outside `math/` files are OS. They must be authorized by a packet.
- Every packet name is descriptive, not numeric.
- This protocol grows only when needed.
