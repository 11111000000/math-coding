#!/usr/bin/env bash
# tests/fixtures/master-policy-one-source.sh
#
# WHAT IT MEASURES. The protocol's master policy has ONE source
# (`templates/master-policy.yaml`), and the two copies of it in the
# tree are generated from that source:
#
#   1. `scripts/install-tooling/templates/active-policy.yaml` -- the
#      verbatim copy the kernel validates.
#   2. the string literal in `lib/init/init.ml` -- the copy the
#      binary embeds and `mathc init` writes.
#
# Before this fixture, the three documents that answered "what is the
# policy?" had drifted apart: the installer's copy was a decision
# document with an empty `scope.paths[]`, the embedded copy was a
# different decision document with placeholder paths, and
# `decisions/decision.yaml` was this repository's instance of the
# same id. The fixture measures the shape the tree is in now:
#
#   A. the canonical file exists;
#   B. both derived copies match it (byte for byte, and the embedded
#      one DECODED -- an OCaml string literal is not the YAML);
#   C. the generator is FAITHFUL: regenerating the literal in a copy
#      of `lib/init/init.ml` produces the same file, so the embedded
#      copy is the generator's output and not a hand-maintained one;
#   D. `decisions/decision.yaml` is a DECISION (it has an id and no
#      `policy_id`), not a policy sequence;
#   E. `policies.yaml` is the only policy sequence in the live tree;
#   F. the dead `MC_TEMPLATE_REMOTE_PATH` is gone from the installer.
#
# THE NEGATIVE CONTROL. A check that has never been observed to bind
# is not known to bind. The fixture breaks each derived copy in a
# throwaway copy of the tree and requires the checker to refuse it.
#
# EXIT CODES.
#   0  every derived copy matches the source, and the negative
#      control was observed to fail.
#   1  a derived copy drifted, or a shape the tree is in now is not
#      the shape the fixture measures.
#   3  nothing was measured -- unknown, not pass.

set -uo pipefail
cd "$(dirname "$0")/../.."

SOURCE="templates/master-policy.yaml"
COPY="scripts/install-tooling/templates/active-policy.yaml"
EMBEDDED="lib/init/init.ml"
SYNC="scripts/sync-master-policy.sh"
INSTALLER="scripts/install-tooling/install.sh"

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- A. the canonical file ----------------------------------------------
if [ ! -s "$SOURCE" ]; then
  bad "$SOURCE is missing or empty"
  echo "master-policy-one-source: FAIL"
  exit 1
fi
ok "$SOURCE exists ($(wc -c < "$SOURCE" | tr -d ' ') bytes)"

# --- B. the derived copies match it -------------------------------------
if sh "$SYNC" --check >/dev/null 2>&1; then
  ok "every derived copy of the master policy matches $SOURCE"
else
  sh "$SYNC" --check 2>&1 | sed 's/^/     /'
  bad "a derived copy of the master policy has drifted from $SOURCE"
fi

if cmp -s "$SOURCE" "$COPY"; then
  ok "$COPY is byte-identical to $SOURCE"
else
  bad "$COPY is not byte-identical to $SOURCE"
fi

# --- C. the generator is faithful ---------------------------------------
# The generator is run in a COPY of the tree: the real `lib/init/init.ml`
# is never written by a fixture.
tmp="$(mktemp -d)" || { echo "master-policy-one-source: mktemp failed" >&2; exit 3; }
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/scripts" "$tmp/templates" "$tmp/lib/init"
cp "$SYNC" "$tmp/scripts/"
cp "$SOURCE" "$tmp/templates/"
cp "$EMBEDDED" "$tmp/lib/init/"

if sh "$tmp/scripts/sync-master-policy.sh" --write >/dev/null 2>&1; then
  if cmp -s "$EMBEDDED" "$tmp/lib/init/init.ml"; then
    ok "the generator reproduces $EMBEDDED byte for byte: the embedded copy IS generated"
  else
    bad "the generator does not reproduce $EMBEDDED: the embedded copy is hand-maintained"
  fi
else
  bad "the generator failed on a copy of the tree"
fi

# --- D. decisions/decision.yaml is a decision --------------------------
if [ -f decisions/decision.yaml ]; then
  if grep -q "^id:" decisions/decision.yaml \
     && ! grep -q "^policy_id:\|^- policy_id:" decisions/decision.yaml; then
    ok "decisions/decision.yaml is a decision (it has an id and no policy_id)"
  else
    bad "decisions/decision.yaml is not shaped like a decision"
  fi
else
  bad "decisions/decision.yaml is missing"
fi

# --- E. one policy sequence in the live tree ---------------------------
# The live tree, not the archive: the archived waivers carry a
# `policy_id:` because they name the policy they waive.
others="$(git ls-files '*.yaml' '*.yml' 2>/dev/null \
  | grep -v '^archive/' \
  | grep -v '^policies\.yaml$' \
  | xargs grep -ln '^policy_id:\|^- policy_id:' 2>/dev/null || true)"
if [ -z "$others" ]; then
  ok "policies.yaml is the only file in the live tree that declares policy records"
else
  bad "other files declare policy records: $(echo "$others" | tr '\n' ' ')"
fi

# --- F. the dead variable is gone ---------------------------------------
# The defect was a variable that was DEFINED and never READ. A comment
# that names it is history; an assignment is the defect.
if grep -qE '^[[:space:]]*(export[[:space:]]+)?MC_TEMPLATE_REMOTE_PATH=' "$INSTALLER"; then
  bad "$INSTALLER still defines MC_TEMPLATE_REMOTE_PATH"
else
  ok "$INSTALLER defines no MC_TEMPLATE_REMOTE_PATH"
fi

# --- the negative control -----------------------------------------------
# Each derived copy is broken in the throwaway copy of the tree, and
# the checker has to refuse it. The breakage is INSIDE the content
# that the copy carries: appending a comment at the end of a YAML
# file is a real edit that leaves the master policy alone, and the
# checker is right to accept it.
for victim in "$COPY" "$EMBEDDED"; do
  rm -rf "$tmp/scripts" "$tmp/templates" "$tmp/lib" "$tmp/scripts/install-tooling"
  mkdir -p "$tmp/scripts" "$tmp/templates" "$tmp/lib/init"
  cp "$SYNC" "$tmp/scripts/"
  cp "$SOURCE" "$tmp/templates/"
  cp "$EMBEDDED" "$tmp/lib/init/"
  mkdir -p "$tmp/$(dirname "$COPY")"
  cp "$COPY" "$tmp/$COPY"
  if [ "$victim" = "$COPY" ]; then
    printf '\n# drift\n' >> "$tmp/$victim"
  else
    sed -i 's/^   state: active/   state: retired/' "$tmp/$victim"
  fi
  if sh "$tmp/scripts/sync-master-policy.sh" --check >/dev/null 2>&1; then
    bad "the checker accepted a drifted $victim: the check cannot bind"
  else
    ok "the checker refuses a drifted $victim (negative control)"
  fi
done

printf '\n'
if [ "$fail" -ne 0 ]; then
  echo "master-policy-one-source: FAIL"
  exit 1
fi
echo "master-policy-one-source: PASS"
exit 0
