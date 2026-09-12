# shared-install-v0993

## Thesis

  math-coding runtime payload lives once at `$XDG_DATA_HOME/math-coding/<ver>/`, projects carry only a 25-line wrapper plus `math/` and `.mathrc`.

## Antithesis

  CI runners and sandboxed agents often run without a cached `$HOME/.local/share`, so the first invocation in a fresh container pays the full cost and breaks hermetic builds. Shared install assumes writable home; on read-only filesystems the wrapper cannot bootstrap.

## Synthesis

  Default install writes payload to `$XDG_DATA_HOME/math-coding/<ver>/`, exposes it through a `current` symlink, and writes a 25-line wrapper + `.mathrc` + `math/` into the project. The wrapper resolves `current` first, falls back to in-repo `.math-coding/` (legacy local layout), and prints a clear error with the install command if both are absent. `install --local` preserves the legacy in-repo copy for hermetic CI and sandboxed runners.

## Surface impact

  - core/install/install.sh (writes to shared layout)
  - core/install/install-skill.sh (uses new layout for skill payload)
  - core/install/upgrade.sh, uninstall.sh (symlink-aware)
  - core/install/install-smoke-test.sh (resolves dispatcher via wrapper)
  - core/author/lifecycle.sh (collapses apply/retire/review/abandon into one)
  - math-coding (project wrapper, ~25 lines)
  - KNOWN_LIMITATIONS.md (drop --gitignore default, document shared layout)
  - core/lib/common.sh (no longer derives REPO_ROOT from disk layout)

## Proof

  Evidence is `sh core/install/install-smoke-test.sh`, which performs install + create + apply + review + verify + probe + uninstall against a fresh tmp directory and exits 0. Before this change the test exercised in-repo `.math-coding/`; after this change it exercises the shared layout with a project-local wrapper. The same test runs in `tests/run.sh` (Case brownfield-install-cycle).
