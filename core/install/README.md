# core/install/

Brownfield installer: copy math-coding into an existing
project. Three scripts: install, upgrade, uninstall.
One test script: install-smoke-test.

## Quick start

```sh
# Install into an existing project
sh /path/to/math-coding/math-coding install /path/to/project

# Verify the install
cd /path/to/project
sh ./.math-coding/math-coding probe

# Upgrade an existing install
sh /path/to/math-coding/math-coding upgrade /path/to/project

# Uninstall
sh /path/to/math-coding/math-coding uninstall /path/to/project
```

## What install.sh does

1. Creates `<target>/.math-coding/`
2. Copies `core/`, `theories/`, `docs/`, `math/`,
   `math-coding` (the dispatcher) into `.math-coding/`
3. Creates `<target>/.mathrc` if absent
4. Adds `.math-coding/` to `<target>/.gitignore` if absent

The installed copy contains **the same files** as the
source repository. axiom A6 (Self-Application) is
verified in the copy by `sh .math-coding/math-coding probe`.

## What upgrade.sh does

1. Removes old `.math-coding/`
2. Re-installs from current source
3. Preserves `<target>/.mathrc` (user config)

## What uninstall.sh does

1. Removes `<target>/.math-coding/`
2. Preserves `<target>/.mathrc` (user config)
3. Removes `.math-coding/` from `<target>/.gitignore`

## What install-smoke-test.sh does

A hermetic test: creates a tmp directory, runs install,
verifies axiom A6 in the copy, runs uninstall, cleans up.
The test runs in `tests/run.sh` (Case 16) and in CI.

## .mathrc fields

The default .mathrc is:

```
mode: standard
role: developer
lookahead_ok: 0
```

Override fields as needed:

```
mode: strict          # light | standard | strict
role: researcher     # developer | designer | product-manager | researcher | tech-writer
lookahead_ok: 1     # 0 | 1
```

## What install does NOT do

- Does not modify the source repository
- Does not require network access
- Does not install dependencies (axiom Material Basis)
- Does not run axiom A6 in the source (it runs in the copy)

## See also

- `core/install/install.sh` — the script
- `core/install/upgrade.sh` — the script
- `core/install/uninstall.sh` — the script
- `core/install/install-smoke-test.sh` — the test
- `math/brownfield-install-cycle-test/` — the test packet