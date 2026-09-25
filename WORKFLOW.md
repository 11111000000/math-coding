# How to work with math-coding

## Daily flow

### 1. Before recording a non-trivial decision

Create a packet **before** the code is written. This is the
curry-howard aspect: the proposition (type) precedes the code (term).

```sh
mathc record my-decision "a single-sentence proposition"
git add math/my-decision/ && git commit -m "my-decision: short description"
mathc amend my-decision
git add math/my-decision/witness && git commit -m "my-decision: witness"
```

After this, `mathc check` shows `applied ✓`.

### 2. When the proposition changes

Never edit `packet.md` after `witness`. Use supersession:

```sh
mathc supersede my-decision my-decision-v2 "new proposition"
git add math/my-decision/ && git commit -m "v2: new proposition"
mathc amend my-decision-v2
git add math/my-decision-v2/witness && git commit
```

The old chain is preserved in git history. The kernel verifies that
`superseded_by: my-decision-v2` points to an existing packet.

### 3. Search and navigation

```sh
mathc find TTL                       # find packets by substring
mathc grep "cache"                   # grep over proposition and name
mathc show my-decision               # show the full packet
mathc list                           # all packets
mathc history my-decision            # packet history
mathc graph my-decision              # mermaid supersession chain
```

### 4. Status check

```sh
mathc check                          # check all packets
mathc status --json                  # JSON: state and next steps
mathc stats                          # metrics (drift rate, applied/total)
```

## Brownfield: migrating an existing project

### Step 1. Install

```sh
nix develop --command sh scripts/install.sh
# or
opam switch create 5.2.0 && opam install dune
sh scripts/install.sh
```

The binary lands at `$XDG_DATA_HOME/math-coding/current/mathc`. The
`./mathc` wrapper at the project root points to it.

### Step 2. Initialise

```sh
mathc init
```

Creates `math/`, `.mathrc`, and installs the pre-commit hook.
Existing files are left untouched.

### Step 3. Authorise existing code

For legacy code, create one packet:

```sh
mathc record legacy-code "Existing code is authorised as legacy: <short description>"
git add math/legacy-code/ && git commit -m "legacy-code: authorisation"
mathc amend legacy-code
git add math/legacy-code/witness && git commit
```

This packet serves as a marker: "everything that existed before the
convention is considered authorised as legacy."

### Step 4. New decisions

Each new architectural decision becomes its own packet:

```sh
mathc record my-decision "..."
git add . && git commit
mathc amend my-decision
```

### Step 5. Gradual expansion

Old important decisions can be retroactively turned into packets.
Not all at once is fine. The convention itself will hint, through
`mathc status`, which packets are missing for existing decisions.

## Configuration: `.mathrc`

```yaml
# Signing mode
SIGNING_MODE: lenient    # strict | lenient | off

# Automation
AUTO_AMEND: true         # record → auto-amend after commit
AUTO_RECORD_PROMPT: true # agent proposes creating a packet

# Substrate
SUBSTRATE_DEFAULT: none

# Lifecycle
STRICT_DRIFT_CHECK: false # strict = Fail on drift; lenient = Warn

# Schema
SCHEMA_VERSION: "2.0"

# Plugin (for future legacy)
PLUGINS: ["v2.0"]

# Output
DEFAULT_JSON: false
```

## Pre-commit hook (auto-installed)

`mathc init` installs `.git/hooks/pre-commit`:

```sh
#!/bin/sh
exec mathc check --staged --strict
```

On every commit, the staged packets are checked. Drift is detected
automatically before reaching git.

## Evolving the convention

### Updating frontmatter (new fields)

When the convention adds a new mandatory field:

```sh
mathc migrate-convention
```

It analyses every packet, adds new fields with defaults, and does not
touch existing proposition/witness. It creates a commit titled
"convention: migration".

### Format evolution (new schema_version)

When the convention requires a new schema version:

```sh
# mathc migrate --from=v2.0 --to=v3.0 (deferred until v2.0.1)
```

Legacy plugins will be added in v2.0.1+ for brownfield migration
from v1.0/v0.99/v0.854.
