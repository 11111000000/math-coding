# math-coding v1.0

> Curry-Howard convention for AI coding agents, v1.0.
> Plain text. Git. Single OCaml binary.

## What this is

A convention where every non-trivial decision is a **packet** —
a directory containing `packet.md` (proposition, antithesis,
synthesis) and `witness` (SHA history). The OCaml binary verifies
packet structure, lifecycle, witness history, and epistemic
markers. The convention applies to itself (axiom Self-Application).

## Seven axioms

  A0. Difference        A4. Process
  A1. Care              A5. Accounting
  A2. Curry-Howard      A6. Self-Application
  A3. Material Basis

Read `docs/axioms.md` for full statements.

## Packet

```
math/<name>/
├── packet.md        # YAML frontmatter + Markdown body
├── witness          # YAML list of witness entries
├── run.sh           # only if substrate: shell
├── properties/      # only if substrate: pbt
├── tla/             # only if substrate: tla+
├── coq/             # only if substrate: coq
├── alloy/           # only if substrate: alloy
└── bpmn/            # only if substrate: bpmn
```

The packet lifecycle is **computed** from git history:

```
draft       — no witness
applied     — witness + files in witness commit
drift       — proposition changed after witness
stale       — files changed but proposition same
retired     — explicit retire (via CLI)
abandoned   — explicit abandon (via CLI)
```

Optional `status:` field in frontmatter overrides the computation.

## Eight substrates

LLM chooses one based on `docs/substrate-decision-rules.md`:

```
none    shell    pbt    tla+    coq    alloy    bpmn    pbt-prism
```

v1.0 implements real verification for `none / shell / pbt`. Other
substrates report `tool not installed, SKIP`.

## Five epistemic markers

```
fact        hypothesis        judgment        unknown        proven
```

`proven` requires reproducible evidence. Verify re-runs the
recorded command and compares exit code. On mismatch, marker
demotes to `hypothesis`.

## Quick start

```bash
# 1. Install
sh scripts/install.sh
# → builds OCaml binary, installs to $XDG_DATA_HOME/math-coding/

# 2. Create a packet
math-coding packet create cache-ttl \
  --proposition="Cache entries expire after 60 seconds" \
  --antithesis="Manual invalidation forces users to wait" \
  --synthesis="TTL is fixed; manual invalidate is /admin/cache"

# 3. Implement in code
# 4. Commit
git add . && git commit -m "cache-ttl: 60s TTL"

# 5. Verify
math-coding check

# 6. Probe (axiom Self-Application)
math-coding probe
```

## Install in an existing project

The OCaml binary lives at `$XDG_DATA_HOME/math-coding/<ver>/`. Each
project uses the same binary via wrapper:

```bash
# In your project root:
ln -s "$XDG_DATA_HOME/math-coding/current/math-coding" ./math-coding
# Or call directly:
$XDG_DATA_HOME/math-coding/current/math-coding check
```

## Build

```bash
opam install . --deps-only
dune build --profile=release
dune test
```

## License

Living Beings License — see LICENSE.
