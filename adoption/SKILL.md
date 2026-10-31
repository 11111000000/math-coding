---
name: math-coding
description: |
  Apply the math-coding assurance protocol in a project. Use when the
  user says "примени math-coding", "set up math-coding", "start tracking
  decisions", "we need an audit trail", or mentions obligations,
  attestations, or waiver in a project context. Do not trigger on casual
  uses of "decision" or "obligation" in ordinary conversation.
compatible_with: mathc@>=3.7.4
MC_VERSION=3.7.4
---

# math-coding

Math-coding binds every change to a written commitment, a list of
obligations, and bounded evidence. The kernel (`mathc`) checks that
nothing is silently promoted from `unknown` to `pass`.

What it proves, exactly: a commitment was written down, somebody
signed for it, and the evidence named a tree. What it does not prove:
that the software is correct, or that the commitment was met. Read
Step 4 before you sign anything — it is the difference between a trail
and a receipt — and Known defects before you trust a scaffold.

## When to apply

Default: apply. `mathc init` prints the envelope it assumed: Path A,
installed by default, a single maintainer included. Per
`spec/kernel-contract.md` §28 the burden of proof sits on the exclusion,
not on the adoption: to skip, the project must be throwaway (a
prototype, MVP, spike, one-day hackathon), and the rationale goes in
the README, per §23.

What raises the ceremony above the cheapest rung (`mode_floor: light`):

- two or more AI agents (or humans) edit the same repository;
- regulatory or contractual audit needs a tamper-evident trail;
- three or more maintainers on a five-or-more-year horizon;
- an AI agent writes into the repository, even with one human. Code
  you did not write is code you cannot recall; the counterexample
  paragraph is where you find out it was wrong.

Raise the floor with `mode_floor: <mode>` in the project's
`policies.yaml`. Without that file the kernel uses its lowest rung
(Tiny) — cheaper than light, not more expensive.

### Where the rule lives

The applicability rule has one home: `spec/kernel-contract.md` §28. This
skill states the operational instruction and points there; it does not
carry a second copy of the rule. If the two ever disagree, §28 wins
and the disagreement is a bug in the corpus, not a choice you get to
make.

## What the protocol costs (measured)

The project's own adoption experiment (2026-10-17, five external
projects: click, express, cobra, ripgrep, sinatra) is in
`docs/experiments/adoption-2026-10.md`:

- time to first decision: median ~4 min, worst ~14 min;
- with-protocol session: median ~10 min; control arm ~3 min;
- three of eight hypotheses refuted (H3 schema coverage, H4
  throughput, H8 attest-batch);
- the 10-vs-3 gap was dominated by a path-resolution defect, not by the
  method. Once the layout was locked, per-decision overhead fell to
  ~1-2 min.

Ten minutes buys a trail a regulator or a second agent will read. It
buys nothing for a script nobody reads twice — which is why §28 has one
exclusion class instead of a philosophy.

> For a three-command quickstart of the whole adoption, see
> [QUICKSTART.md](QUICKSTART.md). For the ten-minute path from an empty
> repository to a green gate, see
> [docs/adoption-quickstart.md](../docs/adoption-quickstart.md).

## Step 1. Install the kernel

```bash
# Single-line install (default tag is the rolling 'edge' prerelease).
# The script verifies SHA-256 of the downloaded binary against
# SHA256SUMS on the same release. To pin a specific tag, pass
# --version=<X>; to also install the per-user opencode skill, pass
# --user-skill.
curl -fsSL https://github.com/11111000000/math-coding/releases/download/edge/install.sh \
  | sh -s -- --user-skill
export PATH="$HOME/.local/bin:$PATH"
mathc version
```

For Docker, Nix, a source build, or Alpine/musl, see USAGE.md
§Install and QUICKSTART.md.

**The version trap.** `mathc version` prints `math-coding <X>: bootstrap`
and does not identify the build: two different binaries both report
`3.7.4`. Discriminate by behaviour instead — after Step 3 the scaffold
must carry `schema: math-coding/3.3` and an `axiom_link:` block. A
scaffold with `schema: math-coding/3.2` and no `axiom_link` comes from
a binary older than 2026-10-26, whose default template the kernel
rejects; reinstall from the `edge` tag and check again.

## Step 2. Bootstrap the repository

```bash
mathc init .
```

Creates `.math-coding/decisions/`, `.math-coding/attestations/`,
`.math-coding/policy.yaml`, and (unless `--no-install`) the
`.githooks/pre-commit` hook, then prints the applicability envelope it
assumed. `mathc init` cannot observe team size, agent count, or audit
obligations — it prints the envelope, it does not detect it. You raise
or lower the floor yourself, in `policies.yaml`.

`mathc init --merge` is wired: it keeps an existing master policy and
proceeds with the rest of the scaffold. It does not migrate or delete
a legacy `decisions/` + `attestations/` tree — the resolver prefers
`.math-coding/` when it exists and falls back to the legacy layout
when it does not, so both coexist until you remove one.

To point the kernel at the legacy layout explicitly:

```bash
export MATH_CODING_DECISIONS_DIR=decisions
export MATH_CODING_ATTESTATIONS_DIR=attestations
export MATH_CODING_POLICY=decisions/decision.yaml
```

The env var wins over the filesystem, and the resolver never consults
the disk for it. This is what the hermetic tests use.

## Step 3. First decision

```bash
mathc new-decision my-id --write
```

The scaffold is a stub: fill in the TODO markers. Keep the shape — the
kernel reads these keys:

```yaml
---
schema: math-coding/3.3
id: <id>
revision: 1
state: active
mode: light

intent: |
  One paragraph. What should become true after this decision lands?

commitment: |
  Two sentences max. What is promised. If you cannot phrase it in two
  sentences, the decision is not ready.

outcomes:
  - id: <outcome-id>
    statement: |
      One sentence. The observable property this decision delivers.

scope:
  paths:
    - "<path/glob/that/this/decision/touches/**>"

obligations:
  - id: <obligation-id>
    claim: |
      One sentence. What the kernel or fixture can verify.
    acceptance:
      all:
        - verifier: <fixture-path-or-kernel-verifier>

axiom_link:
  - A0

counterexample: |
  The strongest plausible case where this decision is wrong, and what
  would change your verdict. One paragraph.

risk:
  declared_triggers:
    - <what-could-go-wrong>
  owner: <human:role or human:name>

relations:
  addresses:
    - bootstrap-v3@3
```

`axiom_link` is required whenever `state: active`; an empty one is
MC-AXIOM-LINK-MISSING, a block. `mode` decides what the dialectic
costs you:

| mode | counterexample | antithesis |
|---|---|---|
| tiny, light | optional (soft warning) | optional |
| standard, strict, exhaustive | required (block, exit 1) | optional |
| considered | required (block) | required |

An empty counterexample at mode >= standard is MC-COUNTEREXAMPLE-MISSING
(a block); at light it is a warning and the verdict stays accept. Do
not read "the kernel accepts it" as "the counter-case was considered":
at light, nothing checks that the slot was filled in honestly. That is
what the mode floor is for.

After editing, restamp the digest — the kernel validates the file's own
bytes, and a scaffold's digest is stale the moment you type:

```bash
mathc rehash --write .math-coding/decisions/my-id.yaml
mathc validate .math-coding/decisions/my-id.yaml
```

On a non-zero exit the stderr line starts with an `MC-*` code; run
`mathc explain-diagnostic <CODE>` for the definition, when it occurs,
and the remediation.

## Step 4. Evidence — the part that decides what the trail is worth

An attestation says "this obligation held at this tree". It is worth
exactly what produced it.

Order matters: the kernel refuses an attestation whose tree is not
anchored to a commit, so `attest-batch` before the first commit exits 2
("refusing to write an attestation with an unanchored candidate_tree").

The honest path — execute the verifiers:

```bash
git add -A && git commit -m "feat: ..."
mathc attest-batch --from=decisions --kind=test --producer=ci:<name> \
  --run-per-obligation
mathc self-check
```

`--run-per-obligation` runs each obligation's own verifier (the same
strings `mathc verify` executes) and signs its verdict. A verifier the
kernel cannot execute yields `inconclusive`, the obligation stays
`skipped`, and `self-check` reports `unknown` with exit 3. That is the
correct outcome, not a problem to work around.

Two flags that keep the trail honest:

- `--skip-failing` leaves a failing obligation unsigned instead of
  overwriting a good signature;
- `--only-changed` re-signs only the obligations whose scope
  intersects the changed files. Under semantics A a scope change
  invalidates the attestation that covered it, so a commit that touches
  a scope must re-sign it.

Do not sign for a human. `--producer=human:me` writes `result: pass`
with an empty materials digest — the digest of nothing, which is the
freshness wildcard: that attestation is fresh for every tree, for ever,
and no change can invalidate it. A hand-written attestation JSON with
`"result": "pass"` is the same laundering in a different shape. If you
are an agent, sign as an agent (`--producer=agent:<name>`) and let the
verifier produce the verdict.

Check what is still open:

```bash
mathc gaps
```

`gaps` lists every promise that is declared, unknown, or waived, with
the class of its check and what to do about it. Run it after signing.
The difference it shows is the whole difference between a trail and a
receipt: an obligation whose verifier is a placeholder is reported as
`not-a-check` / `unknown` ("write the check, cover the gap with a dated
waiver, or drop the promise"), while a review attestation with no
executed verifier closes it and the promise disappears from the list.

## Step 5. The gate

```bash
mathc self-check
```

- exit 0, `"verdict": "pass"` — every decision has a current
  attestation reporting pass;
- exit 3, `"verdict": "unknown"` — the kernel cannot conclude: no
  decision yet, or an attestation that is inconclusive. The `causes`
  and `remedies` arrays name the obligation;
- exit 1 — a decision is rejected; `mathc validate <file>` and
  `mathc explain-diagnostic <CODE>` give the remediation.

`unknown` is the honest state. The kernel will not promote it, and
neither should you.

## What the kernel refuses

- **missing result** — a decision without `obligations[]`;
- **missing obligation** — an obligation without `acceptance.verifier`;
- **missing fixture** — a verifier naming a path that does not exist;
- **missing authority** — a protected-policy transition not under the
  previously active policy;
- **missing expiry** — a waiver without `expires_at`.

`unknown`, `waived`, and `reviewed` are not `pass`.

## Known defects in this release

Verified against the build of 2026-10-30. Each one is a reason to
check, not a reason to skip.

1. **The scaffold is not valid YAML for strict parsers.** The emitted
   stub contains an unquoted `<TODO: fixture-path-or-kernel-verifier>`;
   PyYAML stops on it ("mapping values are not allowed in this
   context"). The kernel's own reader is lenient and `mathc validate`
   answers `parse-ok`. If your tooling reads decision files with a
   strict parser, quote the verifier placeholder before filling it in.
2. **The scaffold's `risk` block is swallowed.** In the same stub the
   `risk:` key is indented under the `counterexample` block scalar, so a
   strict parser reads the trigger and the owner as part of the
   counterexample text and the decision has no `risk` at all. The
   kernel then defaults the owner to `human:maintainer`, and your
   `declared_triggers` are silently gone. Fix the indentation after
   scaffolding and confirm `risk.owner` and `risk.declared_triggers`
   are really there.
3. **`mathc validate` accepts a scaffold full of TODOs.** It checks
   shape, not content: intent, commitment, outcome and verifier may
   all still be placeholders and the verdict stays `accept`. A green
   validate is not a decision.
4. **The scope placeholder is the freshness wildcard.** A decision
   whose `scope.paths` names no real file has an empty materials
   digest, so its attestation never goes stale. Replace the placeholder
   with the paths the decision actually covers; the scaffold warns
   about this at write time.
5. **Two binaries report the same version.** See Step 1.

## Files you touch

Only these, in the target repository:

- `.math-coding/decisions/*.yaml` — the commitments;
- `.math-coding/attestations/*.json` — the evidence;
- `.math-coding/policy.yaml` — the active policy;
- `policies.yaml` — the mode floor you declare (optional).

The kernel parses by hand and reads no JSON-Schema file, so a
brownfield repository needs no `schemas/` on disk for `mathc validate`
to work. Do not read or edit `spec/`, `axioms/`, `lib/`, or the
kernel's own internal documentation while adopting the protocol in
another project.

## Deploy this skill to your platform

This file is the canonical source. `scripts/dist-adoption.sh` renders
the platform drops into `dist/adoption/<platform>/`; they are build
artifacts, not sources.

| Platform | Target path |
|---|---|
| opencode | `.opencode/skills/math-coding/SKILL.md` |
| Claude Code | `CLAUDE.md` (merge snippet) or `.claude/instructions.md` |
| Cursor | `.cursor/rules/math-coding.md` |
| GitHub Copilot | `.github/instructions/math-coding.instructions.md` |

The in-repo OpenCode copy must stay byte-for-byte identical to this
file (`scripts/check-opencode-skill.sh`). If the agent session is
read-only, ask the user to copy the file from `dist/adoption/<platform>/`
into the path above.

## MCP integration

`mathc_mcp` is a JSON-RPC 2.0 server over stdio, shipped beside the
binary. Fourteen methods:

- read-only (10): `validate`, `explain`, `packages`, `mode`,
  `re-evaluate`, `rebuttals`, `self-check`, `find`, `precommit`,
  `graph`;
- read-write (4): `gate`, `attest`, `record`, `re-evaluate-decisions`.

One request per line on stdin, one response per line on stdout; stderr
is diagnostics; EOF on stdin exits 0. Launch it directly:

    ~/.local/bin/mathc_mcp

An MCP-aware agent (opencode, Claude Code, Cursor) can launch this
binary as a stdio MCP server and see `mathc::validate` and the rest as
direct tool calls, without a `bash` round-trip.

Set `MCP_READ_WRITE=off` to disable the four write methods; they then
answer `-32601 Method not found` and the read-only ten keep working.
The default (env unset) keeps all fourteen reachable. The server prints
one line to stderr when the write methods are off.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `MATH_CODING_DECISIONS_DIR` | `.math-coding/decisions` | Where the kernel reads and writes `*.yaml` decisions. Set it to `decisions` for the legacy layout. |
| `MATH_CODING_ATTESTATIONS_DIR` | `.math-coding/attestations` | Where the kernel reads and writes `*.json` attestations. |
| `MATH_CODING_POLICY` | `.math-coding/policy.yaml` | Master policy path consulted by `mathc validate` and `mathc self-check`. |
| `MATH_CODING_HOME` | `$XDG_DATA_HOME/math-coding/<version>` | System-wide templates and schema directory (planned for v3.5; not consulted at runtime). |

Precedence in the resolver: the env var wins unconditionally (no
filesystem check); otherwise the new-default path if it exists; otherwise
the legacy fallback; otherwise the new-default path, synthesised.

## Backward compatibility

Projects bootstrapped against a 3.0–3.3 release — `decisions/` and
`attestations/` at the repo root, master policy at
`decisions/decision.yaml` — keep working with no configuration change:
the resolver prefers `.math-coding/...` when it is present and falls
back to the legacy layout when it is not; no migration, no rename, no
deprecation warning. `mathc init` on a project that already has
`decisions/` emits a clean tree under `.math-coding/` and leaves the
legacy tree in place — they coexist until you remove one.

To opt into the legacy layout explicitly:

```bash
export MATH_CODING_DECISIONS_DIR=decisions
export MATH_CODING_ATTESTATIONS_DIR=attestations
export MATH_CODING_POLICY=decisions/decision.yaml
mathc validate decisions/<id>.yaml
```
