# Frequently Asked Questions

## How is math-coding different from ADR-tools / MADR / log4brains?

The functional difference is that the others store a *record*;
math-coding stores a *witness*. A record says what was decided; a
witness says the decision still matches the code at this commit.

| axis | adr-tools | MADR | log4brains | math-coding |
|---|---|---|---|---|
| verifiability | prose in markdown, manually read | prose, manually read | prose, GUI view | `mathc check` over git SHA |
| drift detection | none — author remembers to update | none | none | automatic, kernel returns `Drift` |
| author / signing | git author only | git author only | git author only | signed commits, `strict`/`lenient`/`off` modes |
| reproducibility | none | none | none | `Reproducible{command, recorded_exit}` re-runnable |

The packet is plain text under `math/<name>/packet.md`, bound to the
code by a `witness` (a git SHA), so `mathc check` returns the lifecycle
of every decision without a server.

## Can math-coding be used on an existing project?

Yes. See WORKFLOW.md "Brownfield: migrating an existing project."
The key steps: `mathc init`, create one `legacy-code` packet that
authorises the existing code, then turn each new architectural
choice into a packet. Old packets are migrated gradually.

## Do I need OCaml to use math-coding?

For building — yes (one time). After installation — no. One `mathc`
binary, plus shell and git, is everything you need for day-to-day
work.

## How do I add a new packet?

```sh
mathc record <name> "<proposition>"
git add math/<name>/ && git commit -m "<name>: short description"
mathc amend <name>
git add math/<name>/witness && git commit -m "<name>: witness"
mathc check
```

Or, with `AUTO_AMEND: true` in `.mathrc`: after a commit, mathc
will propose `amend` automatically.

## What if the code changes but the proposition does not?

That is drift (`Drift`). `mathc check` shows it as Warn. Fix it with
`mathc supersede <name> <name>-v2 "<new>"` — a new packet is created,
and the old chain is preserved as lineage.

## Why signed commits?

In `strict` mode the signature verifies that a human actually
adopted the decision, not someone recording it on their behalf. In
`lenient` mode the signature is a recommendation. In `off` mode the
convention does not check the actor.

## How do I find all packets about cache TTL?

```sh
mathc find TTL
# or
mathc grep "cache"
# or, if you have grep:
grep -r "TTL" math/ --include="packet.md"
```

## Can a packet be deleted?

No. Only supersession (`mathc supersede`). The history is preserved
as the decision's lineage. Deleting a packet means losing the memory
of why the code is the way it is.

## How do I generate the site?

```sh
mathc render
```

It produces `dist/index.html` with indexed packets. LaTeX formulas
are rendered through MathJax.

## What does mathc stats do?

```sh
mathc stats
# Total packets: 8
# Applied: 7 (87.5%)
# In draft: 1 (12.5%)
# Drift rate: 0/8 (0%)
# Supersession chains:
#   ttl-policy → ttl-policy-v2
```

Convention metrics: drift rate, applied/total, supersession chains.
Helps see how the convention is working on a project.

## Who maintains math-coding?

The community. Issues, pull requests, and discussions in the
repository. Internal changes go through a merge to main. Each
architectural decision in the kernel itself is recorded as a packet.
