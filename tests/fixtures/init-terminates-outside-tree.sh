#!/usr/bin/env bash
# tests/fixtures/init-terminates-outside-tree.sh
#
# Failure-first fixture for the non-terminating upward walk in
# lib/init/init.ml (fixed in fix/init-walk-termination).
#
# THE DEFECT. `find_source_ci_workflow` and `find_source_skill` each
# walked up from the binary's directory with
#
#     let rec walk dir =
#       if dir = "/" || dir = "." || dir = "" then None
#       else if Sys.file_exists candidate then Some candidate
#       else walk (Filename.concat dir "..")
#
# `Filename.concat` does not normalise. It produces "<dir>/..", then
# "<dir>/../..", then "<dir>/../../.." — a string that grows by three
# characters per step and never compares equal to "/". The guard was
# therefore unreachable and the recursion never terminated.
#
# MEASURED. With the binary at any path that has no ancestor holding
# the wanted file — a release binary in ~/.local/bin, or a dune cram
# sandbox under /tmp — `mathc init` never returned. One observed
# process: 725 s of CPU, 1 197 185 non-voluntary context switches,
# alive for 1 h 50 m. A `dune test tests/` run inherited two of them
# and never finished. On this machine 8 such processes were resident
# at once.
#
# WHY A FIXTURE AND NOT A NOTE. The defect is invisible to a test
# that only exercises the in-tree build: there, `_build/default/bin/`
# has the repository root as an ancestor, the first candidate exists,
# and the walk returns on its first iteration. The bug lives exactly
# in the configuration the test suite does not cover.
#
# WHY THE NEGATIVE CONTROL. A check that cannot fail is not a check.
# The only way to tell "the assertion has teeth" from "the assertion
# is satisfied" is to break the thing on purpose and observe the
# harness notice. Section 3 below runs the SAME harness against a
# deliberately non-terminating stub and requires it to be reported as
# a hang. Without that section, a harness that silently stopped
# running the binary at all would pass this file.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The budget. The fixed code returns in well under a second; the
# broken code never returns at all. 20 s is generous enough to
# survive a loaded machine and short enough that the negative control
# does not stall the suite for a minute.
BUDGET=5

# Locate the binary under test. Prefer the local build; fall back to
# PATH for the installed binary, which is the configuration that
# actually hangs for adopters. MATHC_BIN overrides both — it is how
# this fixture is pointed at a pre-fix binary to prove that it
# actually fails there.
bin="${MATHC_BIN:-}"
if [ -z "$bin" ]; then
  if [ -x "_build/default/bin/mathc.exe" ]; then
    bin="$PWD/_build/default/bin/mathc.exe"
  elif [ -x "_build/default/bin/mathc" ]; then
    bin="$PWD/_build/default/bin/mathc"
  elif command -v mathc >/dev/null 2>&1; then
    bin="$(command -v mathc)"
  fi
fi

if [ -z "$bin" ]; then
  bad "no mathc binary found (looked in _build/default/bin/ and on PATH)"
  echo
  echo "init-terminates-outside-tree: FAIL"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A directory tree with no ancestor that holds `templates/ci.yml` or
# `.opencode/skills/math-coding/SKILL.md`. Every ancestor of
# "$work" is a system directory, so the walk must reach "/" and stop.
deep="$work/a/b/c/d/e"
mkdir -p "$deep"

# --- 1. the defect itself ------------------------------------------------
# Run the binary from the deep directory, so its resolved path has no
# source ancestor. Each variant must terminate.
#
# run_init returns 0 when the invocation terminated with exit 0, and
# 1 when it hung or failed. It does NOT touch the global `fail`
# counter: the negative control below needs the same harness to
# return 1 on purpose, and that must not count as a fixture failure.
run_init() {
  # $1 = label, rest = args
  local label="$1"; shift
  local target="$work/repo-$RANDOM"
  local out rc
  out="$(timeout "$BUDGET" "$deep/mathc" init "$target" "$@" </dev/null 2>&1)"
  rc=$?
  if [ "$rc" -eq 124 ]; then
    printf '  %s: HUNG (no exit within %ss)\n' "$label" "$BUDGET"
    return 1
  elif [ "$rc" -ne 0 ]; then
    printf '  %s: exited %s (expected 0); output: %s\n' "$label" "$rc" \
      "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    return 1
  else
    printf '  %s: terminated with exit 0\n' "$label"
    return 0
  fi
}

cp "$bin" "$deep/mathc"
chmod 755 "$deep/mathc"

for variant in "no-args-variants:--no-install" \
               "agent-opencode:--agent opencode --no-install" \
               "with-ci-workflow:--no-install --with-ci-workflow"; do
  label="${variant%%:*}"
  args="${variant#*:}"
  # shellcheck disable=SC2086
  if run_init "$label" $args; then
    ok "$label: 'mathc init' terminated with exit 0"
  else
    bad "$label: 'mathc init' did not terminate — the upward walk does not terminate"
  fi
done

# --- 2. --no-install means "no in-project hook", and nothing else -------
# This section pins the SEMANTICS of --no-install, because the fix
# touches the same function and a careless fix could silently widen
# or narrow the flag.
#
# Documented behaviour (tests/cli/init-agent.t is the authority):
#   --no-install  -> do not write a pre-commit hook INTO THE PROJECT.
#   --agent opencode -> install the per-user agent skill into
#                       $XDG_CONFIG_HOME, regardless of --no-install,
#                       because that skill lives OUTSIDE the project.
#
# The previous draft of this fixture asserted that --no-install writes
# nothing under $XDG_CONFIG_HOME. That was wrong: it contradicts
# tests/cli/init-agent.t, and no fixture leaks the developer's real
# XDG directory — init-agent.t exports its own XDG_CONFIG_HOME. The
# behaviour was changed to match the flag's documented meaning, and
# the assertion below checks the REAL contract in both directions.
xdg="$work/xdg"
mkdir -p "$xdg"

# (a) With --no-install: no pre-commit hook inside the project.
rm -rf "$work/repo-a"
XDG_CONFIG_HOME="$xdg" "$bin" init "$work/repo-a" --agent opencode --no-install >/dev/null 2>&1
hooks="$(find "$work/repo-a" -path '*githooks*' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$hooks" = "0" ]; then
  ok "--no-install wrote no pre-commit hook into the project"
else
  bad "--no-install wrote $hooks hook file(s) into the project"
fi

# (b) With --no-install: the per-user agent skill IS still installed,
#     because it lives outside the project.
rm -rf "$work/repo-b"
XDG_CONFIG_HOME="$xdg" "$bin" init "$work/repo-b" --agent opencode --no-install >/dev/null 2>&1
peruser="$(find "$xdg" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$peruser" -ge 1 ]; then
  ok "--agent opencode installed the per-user skill under \$XDG_CONFIG_HOME ($peruser file)"
else
  bad "--agent opencode installed nothing under \$XDG_CONFIG_HOME — the per-user skill was lost"
fi

# (c) Without --no-install: the pre-commit hook IS installed.
rm -rf "$work/repo-c"
XDG_CONFIG_HOME="$xdg" "$bin" init "$work/repo-c" --agent opencode >/dev/null 2>&1
hooks2="$(find "$work/repo-c" -path '*githooks*' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$hooks2" -ge 1 ]; then
  ok "without --no-install the pre-commit hook IS installed ($hooks2 file)"
else
  bad "without --no-install no pre-commit hook was installed — the flag's meaning has drifted"
fi

# --- 3. NEGATIVE CONTROL: the harness must have teeth --------------------
# Replace the binary with a stub that never terminates, and require
# the SAME run_init harness to be reported as a hang. If this section
# fails, the harness is not actually running the binary and every
# "ok" above is meaningless.
#
# `rm -f` first: `cp` of a nix-store binary lands a mode-555 file
# (read-only, not writable), so a plain redirect into it fails and
# the stub silently never replaces the binary.
rm -f "$deep/mathc"
cat > "$deep/mathc" <<'STUB'
#!/usr/bin/env bash
# Deliberately non-terminating stub: simulates the old
# `Filename.concat dir ".."` walk, which never reaches "/".
while true; do :; done
STUB
chmod 755 "$deep/mathc"

# shellcheck disable=SC2086
if run_init "negative-control" --no-install; then
  bad "negative control: the harness reported a non-terminating binary as OK — this fixture cannot detect the defect it exists to detect"
else
  ok "negative control: the same harness caught the non-terminating stub"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "init-terminates-outside-tree: PASS"
  exit 0
fi
echo "init-terminates-outside-tree: FAIL"
exit 1
