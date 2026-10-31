#!/usr/bin/env bash
# tests/fixtures/exportable-core-boundary.sh
#
# The transferable/protocol boundary is executable. This fixture checks the
# tree produced by scripts/export-core.sh against an INDEPENDENT path
# allowlist, then contaminates throwaway copies and requires the same check
# to reject each kind of project content.
#
# WHAT THE THREE ARTIFACTS ARE. The plan names them in section 0: a decisions
# directory, an attestations directory, and policies.yaml. The export carries
# the first two as EMPTY directories and copies the third. It does not carry
# this repository's 136 live decision files or its generated evidence store:
# those are the conformance corpus of THIS project, not protocol scaffolding.
#
# THE NEGATIVE CONTROL. A boundary check that has never rejected anything is
# not known to be able to reject anything. Each contaminated copy is made in
# a temporary directory; the repository checkout is never modified.
#
# The fixture also builds the exported tree and makes the exported binary
# validate a decision. A copy that cannot compile or cannot make a decision is
# not a portable core, whatever its directory layout says.
#
# Exit codes follow the house convention: 0 = measured and held,
# 1 = measured and broken.

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

ROOT="$PWD"
EXPORTER="$ROOT/scripts/export-core.sh"
fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

tmp="$(mktemp -d)" || { echo 'FAIL: mktemp' >&2; exit 1; }
# shellcheck disable=SC2329   # invoked indirectly as a trap handler
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

exported="$tmp/export"

# An independent implementation of the boundary. It deliberately does not
# call the exporter's internal check: the fixture asks a different reader
# whether the same tree is inside the protocol.
check_boundary() {
  local tree="$1"
  local path
  local rc=0
  local first

  for required in \
    VERSION \
    dune-project \
    math-coding.opam \
    policies.yaml \
    .export-core-boundary \
    adoption/SKILL.md \
    lib/dune \
    bin/dune; do
    if [ ! -f "$tree/$required" ]; then
      printf 'boundary: required path is missing: %s\n' "$required" >&2
      rc=1
    fi
  done

  while IFS= read -r path; do
    case "$path" in
      VERSION|dune-project|math-coding.opam|policies.yaml|\
      .export-core-boundary|adoption|adoption/SKILL.md|\
      lib|lib/*|bin|bin/*|decisions|attestations)
        ;;
      *)
        printf 'boundary: path is not part of the protocol: %s\n' "$path" >&2
        rc=1
        ;;
    esac
  done < <(cd "$tree" && find . -mindepth 1 -printf '%P\n' | LC_ALL=C sort)

  for artifact_dir in decisions attestations; do
    if [ ! -d "$tree/$artifact_dir" ]; then
      printf 'boundary: protocol artifact directory is missing: %s\n' \
        "$artifact_dir" >&2
      rc=1
    else
      first="$(find "$tree/$artifact_dir" -mindepth 1 -print -quit)"
      if [ -n "$first" ]; then
        printf 'boundary: protocol artifact directory is not empty: %s\n' \
          "$first" >&2
        rc=1
      fi
    fi
  done

  first="$(find "$tree" -type l -print -quit)"
  if [ -n "$first" ]; then
    printf 'boundary: symbolic link is not allowed: %s\n' "$first" >&2
    rc=1
  fi

  return "$rc"
}

# --- 1. the export exists -----------------------------------------------
if [ ! -x "$EXPORTER" ]; then
  bad "$EXPORTER does not exist or is not executable"
  echo
  echo 'exportable-core-boundary: FAIL'
  exit 1
fi
ok 'the export script exists and is executable'

if bash "$EXPORTER" "$exported" > "$tmp/export.log" 2>&1; then
  ok 'the export script produced a tree'
else
  bad 'the export script failed'
  sed -n '1,120p' "$tmp/export.log" >&2
fi

# --- 2. the tree is inside the protocol ---------------------------------
if check_boundary "$exported" > "$tmp/boundary.log" 2>&1; then
  ok 'the export contains only protocol paths'
else
  bad 'the export contains a path outside the protocol'
  sed -n '1,120p' "$tmp/boundary.log" >&2
fi

for required in \
  VERSION \
  dune-project \
  math-coding.opam \
  policies.yaml \
  adoption/SKILL.md \
  lib/domain.ml \
  bin/Mathc.ml; do
  if [ -f "$exported/$required" ]; then
    ok "the export contains $required"
  else
    bad "the export does not contain $required"
  fi
done

for artifact_dir in decisions attestations; do
  if [ -d "$exported/$artifact_dir" ]; then
    ok "the export contains the empty $artifact_dir protocol artifact directory"
  else
    bad "the export does not contain the $artifact_dir protocol artifact directory"
  fi
done

# The copied core and protocol files must be the source files, not a
# convenient subset that merely happens to have the right names.
if diff -qr "$ROOT/lib" "$exported/lib" > "$tmp/lib.diff" 2>&1; then
  ok 'the exported lib/ tree is byte-for-byte the source lib/ tree'
else
  bad 'the exported lib/ tree differs from the source lib/ tree'
  sed -n '1,80p' "$tmp/lib.diff" >&2
fi

if diff -qr "$ROOT/bin" "$exported/bin" > "$tmp/bin.diff" 2>&1; then
  ok 'the exported bin/ tree is byte-for-byte the source bin/ tree'
else
  bad 'the exported bin/ tree differs from the source bin/ tree'
  sed -n '1,80p' "$tmp/bin.diff" >&2
fi

for copied in policies.yaml adoption/SKILL.md dune-project math-coding.opam VERSION; do
  if cmp -s "$ROOT/$copied" "$exported/$copied"; then
    ok "$copied is byte-for-byte the source file"
  else
    bad "$copied differs from the source file"
  fi
done

# --- 3. named project surfaces stay behind ------------------------------
for forbidden in \
  site plugin fixtures scripts tools docs spec axioms schemas templates \
  render archive assets tests .github .opencode; do
  if [ -e "$exported/$forbidden" ]; then
    bad "the export contains project surface: $forbidden/"
  fi
done
ok 'the site, plugin, conformance corpus, release tooling and book stay behind'

for book_file in KERNEL_AGENTS.md OCAML_KERNEL_CONVENTIONS.md; do
  if [ -e "$exported/$book_file" ]; then
    bad "the export contains book file: $book_file"
  fi
done

# --- 4. NEGATIVE CONTROL ------------------------------------------------
# Each copy receives one real project-shaped file. The independent boundary
# check must reject the copy. If it accepts any of them, the positive check
# above has no meaning.
negative_paths=(
  'site/leak.md'
  'plugin/leak.js'
  'fixtures/conformance/leak.json'
  'scripts/install-tooling/leak.sh'
  'spec/leak.md'
  'decisions/project-corpus.yaml'
)

n=0
for leaked_path in "${negative_paths[@]}"; do
  n=$((n + 1))
  contaminated="$tmp/contaminated-$n"
  cp -a "$exported" "$contaminated"
  mkdir -p "$(dirname "$contaminated/$leaked_path")"
  printf 'project-only negative control\n' > "$contaminated/$leaked_path"

  if check_boundary "$contaminated" > "$tmp/negative-$n.log" 2>&1; then
    bad "the boundary check accepted a project file: $leaked_path"
  else
    ok "the boundary check rejected a project file: $leaked_path"
  fi
done

# --- 5. the exported core builds and works ------------------------------
build_export() {
  if command -v dune >/dev/null 2>&1; then
    (cd "$exported" && dune build bin/mathc.exe)
  else
    # The single quotes are intentional: $1 is expanded by the inner bash.
    # shellcheck disable=SC2016
    nix develop "$ROOT#test" --command bash -c \
      'cd "$1" && dune build bin/mathc.exe' _ "$exported"
  fi
}

if build_export > "$tmp/build.log" 2>&1; then
  ok 'the exported core builds with dune'
else
  bad 'the exported core does not build'
  sed -n '1,160p' "$tmp/build.log" >&2
fi

mathc="$exported/_build/default/bin/mathc.exe"
if [ -x "$mathc" ]; then
  ok 'the exported build produced mathc'

  version_output="$(cd "$exported" && "$mathc" version 2>&1)"
  expected_version="math-coding $(tr -d '\n' < "$exported/VERSION"): bootstrap"
  if [ "$version_output" = "$expected_version" ]; then
    ok "the exported mathc reports its version: $version_output"
  else
    bad "the exported mathc reported the wrong version: $version_output"
  fi

  cat > "$exported/decisions/export-probe.yaml" <<'YAML'
---
schema: math-coding/3.3
id: export-probe
revision: 1
state: active
mode: light
body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
intent: prove that the exported kernel accepts a decision
commitment: the exported kernel validates this decision
counterexample: the decision names a file outside the export
axiom_link:
  - A0
scope:
  paths:
    - VERSION
outcomes:
  - id: exported-kernel-validates
    statement: mathc validate accepts this decision
obligations:
  - id: version-exists
    claim: VERSION exists in the exported tree
    acceptance:
      all:
        - verifier: file-exists VERSION
YAML

  if (cd "$exported" && "$mathc" rehash --write decisions/export-probe.yaml) \
      > "$tmp/rehash.log" 2>&1; then
    ok 'the exported mathc rehashes the probe decision'
  else
    bad 'the exported mathc cannot rehash the probe decision'
    sed -n '1,120p' "$tmp/rehash.log" >&2
  fi

  validate_output="$(cd "$exported" && "$mathc" validate decisions/export-probe.yaml 2>&1)"
  validate_rc=$?
  if [ "$validate_rc" -eq 0 ] && printf '%s\n' "$validate_output" | grep -q 'parse-ok:'; then
    ok 'the exported mathc accepts the probe decision'
  else
    bad 'the exported mathc rejected the probe decision'
    printf '%s\n' "$validate_output" >&2
  fi
else
  bad 'the exported build did not produce an executable mathc'
fi

echo
if [ "$fail" -eq 0 ]; then
  echo 'exportable-core-boundary: PASS'
  exit 0
fi
echo 'exportable-core-boundary: FAIL'
exit 1
