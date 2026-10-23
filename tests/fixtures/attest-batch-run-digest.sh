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
# depending on which source the obligations came from.
#
# Under semantics A (the materials digest is the digest of the CONTENT
# of the files a decision's scope names), the invariant this fixture
# pins is:
#
#     for the SAME (decision, obligation), the --manifest branch and
#     the --from=decisions branch write the SAME materials_digest.
#
# It is NOT "both branches write the run output digest" — that was the
# old, incoherent conflation, and the whole point of semantics A is
# that the materials digest and the run's evidence are different
# things. The run's output digest now lives in `evidence_digest`.
#
# WHY A FIXTURE. The defect lived in the branch that a
# decision-driven workflow never touches: `attest-batch --from=decisions`
# is what the kernel itself uses, so it was exercised; the manifest
# branch is what a human uses to sign a specific set of obligations,
# and it had no test.
#
# WHY THE NEGATIVE CONTROL. A check that cannot fail is not a check.
# Section 4 runs the same comparison against a deliberately broken
# stub and requires the harness to notice.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# MATHC_BIN overrides the binary under test — it is how this fixture
# is pointed at a pre-fix binary to prove that it actually fails
# there.
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

# A command whose output is deterministic, so the digest is stable.
run_cmd="printf mathc-attest-run-digest-probe"

# --- 0. take a REAL (decision, obligation) pair from the corpus ----------
# The comparison must be about the same obligation on both sides, or it
# compares two different things and proves nothing. The pair is taken
# from what the --from=decisions branch actually emits, so it is
# guaranteed to be an obligation the kernel knows about.
first="$("$bin" attest-batch --from=decisions --kind=test --producer=ci:fixture:probe \
        --run="$run_cmd" --dry-run 2>/dev/null | head -1)"
dec_id="$(printf '%s' "$first" | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["subject"]["decision"])
except Exception: print("")')"
obl_id="$(printf '%s' "$first" | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["subject"]["obligation"])
except Exception: print("")')"
if [ -z "$dec_id" ] || [ -z "$obl_id" ]; then
  bad "could not read a (decision, obligation) pair from the corpus"
  echo "attest-batch-run-digest: FAIL"
  exit 1
fi

manifest="$work/m.tsv"
printf '%s\t%s\ttest\tci:fixture:probe\tpass\n' "$dec_id" "$obl_id" > "$manifest"

digest_of() {
  # $1 = the attestation JSON on stdin; prints the materials_digest
  python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d["subject"]["materials_digest"])
except Exception:
    print("")'
}

# --- 1. the manifest branch must carry a digest -------------------------
m="$("$bin" attest-batch --manifest="$manifest" --run="$run_cmd" --dry-run 2>/dev/null \
     | head -1 | digest_of)"
if [ -n "$m" ]; then
  ok "manifest branch wrote a materials_digest ($m)"
else
  bad "manifest branch wrote an EMPTY materials_digest — --run was ignored"
fi

# --- 2. both branches must agree on the SAME obligation -----------------
f="$("$bin" attest-batch --from=decisions --kind=test --producer=ci:fixture:probe \
     --run="$run_cmd" --dry-run 2>/dev/null \
   | python3 -c 'import sys,json
want_dec=sys.argv[1]; want_obl=sys.argv[2]
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: d=json.loads(line)
    except Exception: continue
    s=d.get("subject",{})
    if s.get("decision")==want_dec and s.get("obligation")==want_obl:
        print(s.get("materials_digest","")); break
else:
    print("")' "$dec_id" "$obl_id")"
if [ -n "$f" ] && [ "$m" = "$f" ]; then
  ok "both branches agree on $dec_id/$obl_id ($m)"
else
  bad "branches disagree on $dec_id/$obl_id: --manifest=$m vs --from=decisions=$f"
fi

# --- 3. the run's evidence must be recorded separately ------------------
# The digest of what the command produced is evidence, not the materials
# anchor. Under semantics A they are different fields.
ev="$("$bin" attest-batch --manifest="$manifest" --run="$run_cmd" --dry-run 2>/dev/null \
     | head -1 \
   | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("evidence_digest",""))
except Exception:
    print("")')"
if [ -n "$ev" ]; then
  ok "the run's output digest is recorded in evidence_digest ($ev)"
else
  bad "no evidence_digest recorded — the run's output is not preserved anywhere"
fi

# --- 4. NEGATIVE CONTROL -------------------------------------------------
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

stub_man="$("$work/stub" attest-batch --manifest="$manifest" --run="$run_cmd" --dry-run 2>/dev/null \
  | head -1 | digest_of)"
stub_from="$("$work/stub" attest-batch --from=decisions --kind=test --producer=x --run="printf x" --dry-run 2>/dev/null \
  | head -1 | digest_of)"
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
