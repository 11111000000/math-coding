#!/usr/bin/env bash
# process-principles: p1 + p2 + p5 + p6 + p7 fixture
#
# Asserts the checkable subset of ROADMAP.md Process Principles
# P1-P7 as locked down by bootstrap/process-principles.yaml. Each
# principle has its own check; the fixture prints the principle
# name on success or failure, and exits 1 with the offending
# principle's label on the first violation.
#
# P1 (decisions before kernel changes) — every non-meta file in
#     bootstrap/ has the required frontmatter fields (schema, id,
#     revision) and the required body sections (intent, commitment,
#     scope, obligations, risk). A future file that omits any
#     required field trips P1.
#
# P2 (decisions paired with fixtures) — every obligation in a
#     non-meta decision file references a verifier via
#     `acceptance.all[].verifier`, where the verifier is either
#     a path under `tests/fixtures/*.sh` that exists on disk, a
#     kernel-test reference (e.g. `tests/conformance.ml ...` or
#     `tests/yaml_block_scalars.ml`), or a manual-style verifier
#     (`text-scan-`, `cram-fixture-`, `script-runs-and-is-deterministic`,
#     `dune test`, `dune build`, `manual-`, `review`,
#     `practice-review`, `mathc-`, `compiler-warning-clean`,
#     `sha256-rfc-vectors`, `flake-pin-clean`, `reference-class`,
#     `this-decision-file-present`, or a recognised exact name
#     like `gate-shape-fixture`). An obligation with no verifier
#     declaration trips P2; a verifier pointing to a non-existent
#     fixture file also trips P2.
#
# P5 (cram retired) — `tests/cram/*.t` does not exist. New cram
#     files trip P5.
#
# P6 (pre-commit verification) — `scripts/check.sh` exists and
#     is executable. Removing the file or stripping the bit
#     trips P6.
#
# P7 (honesty) — this fixture is a structural check that reads
#     repository state and compares it against invariants; it
#     does not assert "this fixture exits 0" as its only
#     statement. P7 is meta-checked by the human maintainer.
#
# P3 (time-box) and P4 (merge order) are NOT checked here;
#     per bootstrap/process-principles.yaml they are
#     honest-declaration obligations with manual-acceptance.
#
# This fixture is the acceptance gate for obligations
# p1-decisions-before-kernel-changes, p2-decisions-paired-with-fixtures,
# p5-cram-retired-shell-fixtures-only, p6-pre-commit-verification,
# p7-honesty-in-fixture-assertions in bootstrap/process-principles.yaml.
#
# Verdict:
#   exit 0 — every checkable principle holds at HEAD.
#   exit 1 — at least one principle is violated; stderr prints
#            the principle label (P1 / P2 / P5 / P6) and the
#            offending files / obligation IDs.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "process-principles:"

fail=0

# -----------------------------------------------------------------
# P1 — every non-meta bootstrap file has the required frontmatter
#      fields and the required body sections.
# -----------------------------------------------------------------
p1_fail=0

# Files explicitly excluded from the P1 schema check
# (see bootstrap/process-principles.yaml assumption
#  meta-policy-skipped-by-fixture):
#   - bootstrap/decision.yaml      (active policy; no obligations:)
#   - bootstrap/obligations.yaml   (aggregator; different schema)
#   - bootstrap/rationale.md       (free-form prose)
p1_skip_re='^(bootstrap/decision\.yaml|bootstrap/obligations\.yaml|bootstrap/rationale\.md)$'

for f in bootstrap/*.yaml bootstrap/*.md; do
  if [[ "$f" =~ $p1_skip_re ]]; then
    continue
  fi
  if [ ! -f "$f" ]; then
    continue
  fi

  # Extract frontmatter: lines from the leading --- through the
  # next --- (excluding both delimiters). YAML frontmatter uses
  # this convention; if no closing --- exists, we fall back to
  # the leading --- only, which still captures the schema/id/
  # revision block for current files (none have a closing ---).
  fm=$(awk '
    BEGIN { in_fm = 0; saw_first = 0 }
    {
      if (!saw_first && /^---$/) {
        saw_first = 1
        in_fm = 1
        next
      }
      if (in_fm && /^---$/) {
        exit
      }
      if (in_fm) {
        print
      }
    }
  ' "$f")

  if [ -z "$fm" ]; then
    echo "  FAIL P1: $f has no frontmatter" >&2
    p1_fail=1
    continue
  fi

  missing_fm=()
  for field in schema id revision; do
    if ! printf '%s\n' "$fm" | grep -qE "^${field}:"; then
      missing_fm+=("$field")
    fi
  done
  if [ ${#missing_fm[@]} -gt 0 ]; then
    echo "  FAIL P1: $f missing frontmatter fields: ${missing_fm[*]}" >&2
    p1_fail=1
  fi

  missing_sec=()
  for sec in intent commitment scope obligations risk; do
    if ! grep -qE "^${sec}:" "$f"; then
      missing_sec+=("$sec")
    fi
  done
  if [ ${#missing_sec[@]} -gt 0 ]; then
    echo "  FAIL P1: $f missing body sections: ${missing_sec[*]}" >&2
    p1_fail=1
  fi
done

if [ "$p1_fail" -ne 0 ]; then
  echo "  FAIL P1 (decisions-before-kernel-changes) violated" >&2
  fail=1
else
  echo "  ok   P1 every bootstrap decision file has required frontmatter and body sections"
fi

# -----------------------------------------------------------------
# P2 — every obligation in a non-meta decision file references a
#      verifier via `acceptance.all[].verifier`, where the
#      verifier is either a present fixture file, a kernel-test
#      reference, a cram .t file, or a manual-style verifier.
# -----------------------------------------------------------------
p2_fail=0

# Manual-style verifier prefixes. A verifier whose value starts
# with any of these is accepted without a file-existence check;
# the obligation's verifier is a human / kernel-side review, not
# a fixture file.
p2_manual_prefixes=(
  'manual-'
  'text-scan-'
  'practice-review'
  'cram-fixture-'
  'script-runs-and-is-deterministic'
  'conformance-fixtures-still-pass'
  'compiler-warning-clean'
  'sha256-rfc-vectors'
  'flake-pin-clean'
  'dune test'
  'dune build'
  'review'
  'mathc-'
  'reference-class'
  'this-decision-file-present'
  'mc '
)

# Manual-style exact verifier names.
p2_manual_exact=(
  'gate-shape-fixture'
  'sha256-against-rfc6234-vectors'
)

# Helper: classify one verifier string.
# Echoes one of: manual, fixture-path, kernel-test, unrecognised.
# If fixture-path, the path is appended on stdout.
classify_verifier() {
  local v="$1"
  for p in "${p2_manual_prefixes[@]}"; do
    if [[ "$v" == "$p"* ]]; then
      printf 'manual\n'
      return
    fi
  done
  for e in "${p2_manual_exact[@]}"; do
    if [ "$v" = "$e" ]; then
      printf 'manual\n'
      return
    fi
  done
  # tests/fixtures/<name>.sh (with optional compound suffix).
  if [[ "$v" =~ ^tests/fixtures/[A-Za-z0-9_./-]+\.sh(:.+)?$ ]]; then
    # strip optional compound suffix.
    local bare="${v%%:*}"
    printf 'fixture-path\n%s\n' "$bare"
    return
  fi
  # Bare <name>.sh (used by infrastructure-honesty.yaml).
  if [[ "$v" =~ ^[A-Za-z0-9_-]+\.sh$ ]]; then
    printf 'fixture-path\ntests/fixtures/%s\n' "$v"
    return
  fi
  # Cram .t file under tests/cli/. Treated as a present fixture;
  # dune discovers it via the (cram ...) stanza in tests/cli/dune
  # and runs it under `dune runtest`.
  if [[ "$v" =~ ^tests/cli/[A-Za-z0-9_./-]+\.t(:.+)?$ ]]; then
    local bare="${v%%:*}"
    printf 'fixture-path\n%s\n' "$bare"
    return
  fi
  # Kernel-test reference: tests/<file>.ml or tests/conformance.ml ...
  if [[ "$v" =~ ^tests/[A-Za-z0-9_]+\.ml ]]; then
    printf 'kernel-test\n'
    return
  fi
  printf 'unrecognised\n'
}

# Walk every non-meta decision file and audit each obligation's
# verifier declaration(s). Two checks per obligation: (a) the
# obligation declares at least one verifier; (b) every verifier
# is either manual, a present fixture path, or a kernel-test
# reference. Print FAIL_P2_* lines to stdout for the shell loop
# to pick up and translate to user-facing messages.

p2_tmp=$(mktemp)
trap 'rm -f "$p2_tmp"' EXIT

for f in bootstrap/*.yaml bootstrap/*.md; do
  if [[ "$f" =~ $p1_skip_re ]]; then
    continue
  fi
  if [ ! -f "$f" ]; then
    continue
  fi

  awk -v file="$f" '
    function flush_entry(   i) {
      if (cur_id == "") return
      if (verifier_count == 0 && manual_evidence == 0) {
        print "FAIL_P2_NO_VERIFIER\t" cur_id "\t" file
        return
      }
    }
    BEGIN {
      in_obligations = 0
      in_obligation = 0
      cur_id = ""
      verifier_count = 0
      manual_evidence = 0
    }
    /^outcomes:|^assumptions:|^reversal:|^risk:|^relations:/ {
      if (in_obligation) flush_entry()
      in_obligations = 0
      in_obligation = 0
      cur_id = ""
      verifier_count = 0
      manual_evidence = 0
    }
    /^obligations:/ {
      in_obligations = 1
      next
    }
    in_obligations && /^[[:space:]]*-[[:space:]]+id:[[:space:]]+/ {
      if (in_obligation) flush_entry()
      in_obligation = 1
      cur_id = $0
      sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]+/, "", cur_id)
      sub(/[[:space:]]+$/, "", cur_id)
      verifier_count = 0
      manual_evidence = 0
      next
    }
    in_obligation && /^[[:space:]]*-[[:space:]]+verifier:[[:space:]]+/ {
      v = $0
      sub(/^[[:space:]]*-[[:space:]]+verifier:[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      verifiers[++verifier_count] = v
    }
    in_obligation && /^[[:space:]]+evidence:[[:space:]]*manual-acceptance[[:space:]]*$/ {
      manual_evidence = 1
    }
    END {
      if (in_obligation) flush_entry()
    }
  ' "$f" >> "$p2_tmp"
done

# Now do the shell-side classifier + file-existence check.
declare -a fixture_paths_to_check=()

while IFS=$'\t' read -r tag oid src; do
  if [ "$tag" = "FAIL_P2_NO_VERIFIER" ]; then
    echo "  FAIL P2: $src obligation '$oid' has no acceptance.all[].verifier" >&2
    p2_fail=1
  fi
done < "$p2_tmp"

# Re-scan verifier lines for the file-existence check. We do this
# separately so we can re-use classify_verifier in shell.
declare -a fixture_paths=()
while IFS= read -r line; do
  # Each line is "<obligation-id>\t<src-file>\t<verifier>".
  # Verifiers may repeat per obligation; we want all of them.
  while IFS=$'\t' read -r oid src v; do
    if [ -z "$v" ]; then continue; fi
    classified=$(classify_verifier "$v" | head -1)
    if [ "$classified" = "fixture-path" ]; then
      path=$(classify_verifier "$v" | tail -1)
      fixture_paths+=("$path")
    elif [ "$classified" = "unrecognised" ]; then
      echo "  FAIL P2: $src obligation '$oid' verifier '$v' is neither a present fixture nor a manual-style verifier" >&2
      p2_fail=1
    fi
  done <<< "$line"
done < <(
  # Emit "<oid>\t<src>\t<verifier>" lines for every verifier in
  # every obligation of every non-meta decision file. One verifier
  # per line so the shell loop above can classify each.
  for f in bootstrap/*.yaml bootstrap/*.md; do
    if [[ "$f" =~ $p1_skip_re ]]; then continue; fi
    if [ ! -f "$f" ]; then continue; fi
    awk -v file="$f" '
      function flush_entry(   i) {
        if (cur_id == "") return
        for (i = 1; i <= verifier_count; i++) {
          print cur_id "\t" file "\t" verifiers[i]
        }
      }
      BEGIN {
        in_obligations = 0; in_obligation = 0; cur_id = ""
        verifier_count = 0
      }
      /^outcomes:|^assumptions:|^reversal:|^risk:|^relations:/ {
        if (in_obligation) flush_entry()
        in_obligations = 0; in_obligation = 0; cur_id = ""
        verifier_count = 0
      }
      /^obligations:/ { in_obligations = 1; next }
      in_obligations && /^[[:space:]]*-[[:space:]]+id:[[:space:]]+/ {
        if (in_obligation) flush_entry()
        in_obligation = 1
        cur_id = $0
        sub(/^[[:space:]]*-[[:space:]]+id:[[:space:]]+/, "", cur_id)
        sub(/[[:space:]]+$/, "", cur_id)
        verifier_count = 0
        next
      }
      in_obligation && /^[[:space:]]*-[[:space:]]+verifier:[[:space:]]+/ {
        v = $0
        sub(/^[[:space:]]*-[[:space:]]+verifier:[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        verifiers[++verifier_count] = v
      }
      END { if (in_obligation) flush_entry() }
    ' "$f"
  done
)

# Deduplicate fixture paths and verify each exists.
if [ ${#fixture_paths[@]} -gt 0 ]; then
  printf '%s\n' "${fixture_paths[@]}" | sort -u > "$p2_tmp.paths"
  while IFS= read -r p; do
    if [ ! -f "$p" ]; then
      echo "  FAIL P2: referenced fixture does not exist: $p" >&2
      p2_fail=1
    fi
  done < "$p2_tmp.paths"
fi

if [ "$p2_fail" -ne 0 ]; then
  echo "  FAIL P2 (decisions-paired-with-fixtures) violated" >&2
  fail=1
else
  echo "  ok   P2 every obligation declares a verifier that is a present fixture, a kernel-test reference, or a manual-style verifier"
fi

# -----------------------------------------------------------------
# P5 — `tests/cram/*.t` does not exist.
# -----------------------------------------------------------------
if compgen -G "tests/cram/*.t" > /dev/null 2>&1; then
  echo "  FAIL P5: tests/cram/*.t exists (cram is retired; shell fixtures only)" >&2
  for f in tests/cram/*.t; do
    echo "         $f" >&2
  done
  echo "  FAIL P5 (cram-retired-shell-fixtures-only) violated" >&2
  fail=1
else
  echo "  ok   P5 no tests/cram/*.t files exist (cram is retired)"
fi

# -----------------------------------------------------------------
# P6 — `scripts/check.sh` exists and is executable.
# -----------------------------------------------------------------
if [ ! -e scripts/check.sh ]; then
  echo "  FAIL P6: scripts/check.sh does not exist" >&2
  echo "  FAIL P6 (pre-commit-verification) violated" >&2
  fail=1
elif [ ! -x scripts/check.sh ]; then
  echo "  FAIL P6: scripts/check.sh exists but is not executable" >&2
  echo "  FAIL P6 (pre-commit-verification) violated" >&2
  fail=1
else
  echo "  ok   P6 scripts/check.sh exists and is executable"
fi

# -----------------------------------------------------------------
# P7 — honesty. This fixture is itself a check that reads the
#      repository state and compares against structural invariants;
#      it does not assert "this fixture exits 0" as its only
#      statement. P7 is meta-checked by the human maintainer
#      reviewing this fixture's body. We print a one-line marker
#      so the reviewer can grep for the assertion.
# -----------------------------------------------------------------
echo "  ok   P7 this fixture is structural (reads repo state); honesty is reviewed, not auto-asserted"

exit "$fail"