#!/usr/bin/env bash
# tests/fixtures/attest-batch-run-digest.sh
#
# Failure-first fixture for the attest-batch --manifest branch, which
# ignored --run entirely.
#
# THE DEFECT. `mathc attest-batch --run=CMD` is documented as:
#
#     --run  <cmd>  command to run once; its exit code becomes
#                   --result and its output digest becomes
#                   materials_digest. Required with
#                   --kind=test|build|analysis|observation.
#
# The --from=decisions branch honoured that. The --manifest branch
# did not: it hardcoded `~materials_digest:""` and never executed the
# command. So the same command produced two different attestations
# depending on which source the obligations came from:
#
#     --from=decisions  -> materials_digest: sha256:f8d36166eab7b3b8...
#     --manifest=...    -> materials_digest: ""
#
# The empty digest is the one the schema forbids for a runtime kind
# ("this field MUST be non-empty when kind_ is in {test, build,
# observation, analysis}", schemas/attestation.json), and it is the
# value the gate treats as a wildcard. So the manifest branch
# produced attestations that were simultaneously schema-invalid and
# evidence-free — the exact failure mode --run was added to prevent.
#
# WHY A FIXTURE. The defect lived in the branch that a
# decision-driven workflow never touches: `attest-batch --from=decisions`
# is what the kernel itself uses, so it was exercised; the manifest
# branch is what a human uses to sign a specific set of obligations,
# and it had no test.
#
# WHY THE NEGATIVE CONTROL. A check that cannot fail is not a check.
# Section 3 runs the same comparison against a deliberately broken
# stub and requires the harness to notice.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# MATHC_BIN overrides the binary under test — it is how this fixture
# is pointed at a pre-fix binary to prove that it actually fails
# there. Without it the fixture would only ever test the binary it
# was built next to, and would silently pass.
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
  echo "attest-batch-run-digest: FAIL"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

manifest="$work/m.tsv"
printf 'probe-decision\tprobe-obligation\ttest\tci:fixture:probe\tpass\n' > "$manifest"

# A command whose output is deterministic, so the digest is stable.
run_cmd="printf mathc-attest-run-digest-probe"

digest_of() {
  # $1 = extra attest-batch args (as a single string)
  # prints the materials_digest of the first emitted attestation
  # shellcheck disable=SC2086
  "$bin" attest-batch $1 --manifest="$manifest" --run="$run_cmd" --dry-run 2>/dev/null \
    | head -1 \
    | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["subject"]["materials_digest"])
except Exception:
    print("")'
}

# --- 1. the manifest branch must carry a digest -------------------------
m="$(digest_of '')"
if [ -n "$m" ]; then
  ok "manifest branch wrote a materials_digest ($m)"
else
  bad "manifest branch wrote an EMPTY materials_digest — --run was ignored"
fi

# --- 2. both branches must agree ----------------------------------------
# Same command, same obligation: the digest must be identical. This
# is the property that was violated.
f="$("$bin" attest-batch --from=decisions --kind=test --producer=ci:fixture:probe \
     --run="$run_cmd" --dry-run 2>/dev/null | head -1 \
   | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["subject"]["materials_digest"])
except Exception:
    print("")')"
if [ -n "$f" ] && [ "$m" = "$f" ]; then
  ok "both branches agree on the materials_digest ($m)"
else
  bad "branches disagree: --manifest=$m vs --from=decisions=$f — one of them ignores --run"
fi

# --- 3. NEGATIVE CONTROL -------------------------------------------------
# A stub whose manifest branch drops the digest, exactly like the
# pre-fix code. The same comparison must reject it.
cat > "$work/stub" <<'STUB'
#!/usr/bin/env bash
# Stub: honours --from=decisions, drops the digest on --manifest,
# exactly like the pre-fix code.
emit() {
  printf '{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:0","kind_":"test","producer":{"identity":"x"},"result":"pass","issued_at":"2026-01-01T00:00:00Z","subject":{"decision":"d","obligation":"o","candidate_tree":"HEAD","materials_digest":"%s"}}\n' "$1"
}
for a in "$@"; do
  case "$a" in
    --manifest=*) emit "" ; exit 0 ;;
  esac
done
emit "sha256:abc"
STUB
chmod 755 "$work/stub"

stub_from="$("$work/stub" attest-batch --from=decisions --kind=test --producer=x --run="printf x" --dry-run 2>/dev/null \
  | head -1 | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["subject"]["materials_digest"])
except Exception:
    print("")')"
stub_man="$("$work/stub" attest-batch --manifest="$manifest" --run="$run_cmd" --dry-run 2>/dev/null \
  | head -1 | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["subject"]["materials_digest"])
except Exception:
    print("")')"
if [ -n "$stub_from" ] && [ "$stub_man" != "$stub_from" ]; then
  ok "negative control: the comparison detected the branch that drops the digest"
else
  bad "negative control: the comparison did NOT detect a branch that drops the digest — this fixture cannot detect the defect it exists to detect"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "attest-batch-run-digest: PASS"
  exit 0
fi
echo "attest-batch-run-digest: FAIL"
exit 1
