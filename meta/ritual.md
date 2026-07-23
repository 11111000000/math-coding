# Spec ritual (math-coding v0.992)

Single-source-of-truth has a cost: every change to a source
file **must** trigger regeneration of derived artefacts.
This document specifies the ritual.

## When to run

After **any** change to:

  - `core/spec/axioms.md`
  - `core/spec/fsm.md`
  - `core/spec/packet-schema.md`
  - `core/spec/extensions.md`
  - `core/theories/*.md` (any of the 7)
  - `KNOWN_LIMITATIONS.md`
  - `extensions/agents/<agent>/SKILL.template.md`

## What to run

```sh
# Regenerate all generated artefacts (current agent: opencode)
sh meta/build-skill.sh opencode

# Verify freshness (CI-friendly)
sh meta/build-skill.sh opencode --check
```

## What gets checked

`meta/build-skill.sh --check` compares the **current SKILL.md**
against **template + sources**. If they differ, the script
exits 1.

Failure means: someone edited a source file but did not
regenerate SKILL.md. The fix is one command.

## Why this matters (axiom A2)

A packet is a proof term. The verifier is the type-check.

In our case:

  - `core/spec/axioms.md` is the **proposition** (what the
    convention asserts).
  - `extensions/agents/<agent>/SKILL.md` is the **proof
    term** (what the agent sees).

If the proof term diverges from the proposition, the agent
operates on stale axioms. axiom A2 (Curry-Howard) requires
the relationship to hold. The build-skill --check gate
enforces it.

## Who enforces

In source-repo: `meta/build-skill.sh --check` runs in CI
(`tests/spec-ritual.sh`). PR fails if stale.

In target install: `core/install/install-skill.sh` runs the
gate before copying payload. install fails if SKILL.md
in source is stale.

In agent runtime: the agent loads SKILL.md at session start.
After this, axiom A2 holds for the duration of the session.

## Failure modes

If `sh meta/build-skill.sh opencode` fails:

1. Check syntax: `sh -n meta/build-skill.sh`.
2. Check sources exist: `ls core/spec/axioms.md core/spec/fsm.md core/theories/`.
3. Check python3: `which python3`.
4. Check `extensions/agents/opencode/SKILL.template.md` has
   `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->`
   markers.
5. Re-read this ritual file.

If `--check` reports stale after a fresh build, the build
itself is broken. File an issue.

## The 5 files rule

The convention has its own "5-file packet" rule. The spec
ritual has a parallel rule for normative content:

  1. Edit `core/spec/*.md` or `core/theories/*.md` (source).
  2. Run `sh meta/build-skill.sh opencode` (derive).
  3. Verify `sh tests/run.sh` passes (test).
  4. Commit source + SKILL.md in one commit (witness).
  5. Push. CI runs --check (axiom A5).

Five steps, five files. Not coincidence. axiom A2.

## Versioning

The script reads sources by their file paths. There is no
version negotiation between sources — if you edit
`core/spec/axioms.md`, SKILL.md reflects that edit on
next build. Source SHAs in the AUTO-GENERATED header are
the witness (axiom A5).
