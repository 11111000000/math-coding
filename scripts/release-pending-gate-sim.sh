#!/usr/bin/env bash
# SC2030/SC2031 — every replay helper exports GITHUB_BASE_REF and
# GITHUB_OUTPUT INSIDE the `( ... )` that stands for one Actions step.
# Subshell-local is the intent: each step gets a fresh output file, and a
# leaked GITHUB_OUTPUT would let one row's verdict be read out of another
# row's file. Declared file-wide rather than per-line because the pairing
# is the point.
# shellcheck disable=SC2030,SC2031
# scripts/release-pending-gate-sim.sh — prove that the release-pending
# gate asks a question and that every way of not knowing the answer
# blocks.
#
# WHY THIS EXISTS
# ---------------
# `decisions/release-cadence-2026-11.yaml` ships the gate as a
# first-pass placeholder: it blocked any protected-path PR whenever
# `git tag --merged` on the base returned anything at all. Once a
# project has cut one release, every base ref has a tag merged into it
# forever, so that condition was permanently true and the gate blocked
# every protected-path PR from then on without ever once turning green.
# A gate that cannot pass is indistinguishable from a gate that is
# broken, and neither is a check.
#
# The gate now asks a question git can actually answer: is the base tip
# a commit that has been released as vX.Y.Z? So it has a passing case,
# a blocking case, and — the part that matters most — a set of "cannot
# tell" cases that must all BLOCK.
#
# Two properties make the replay trustworthy, and they are the same two
# `scripts/ci-step-exit-sim.sh` rests on:
#   1. every step body is read from `.github/workflows/release-pending.yml`
#      at run time, never copied into this script, so the simulation
#      cannot drift away from the workflow it checks;
#   2. bodies run under `bash --noprofile --norc -e -o pipefail`, the
#      same shell and the same errexit/pipefail environment GitHub
#      Actions gives a `run:` step on Linux. A gate's exit status is a
#      property of its environment, not of its text.
#
# SHARPNESS
# ---------
# A harness that cannot fail proves nothing, so this script carries its
# own two controls:
#   * MUTATION — the current body with its one "pass" condition forced
#     true. That is the smallest possible broken gate: it still reads
#     tags, still writes outputs, still runs, and no longer gates
#     anything. The harness MUST report a failure on it. If it does
#     not, every other row here is vacuous.
#   * PRE-FIX CONTROL — the placeholder body from ec05168, replayed
#     verbatim. It MUST block the released-base case, which is the
#     defect: a base that IS released is not a protected-path risk.
#
# Usage:  scripts/release-pending-gate-sim.sh [--verbose]
# Exit:   0 if every current-workflow row holds AND both controls fire;
#         1 otherwise.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

# The workflow under test. $RP_YML overrides it, same shape as $CI_YML in
# ci-step-exit-sim.sh, so the controls below can be pointed at any
# revision.
RP_YML="${RP_YML:-release-pending.yml}"
case "$RP_YML" in
  /*|.github/*) ;;
  *) RP_YML=".github/workflows/$RP_YML" ;;
esac
verbose=0
[ "${1:-}" = "--verbose" ] && verbose=1

REAL_GIT="$(command -v git)" || { echo "FAIL: no git on PATH" >&2; exit 1; }
# Exported, not just set: the shim below is written with a quoted heredoc
# (so its own "$@" and ${FAIL_GIT_SUBCOMMAND} survive verbatim) and is
# therefore evaluated by bash at RUN time, in a process that inherits only
# what was exported. An unexported REAL_GIT leaves the shim with an empty
# exec target, and every "broken git" row then fails for the wrong reason
# while still reporting the right exit code — a row that proves nothing.
export REAL_GIT

fail=0
pass_rows=0

# --- 1. extract the step bodies from the workflow -----------------------
#
# A block scalar `run: |` continues while lines are either blank or
# indented deeper than the `run:` key itself. The block's own indent is
# whatever its first non-blank line uses — that is what YAML strips, so
# deriving it rather than assuming two spaces keeps the extraction honest
# if the file is ever re-indented.
extract_step_body() {
  awk -v want="$1" '
    BEGIN { bodyind = -1 }
    index($0, "      - name: " want) == 1 { found = 1; next }
    found && match($0, /^ *run: \|$/) {
      inrun = 1
      match($0, /^ */); keyind = RLENGTH
      next
    }
    found && inrun {
      if ($0 ~ /^[[:space:]]*$/) { print ""; next }
      match($0, /^ */)
      if (RLENGTH > keyind) {
        if (bodyind < 0) bodyind = RLENGTH
        print substr($0, bodyind + 1)
        next
      }
      exit
    }
  ' "$RP_YML"
}

sandbox=$(mktemp -d -t release-pending-sim.XXXXXX)
# KEEP_SANDBOX=1 leaves the fixtures and step bodies on disk for
# inspection. Useful for exactly the situation where a row fails with an
# empty log and the reason is not visible from the summary line.
if [ "${KEEP_SANDBOX:-0}" = 1 ]; then
  echo "release-pending-gate-sim: sandbox kept at ${sandbox}" >&2
else
  trap 'rm -rf "$sandbox"' EXIT
fi
mkdir -p "$sandbox/steps" "$sandbox/repos" "$sandbox/shim"

RESOLVE_STEP='Resolve base ref'
DETECT_STEP='Detect protected-path diff'
CHECK_STEP='Check whether the base tip is released'

for pair in "$RESOLVE_STEP:resolve-base" "$DETECT_STEP:detect-diff" "$CHECK_STEP:check-pending"; do
  name="${pair%%:*}"
  out="${pair##*:}"
  extract_step_body "$name" > "$sandbox/steps/$out.sh"
  if [ ! -s "$sandbox/steps/$out.sh" ]; then
    echo "FAIL: could not extract the run: block of step '$name' from $RP_YML" >&2
    exit 1
  fi
  if ! grep -qE 'git (rev-parse|diff|tag)' "$sandbox/steps/$out.sh"; then
    echo "FAIL: extracted block for '$name' runs no git query; wrong step matched" >&2
    exit 1
  fi
  [ "$verbose" = 1 ] && { printf -- '--- %s ---\n' "$name"; cat "$sandbox/steps/$out.sh"; }
done

# --- 2. a git shim that can be told to refuse one subcommand ----------
#
# Fail-closed claims are only worth as much as the ability to make the
# query fail, so every "cannot tell" row below is produced by actually
# breaking git rather than by describing the breakage in a comment.
cat > "$sandbox/shim/git" <<'SHIM'
#!/usr/bin/env bash
if [ -n "${FAIL_GIT_SUBCOMMAND:-}" ]; then
  for arg in "$@"; do
    if [ "$arg" = "${FAIL_GIT_SUBCOMMAND}" ]; then
      echo "git shim: refusing subcommand '${FAIL_GIT_SUBCOMMAND}'" >&2
      exit 128
    fi
  done
fi
exec "$REAL_GIT" "$@"
SHIM
chmod +x "$sandbox/shim/git"

# --- 3. fixture helpers --------------------------------------------------
new_repo() {
  local d="$sandbox/repos/$1"
  rm -rf "$d"; mkdir -p "$d"
  git -C "$d" init -q -b main >/dev/null 2>&1
  git -C "$d" config user.email sim@example.invalid
  git -C "$d" config user.name 'release-pending sim'
  git -C "$d" config commit.gpgsign false
  git -C "$d" config tag.gpgsign false
  printf '%s\n' "$d"
}

commit_file() {
  local d=$1 path=$2 body=$3 msg=${4:-change}
  mkdir -p "$(dirname "$d/$path")"
  printf '%s\n' "$body" > "$d/$path"
  git -C "$d" add -A
  git -C "$d" commit -q -m "$msg"
}

# Mirror the branch into refs/remotes/, the spelling the PRE-FIX control
# resolves `origin/<base>` through. The current gate tries the remote
# ref first and refs/heads second, so both fixtures must offer both.
publish_origin() {
  local d=$1 branch=$2
  git -C "$d" update-ref "refs/remotes/origin/$branch" "$(git -C "$d" rev-parse "$branch")"
}

# Stand up the PR side: a branch off the base tip, carrying one change,
# checked out as HEAD. Without this HEAD and the base tip are the same
# commit, `git diff BASE...HEAD` is empty, and the gate never gets asked
# anything — a fixture that silently tests nothing.
open_pr() {
  local d=$1 path=$2 body=$3
  git -C "$d" checkout -q -b pr
  commit_file "$d" "$path" "$body" 'pr change'
}

# --- 4. replay one body --------------------------------------------------
#
#   $1 = row label
#   $2 = body file
#   $3 = fixture repo (working directory for the step)
#   $4 = expect: pass | fail
#   $5 = substring the output must contain ("" = do not check)
#   $6 = substring the output must NOT contain ("" = do not check)
#   ... = extra KEY=VALUE environment for the step
replay() {
  local label=$1 body=$2 repo=$3 expect=$4 want=$5 unwanted=$6
  shift 6
  # One log per ROW, not per fixture: two rows that share a fixture would
  # otherwise overwrite each other's evidence, and a later row could mask
  # an earlier row that failed for the wrong reason.
  local log="$repo/replay.$pass_rows.log" rc=0

  rm -f "$repo/output"
  (
    cd "$repo" || exit 1
    env GITHUB_OUTPUT="$repo/output" "$@" \
      bash --noprofile --norc -e -o pipefail "$body"
  ) > "$log" 2>&1 || rc=$?

  [ "$verbose" = 1 ] && sed 's/^/    | /' "$log"

  local verdict
  case "$expect" in
    pass) [ "$rc" -eq 0 ] && verdict='ok' || verdict="FAIL(exit $rc, wanted 0)" ;;
    fail) [ "$rc" -ne 0 ] && verdict='ok' || verdict='FAIL(exit 0, wanted non-zero)' ;;
  esac
  if [ "$want" != "" ] && ! grep -qF -- "$want" "$log" && ! grep -qF -- "$want" "$repo/output" 2>/dev/null; then
    verdict="$verdict FAIL(missing '$want')"
  fi
  if [ "$unwanted" != "" ] && grep -qF -- "$unwanted" "$log"; then
    verdict="$verdict FAIL(unexpected '$unwanted')"
  fi

  printf '  %-52s expect=%-4s exit=%-3s %s\n' "$label" "$expect" "$rc" "$verdict"
  [ "$verdict" = ok ] || fail=1
  pass_rows=$((pass_rows + 1))
}

# Replay all three steps in order, threading each step's outputs into the
# next the way Actions threads them through `env:`. This is the row that
# matters most: it exercises the workflow as GitHub will run it rather
# than three bodies in isolation.
replay_chain() {
  local label=$1 repo=$2 expect=$3 want=$4
  shift 4
  local log="$repo/chain.log" rc=0

  (
    cd "$repo" || exit 1
    export GITHUB_BASE_REF=main
    export GITHUB_OUTPUT="$repo/resolve.out"
    : > "$GITHUB_OUTPUT"
    bash --noprofile --norc -e -o pipefail "$sandbox/steps/resolve-base.sh" || exit $?

    BASE_SHA="$(sed -n 's/^base_sha=//p' "$GITHUB_OUTPUT")"
    BASE_REF="$(sed -n 's/^base_ref=//p' "$GITHUB_OUTPUT")"
    if [ -z "$BASE_SHA" ]; then
      echo "chain: resolve-base produced no base_sha" >&2
      exit 91
    fi
    export BASE_SHA BASE_REF

    export GITHUB_OUTPUT="$repo/detect.out"
    : > "$GITHUB_OUTPUT"
    bash --noprofile --norc -e -o pipefail "$sandbox/steps/detect-diff.sh" || exit $?
    if ! grep -q '^touches_protected=true$' "$GITHUB_OUTPUT"; then
      echo "chain: detect-diff did not flag protected paths" >&2
      exit 92
    fi

    export GITHUB_OUTPUT="$repo/check.out"
    : > "$GITHUB_OUTPUT"
    bash --noprofile --norc -e -o pipefail "$sandbox/steps/check-pending.sh"
  ) > "$log" 2>&1 || rc=$?

  [ "$verbose" = 1 ] && sed 's/^/    | /' "$log"

  local verdict
  case "$expect" in
    pass) [ "$rc" -eq 0 ] && verdict='ok' || verdict="FAIL(exit $rc, wanted 0)" ;;
    fail) [ "$rc" -ne 0 ] && verdict='ok' || verdict='FAIL(exit 0, wanted non-zero)' ;;
  esac
  if [ "$want" != "" ] && ! grep -qF -- "$want" "$log" && ! grep -qF -- "$want" "$repo/check.out" 2>/dev/null; then
    verdict="$verdict FAIL(missing '$want')"
  fi

  printf '  %-52s expect=%-4s exit=%-3s %s\n' "$label" "$expect" "$rc" "$verdict"
  [ "$verdict" = ok ] || fail=1
  pass_rows=$((pass_rows + 1))
}

# Replay resolve-base + detect-diff and report what detect concluded about
# the PR's paths.   $3 = want: protected | unprotected
detect_row() {
  local label=$1 repo=$2 want=$3 rc=0
  (
    cd "$repo" || exit 1
    export GITHUB_BASE_REF=main
    export GITHUB_OUTPUT="$repo/resolve.out"
    : > "$GITHUB_OUTPUT"
    bash --noprofile --norc -e -o pipefail "$sandbox/steps/resolve-base.sh" || exit $?
    BASE_SHA="$(sed -n 's/^base_sha=//p' "$GITHUB_OUTPUT")"
    export BASE_SHA
    export GITHUB_OUTPUT="$repo/detect.out"
    : > "$GITHUB_OUTPUT"
    bash --noprofile --norc -e -o pipefail "$sandbox/steps/detect-diff.sh" || exit $?
    case "$want" in
      protected) grep -q '^touches_protected=true$' "$GITHUB_OUTPUT" ;;
      unprotected) grep -q '^touches_protected=false$' "$GITHUB_OUTPUT" ;;
      *) exit 93 ;;
    esac
  ) > "$repo/detect.log" 2>&1 || rc=$?

  [ "$verbose" = 1 ] && sed 's/^/    | /' "$repo/detect.log"
  if [ "$rc" -eq 0 ]; then
    printf '  %-52s expect=%-4s exit=%-3s %s\n' "$label" "$want" 0 'ok'
  else
    printf '  %-52s expect=%-4s exit=%-3s %s\n' "$label" "$want" "$rc" 'FAIL'
    fail=1
  fi
  pass_rows=$((pass_rows + 1))
}

# Run a body that MUST fail the harness, and report whether it did.
# Used for the controls; a control that does not fire is itself a defect.
expect_harness_to_catch() {
  local label=$1 body=$2 repo=$3
  local log="$repo/control.log" rc=0
  (
    cd "$repo" || exit 1
    env GITHUB_OUTPUT="$repo/output" BASE_SHA="$(git -C "$repo" rev-parse main)" \
      BASE_REF=main GITHUB_BASE_REF=main \
      bash --noprofile --norc -e -o pipefail "$body"
  ) > "$log" 2>&1 || rc=$?
  [ "$verbose" = 1 ] && sed 's/^/    | /' "$log"
  # "caught" means the control behaved as a broken gate must: it let a
  # protected-path PR through a base that is NOT released.
  if [ "$rc" -eq 0 ]; then
    printf '  %-52s %s\n' "$label" 'ok'
  else
    printf '  %-52s %s\n' "$label" 'FAIL(control did not misbehave: harness is not sharp)'
    fail=1
  fi
  pass_rows=$((pass_rows + 1))
}

echo
echo "release-pending gate — rows"

# --- released base: the gate PASSES ------------------------------------
#
# Base tip carries tag v1.0.0. The shipped binary was built from exactly
# this tree, so a protected-path change on top of it is an ordinary
# next-cycle change. The pre-fix gate blocked this; the whole point of
# the rewrite is that it does not.
released=$(new_repo released-base)
commit_file "$released" lib/core.ml 'v1' 'c1'
commit_file "$released" lib/extra.ml 'v1' 'c2'
git -C "$released" tag v1.0.0
publish_origin "$released" main
open_pr "$released" lib/core.ml 'pr'
replay_chain 'released base: protected PR passes' "$released" pass 'commits_ahead=0'

# --- unreleased base: the gate BLOCKS, and says what would fix it ------
#
# One commit past v1.0.0. This is F15's shape: the artifact predates the
# tree, and the PR would widen the gap.
unreleased=$(new_repo unreleased-base)
commit_file "$unreleased" lib/core.ml 'v1' 'c1'
git -C "$unreleased" tag v1.0.0
commit_file "$unreleased" lib/core.ml 'v2' 'c2'
publish_origin "$unreleased" main
open_pr "$unreleased" lib/other.ml 'pr'
replay_chain 'unreleased base: protected PR blocks' "$unreleased" fail 'commits_ahead=1'

# The blocking message must name the tag and the gap, because that is
# the whole commitment of release-cadence-2026-11 (b): a reviewer has to
# be able to read what to do without opening the workflow source.
replay_chain 'blocking message names tag and gap' "$unreleased" fail 'most advanced tag v1.0.0'

# A PR that touches nothing protected never reaches the gate: the
# decision step is what scopes it, and this asserts that scoping still
# holds after the rewrite.
docs_only=$(new_repo docs-only)
commit_file "$docs_only" lib/core.ml 'v1' 'c1'
git -C "$docs_only" tag v1.0.0
publish_origin "$docs_only" main
open_pr "$docs_only" docs/readme.md 'prose'
detect_row 'docs-only PR: not protected' "$docs_only" unprotected

# bin/ is a dune package, not just bin/Mathc.ml. The obligation in
# release-cadence-2026-11 names Mathc.ml; the build does not, so the
# glob has to stay wider than the obligation.
binpkg=$(new_repo bin-package)
commit_file "$binpkg" lib/core.ml 'v1' 'c1'
git -C "$binpkg" tag v1.0.0
publish_origin "$binpkg" main
open_pr "$binpkg" bin/mathc_mcp.ml 'pr'
detect_row 'bin/mathc_mcp.ml is a protected path' "$binpkg" protected

# A tag that is not a version is not a release. release.yml publishes
# official releases only for `v*.*.*` (its `on.push.tags` filter), so a
# non-version tag must not satisfy the gate. `nightly` sits ON the base
# tip and must still not be read as the release.
nonnumeric=$(new_repo non-version-tag)
commit_file "$nonnumeric" lib/core.ml 'v1' 'c1'
git -C "$nonnumeric" tag v1.0.0
commit_file "$nonnumeric" lib/core.ml 'v2' 'c2'
git -C "$nonnumeric" tag nightly
publish_origin "$nonnumeric" main
replay 'non-version tag does not count as released' \
  "$sandbox/steps/check-pending.sh" "$nonnumeric" fail 'last_tag=v1.0.0' '' \
  BASE_SHA="$(git -C "$nonnumeric" rev-parse main)" BASE_REF=main

# The repository has shipped, but this base ref shares no release
# ancestor. We cannot tell what is published from here, and "cannot
# tell" is not "nothing is stale".
diverged=$(new_repo diverged-base)
commit_file "$diverged" lib/core.ml 'v1' 'c1'
git -C "$diverged" tag v1.0.0
# An ORPHAN branch, not a branch off the tag: a branch off v1.0.0 still
# has the release as an ancestor, so it is an ordinary unreleased base
# and never reaches the diverged path at all.
git -C "$diverged" checkout -q --orphan side
commit_file "$diverged" lib/side.ml 'side' 'c2'
git -C "$diverged" checkout -q main
publish_origin "$diverged" side
replay 'diverged base with no release ancestor blocks' \
  "$sandbox/steps/check-pending.sh" "$diverged" fail 'a diverged base is not a released base' '' \
  BASE_SHA="$(git -C "$diverged" rev-parse side)" BASE_REF=side

# Never released: no v*.*.* tag anywhere, so no artifact exists that
# could be stale. This is the one pass-without-evidence path, and it is
# safe only because the thing being checked does not exist.
virgin=$(new_repo never-released)
commit_file "$virgin" lib/core.ml 'v1' 'c1'
publish_origin "$virgin" main
replay 'never-released repository passes' \
  "$sandbox/steps/check-pending.sh" "$virgin" pass 'never cut a v*.*.* tag' '' \
  BASE_SHA="$(git -C "$virgin" rev-parse main)" BASE_REF=main

# --- cannot tell: every one of these must BLOCK -----------------------
broken=$(new_repo broken-git)

replay 'empty GITHUB_BASE_REF blocks' \
  "$sandbox/steps/resolve-base.sh" "$broken" fail 'GITHUB_BASE_REF is empty' '' \
  GITHUB_BASE_REF=

replay 'unresolvable base ref blocks' \
  "$sandbox/steps/resolve-base.sh" "$broken" fail 'cannot resolve base ref' '' \
  GITHUB_BASE_REF=no-such-branch

replay 'unreadable diff blocks' \
  "$sandbox/steps/detect-diff.sh" "$broken" fail 'cannot diff' '' \
  BASE_SHA=0000000000000000000000000000000000000000

replay 'unreadable tag list blocks' \
  "$sandbox/steps/check-pending.sh" "$unreleased" fail 'cannot list version tags' '' \
  PATH="$sandbox/shim:$PATH" FAIL_GIT_SUBCOMMAND=tag \
  BASE_SHA="$(git -C "$unreleased" rev-parse main)" BASE_REF=main

replay 'uncountable tag distance blocks' \
  "$sandbox/steps/check-pending.sh" "$unreleased" fail 'cannot count commits' '' \
  PATH="$sandbox/shim:$PATH" FAIL_GIT_SUBCOMMAND=rev-list \
  BASE_SHA="$(git -C "$unreleased" rev-parse main)" BASE_REF=main

# --- controls ----------------------------------------------------------
echo
echo "release-pending gate — controls"

# MUTATION: force the single "this base is released" condition true and
# nothing else. Every tag query still runs, every output is still
# written, the step still exits 0 — it simply no longer gates. If this
# harness cannot see that, none of the rows above mean anything.
sed 's/if \[ "${BEST_AHEAD}" -eq 0 \]; then/if true; then :/' \
  "$sandbox/steps/check-pending.sh" > "$sandbox/steps/mutant.sh"
if cmp -s "$sandbox/steps/check-pending.sh" "$sandbox/steps/mutant.sh"; then
  echo "  MUTATION NOT APPLIED — the pass condition moved; the harness is blind to it" >&2
  fail=1
else
  expect_harness_to_catch 'mutant: pass condition forced true' "$sandbox/steps/mutant.sh" "$unreleased"
fi

# PRE-FIX CONTROL: the placeholder body from ec05168. It must block the
# released base — that is the defect, a base that IS released being
# treated as a protected-path risk forever.
cat > "$sandbox/steps/prefix.sh" <<'PREFIX_EOF'
set -euo pipefail
BASE="${GITHUB_BASE_REF}"
if ! TAG_LIST="$(git tag --sort=-creatordate --merged "origin/${BASE}")"; then
  echo "release-pending: cannot list tags merged into origin/${BASE}." >&2
  echo "Gate fails closed: an unreadable tag list is not an empty one." >&2
  exit 1
fi
LATEST_TAG="${TAG_LIST%%$'\n'*}"
if [ -z "${LATEST_TAG}" ]; then
  echo "last_tag=none" >> "${GITHUB_OUTPUT}"
  echo "no release tag found on base ref ${BASE}; gate passes" >&2
  exit 0
fi
LAST_TAG_SHA="$(git rev-list -1 "${LATEST_TAG}")"
echo "last_tag=${LATEST_TAG}" >> "${GITHUB_OUTPUT}"
echo "last_tag_sha=${LAST_TAG_SHA}" >> "${GITHUB_OUTPUT}"
exit 1
PREFIX_EOF
(
  cd "$released" || exit 1
  export GITHUB_OUTPUT="$released/output"
  : > "$GITHUB_OUTPUT"
  bash --noprofile --norc -e -o pipefail "$sandbox/steps/prefix.sh"
) > "$released/control.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  printf '  %-52s %s\n' 'pre-fix control: blocks a released base' 'ok'
else
  printf '  %-52s %s\n' 'pre-fix control: blocks a released base' 'FAIL(control passed; gate is indistinguishable from the placeholder)'
  fail=1
fi
pass_rows=$((pass_rows + 1))

echo
if [ "$fail" -ne 0 ]; then
  echo "release-pending-gate-sim: FAIL — an expectation above did not hold" >&2
  exit 1
fi
echo "release-pending-gate-sim: ok — ${pass_rows} rows; the gate passes a released"
echo "                            base, blocks an unreleased one, blocks every"
echo "                            way of not knowing, and both controls fire."