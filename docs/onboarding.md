# Onboarding math-coding into an existing project

This guide describes how to adopt math-coding in a production
project — a web service, a compiler, a kernel module, anything
with native code structure.

## Prerequisites

- A working project with code (in any language)
- `sh`, `awk`, `grep`, `sed`, `find`, `git` available
- No other tools required (math-coding is plain text + git)

## Step 1: Decide where packets live

Default: `specs/`. Alternative: `math/`. The choice matters
because your team will type this path often.

Create `.mathcodingrc` at the project root:

```yaml
# .mathcodingrc
packets_dir: specs           # or: math
convention_version: 2.1.0    # tracks math-coding version
```

The schema is in
`schemas/project-config.schema.json` (in the math-coding repo).
If you do not create `.mathcodingrc`, math-coding uses
`specs/` by default.

## Step 2: Install math-coding

Run the install script from the project root:

```sh
sh /path/to/math-coding/install/install.sh
```

This creates `./specs/` (or `./math/`) with:

- `core/` — the convention
- `01-Theory/` — eight mathematical foundations
- `schemas/` — JSON Schema files
- `verify-consistency.sh` — the structural verifier

No other files are copied into your project. Your code stays
untouched.

## Step 3: Connect to your AI agent

If you use Cursor, copy `.cursorrules` from the math-coding
repo into your project root.

If you use opencode, copy `.opencode/` (with `AGENTS.md`,
`commands/`, `skills/`) into your project root.

The agent will then read math-coding instructions when
working on your project.

## Step 4: Open your first packet

Run:

```sh
sh .opencode/commands/mathpacket my-first-feature
```

This creates `specs/my-first-feature/` with the boilerplate
files (`packet.yaml`, `task.md`, `assumptions.yaml`,
`refinement.md`, `traceability.json`).

Fill in:

- `task.md` — what the feature is, what problem it solves,
  what constraints it has
- `assumptions.yaml` — four or more assumptions, each with
  an epistemic marker
- `packet.yaml` — owner, priority, tags

The packet starts at `lifecycle: sketch`.

## Step 5: Decide rigor

If your feature is a simple bug fix or refactor, `light`
rigor is enough. The structural verifier will check shape
and FSM transitions.

If your feature is a state machine, a protocol, or anything
concurrent, consider `temporal` rigor: write `Model.tla` and
`verify-tlc.sh`. See `agents/rigor-tools.md` for guidance.

For most projects, `light` is the default. Add rigor when
the cost of bugs is high.

## Step 6: Write code, link it to the packet

Your code lives in `src/`, `tests/`, or wherever your
project puts it. The packet is the **specification**; the
code is the **implementation**.

Link them explicitly through:

- `refinement.md` — describe the state and operation mapping
  from spec to code. Where in `src/` does each spec action
  live? Where in `src/` does each invariant get checked?
- `traceability.json` — record the file paths and line
  numbers. Each `link` connects a packet section to a
  concrete source location.

Without these, the packet is a design document with no
link to the running code. With them, the packet is a
**proof term** that points to where the proof is realized.

## Step 7: Run the verifier and promote

Run the structural verifier:

```sh
sh specs/verify-consistency.sh
```

If the verdict is VERIFIED, set `lifecycle: verified` in
`packet.yaml` and update `verifier`:

```yaml
lifecycle: verified
verifier:
  command: sh verify.sh
  verdict_file: verifier-output.yaml
```

The verifier produces `verifier-output.yaml` automatically
with provenance fields (`verdict`, `verified_at`, `scope`,
`tool`, `evidence`).

## Step 8: Add to CI

Add this to your CI pipeline:

```sh
sh specs/verify-consistency.sh
```

A failing verifier blocks the merge. A passing verifier
keeps the convention enforced.

## What you do NOT need to do

- **Do not move your source code into the packets directory.**
  The packet is a specification, not a code wrapper. Your
  code keeps its native structure.
- **Do not turn every file in your project into a packet.**
  ADR-0006 ("every artifact is a packet") applies to the
  math-coding repository itself, not to projects that use
  math-coding.
- **Do not use advanced theories (09-11) unless you adopt
  `rigor: proof+`.** They are documented in
  `core/02-Theory-advanced/` but are not part of the basic
  convention.

## When the convention version changes

The math-coding repo is versioned (e.g., `v2.1.0`, `v2.2.0`).
When the version changes:

1. Update `.mathcodingrc: convention_version`.
2. Read the `CHANGELOG.md` for breaking changes.
3. Run the verifier on every packet; some packets may need
   updates to match the new convention.
4. The convention-version change **does not automatically
   revert** your `verified` packets; you decide when to
   re-verify.

## When the project scales

When the project has 10+ packets, consider:

- Tagging packets with `tags:` in `packet.yaml` for filtering
- Using `depends_on:` to express packet dependencies
- Adding rigor to high-stakes packets (financial,
  security, safety-critical)
- Documenting cascade responses in `task.md` when packets
  depend on deprecated ones

The convention scales through clarity, not through tooling.