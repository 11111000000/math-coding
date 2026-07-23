# Known limitations (math-coding v0.992)

math-coding v0.992 is intentionally minimal. It does not
attempt to solve every problem a project might face. This
document lists the limitations we know about, why they
exist, and what the workaround is.

## 1. Convention does not run user tests

**Limitation.** math-coding's verifier checks structure
(packet.yaml fields, decision.md sections, etc.) but does
not run the tests described in `refinement.md:test` or
recorded in `packet.yaml:verifier`. The convention's runtime
is POSIX shell — it does not depend on pytest, jest, go test,
or any other test framework.

**Why.** axiom A3 (Material Basis): plain text + git + POSIX.
Adding test runners would break the substrate requirement
and add installation complexity.

**Workaround.** The target project runs its tests in its
own CI. The convention provides:
- `packet.yaml:verifier` for recording the verification command.
- `extensions/ci/github-actions-tdd.yml` as a CI template
  that reads `verifier` and runs it.

If you use a different CI (GitLab, Jenkins, CircleCI),
adapt the template.

## 2. Convention does not enforce CI in target

**Limitation.** math-coding provides a CI template
(`extensions/ci/github-actions-tdd.yml`), but it
does not enforce that target projects actually use it.
If a target project has no CI, the convention cannot
detect that.

**Why.** CI is the target project's responsibility, not
the convention's. The convention provides shape; the
target chooses its operational practices.

**Workaround.** Document in your team's README that CI
is required for convention usage. Reviewers check that
PRs pass `sh math-coding probe` before merge.

## 3. Monorepo not supported out-of-the-box

**Limitation.** math-coding supports one `math/` at the
project root. For monorepos with multiple subprojects
(each with their own decision history), there is no
native support.

**Why.** `MATH_DIR` resolves to one directory relative
to `.mathrc`. Multi-`MATH_DIR` would require a different
schema (e.g. `math_dirs: [services/auth/math,
services/api/math]`), and that would be a major change.

**Workaround.** Each subproject installs its own copy of
math-coding. Each subproject has its own `math/`, its
own `.mathrc`, and its own CI.

```
monorepo/
├── services/auth/
│   ├── .math-coding/
│   ├── math/
│   └── .mathrc
└── services/api/
    ├── .math-coding/
    ├── math/
    └── .mathrc
```

This is verbose but correct. Future versions may support
multi-`MATH_DIR`.

## 4. Multi-agent conflicts not prevented

**Limitation.** If two AI agents work on the same project
and both modify the same packet, the convention does not
prevent conflicts. The last write wins.

**Why.** Convention does not have file-locking semantics.
Distributed coordination requires external infrastructure
(databases, locks, queue systems) that the convention
cannot provide without breaking axiom A3.

**Workaround.** Use git's merge mechanism for packet files.
If two agents append to the witness file, merge manually.
For high-concurrency setups, use agent-locking at the
orchestration layer (above the convention).

## 5. Verification is structural, not behavioral

**Limitation.** `verify.sh` checks packet structure
(5 files, lifecycle enum, epistemology enum, witness SHA).
It does not check that the code in the commit referenced by
the witness actually implements the proposition.

**Why.** The convention does not run the code. To verify
behavior, you need to run the code (axiom A3 limits us to
POSIX shell).

**Workaround.** Use TDD: write tests first, run tests in CI.
The convention provides `extensions/tdd.md` for this.

## 6. Dataview only works in source-repo

**Limitation.** Dataview queries in `core/spec/axioms.md` and
`core/theories/README.md` work only when the source-repo is
opened in Obsidian. They do not work in target projects
(which lack axioms/, core/theories/, docs/).

**Why.** Dataview queries against axiom packets. axiom
packets are source-only.

**Workaround.** For target projects, use `git log -- math/`
and `cat math/<packet>/packet.yaml` from the command line.
This is what math-coding prescribes.

## 7. synthesis and operation are not templated

**Limitation.** The convention does not generate
`decision.md:antithesis`, `decision.md:synthesis`, or
`refinement.md:operation`. The agent (or human) writes
these. They are real decisions, not boilerplate.

**Why.** axiom A1 (Care): the convention cannot make
decisions for the agent. Templating these would mean the
convention thinks, not the agent.

**Workaround.** The agent reads `extensions/agents/opencode/SKILL.md`
for guidance on writing antithesis, synthesis, and
operation. Worked examples are provided.

## 8. Supersession is two-step, not atomic

**Limitation.** Retiring a packet and creating a successor
are two separate commands. There is a window between
`retire` and `create` where the old packet is retired and
no successor exists.

**Why.** Atomic supersession would require the convention
to know the new proposition before retiring the old. This
breaks the principle of explicit, atomic operations.

**Workaround.** Always create the successor before retiring
the predecessor. Or accept the brief inconsistency.

## 9. The seven-field spec: only proposition + outcome mandatory (v0.992)

**Behavior.** `create` accepts a partial spec. Only
`proposition` and `outcome` are required; the other five
fields (`invariant`, `test`, `antithesis`, `synthesis`,
`operation`) are recommended but generate warnings, not
errors, when missing.

**Why.** Earlier versions required all seven fields and
refused to create the packet otherwise. This produced
friction for trivial decisions. v0.992 relaxes the gate
to reduce ceremony; placeholder text in decision.md /
refinement.md is still warned about by `verify.sh`.

**Workaround.** None needed. Pass only `proposition` and
`outcome` for a quick packet; fill the rest when the
decision merits the work.

## 10. .math-coding/ is committed by default

**Behavior.** `install.sh` does NOT add `.math-coding/`
to `.gitignore` by default. The convention is committed to the
project's git repository. New clones have the convention
without running install.sh manually, and CI works
out-of-the-box.

**Why.** Committed convention removes the "new developer
runs install.sh" friction.

**Opt-out.** Pass `--gitignore` to `install.sh`:
```
sh math-coding install /path/to/project --gitignore
```
This restores the historical behavior of adding
`.math-coding/` to `.gitignore`.

## 10a. Race condition on concurrent apply

**Limitation.** If two AI agents call `apply` on the same
packet simultaneously, the convention does not prevent
file-system race conditions. The last write wins.

**Why.** Convention does not have file-locking semantics
or transactions. Distributed coordination requires
external infrastructure.

**Workaround.** Use git's merge mechanism for packet files.
If two agents append to the witness file, merge manually.
For high-concurrency setups, use agent-locking at the
orchestration layer (above the convention).

## 11. Convention does not provide schema migration tools

**Limitation.** When upgrading from one math-coding version
to another, there is no automatic migration. If the packet
schema changes (e.g. from 5 files to 3 mandatory in
v0.944 → v0.978), you must migrate manually.

**Why.** Migration scripts are version-specific. Each
upgrade would require a new migration script.

**Workaround.** For v0.944 → v0.978, the migration was:
- `lifecycle: working|verified|sketch` → `applied|draft`
- `lifecycle: superseded|deprecated|archived` → `retired`
- 5 files kept, 3 are now mandatory (others are auto-generated)

For v0.991 → v0.992, the migration was:
- `packet.yaml:applications[]` SHA moved to sibling `witness` file
  (axiom A5 recursion fix — refresh commit no longer rewrites the
  file it is supposed to witness)
- 6-state lifecycle FSM collapsed to 4-state (draft / applied /
  retired / abandoned) matching the verifier

Run `sh meta/migrate-witnesses.sh` to migrate existing
applications[] entries automatically. Future versions may
include `sh math-coding migrate` scripts.

## 12. The convention's own axiom packets may have placeholder text

**Limitation.** Source-repo axiom packets (e.g.
`math/00-difference/`) may contain placeholder-like
text that `verify` warns about. The warnings are
informational; they do not fail verification.

**Why.** Axiom packets are reference material; their
content is meant to be read, not generated.

**Workaround.** Ignore warnings on axiom packets. They are
expected. If you create your own axiom packets, ensure
they have substantive content.

## When NOT to use math-coding (v0.992)

The convention is for **decisions**, not for **work**.
Creating a packet for every commit produces ceremony without
signal.

### Trivial changes (use `git commit`, no packet)

  - Typos in code or docs.
  - Renames of a local variable, function, file, or directory.
  - Format fixes that don't change behavior.
  - Dependency bumps within a minor version.
  - Doc-only changes that do not encode a decision.

These are mechanical, reversible without thought.

### Decision-class changes (use `sh math-coding create`)

  - A choice was made that another developer would
    disagree with, and you had reasons.
  - The change affects future direction.
  - The change is irreversible.
  - The change introduces a new invariant.

### Judgment-call zone

  1. Would I be surprised to see this in 6 months? If yes,
     write a packet. If no, commit.
  2. Is there a reasonable alternative I rejected?
     If yes, the rejection is the decision; write a packet.

### Anti-patterns

  - **Packet for everything**: signal diluted; readers learn
    to ignore packets. Use `abandon` and `retire` to keep
    `math/` lean.
  - **No packets**: decisions live in memory only.
    "Why is the cache 60s?" becomes "guess".

## What this list is NOT

This list is **not** a roadmap. Some limitations may be
addressed in future versions (monorepo support, multi-
agent coordination). Others are intentional design
decisions (the convention does not run code, the
convention does not enforce CI).

Each limitation has a workaround. Use the workaround
if the limitation affects you. If the workaround is
insufficient, open an issue describing the use case.

## 13. Adversarial LLMs bypass epistemic honesty (v0.992)

**Limitation.** v0.992 enforces:
- `fact` markers carry evidence (warning otherwise).
- `applied` packets require ≥1 SHA in the witness file
  plus ≥1 approve review.
- Self-critique prompts and review criteria are echoed.

**What this DOES NOT catch.** Adversarial LLM can:
- Write `fact: 0.95` for speculation (no real evidence).
- Submit `--approve` without running through criteria.
- Skip self-critique prompts entirely.

Convention operates on **outputs**, not **state**. It
cannot detect what the LLM actually thought, only what it
wrote.

**Workaround.** None within convention. Use external
governance:
- Code review by humans.
- Sampling (audit random packets for honesty).
- Restricted compute (limit who can call `apply`/`create`).

**Honest framing.** math-coding's epistemic honesty is a
**protocol for honest agents**, not a **shield against
dishonest ones**. Treat v0.992 as raising the floor for
honest agents, not as security.

## 14. Vendored fonts not yet shipped with site (v0.992+)

**Limitation.** Site CSS at `site/assets/css/tokens.css`
declares `@font-face` rules referencing Source Serif 4 and
JetBrains Mono woff2 files at `site/assets/fonts/`. As of
v0.992, those woff2 files are not vendored in this
repository, so browsers fall back to system serif/mono
fonts until a follow-up packet adds the font assets.

**Why.** Vendoring ~138 KB of binary font assets requires
a packet proposal with explicit license verification (both
Source Serif 4 SIL OFL and JetBrains Mono Apache 2.0 allow
redistribution, but the packet must record the verification
as an axiom A5 epistemic marker with evidence).

**Workaround.** Browsers fall back to system fonts
(`Charter, Iowan Old Style, Cambria` for serif; system
mono for code). Visual identity is recognisably Cambridge
Tract but slightly different. Until vendoring completes,
the site-test invariant "no CDN references" still holds —
fonts are *absent*, not *external*.

**Status.** Tracked under `math/site-design/` packet.
Once woff2 files are vendored under a `site-fonts-vendoring`
packet, the limitation should move to its own packet and
be retired.