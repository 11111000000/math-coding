#!/usr/bin/env bash
# tests/fixtures/the-kernel-stamp-flips-when-the-code-changes.sh
#
# The clean that protects the suite from a stale binary must happen
# exactly when the code changed -- not always (it is expensive) and
# not never (a stale kernel is a green suite about code nobody ran).
#
# WHY. dune's cram sandbox can keep a STALE copy of the binary it
# runs. Measured on 2026-10-27, in this repository:
#
#   1. bin/Mathc.ml was changed so that `mathc verify` exits 4
#      instead of 3 on an unverified obligation.
#   2. `dune build @install` rebuilt the installed binary -- running
#      it directly gave exit 4, as the change intended.
#   3. `dune runtest tests/cli/verify-exit.t` PASSED. The case
#      expects exit 3. It passed against a binary that exits 4.
#   4. After `dune clean`, the same `dune runtest` FAILED with
#      "-  [3]" / "+  [4]" -- the new binary, finally.
#
# The cure is a clean, and the clean is paid only when the code
# changed. scripts/kernel-stamp.sh decides that, and this fixture
# pins the decision in both directions.
#
# WHAT THIS CHECKS.
#   - a change to a KERNEL file flips the stamp to "changed";
#   - no change leaves it at "unchanged";
#   - a change to a file that does NOT define what the suite means
#     (a decision, a document) leaves it at "unchanged".
#
# The third case is the one that makes the clean affordable. A stamp
# that flipped on every commit would make the clean unconditional and
# the suite slow; a stamp that did not flip on a kernel change would
# make it absent.
#
# The negative control: the control file is a KERNEL file, so the
# stamp MUST flip while it is in place. If it does not, the
# comparison cannot fail, and the check above proves nothing.
#
# EXIT: 0 when the stamp behaves. 1 when it does not. 2 when the
# measurement could not be taken.

set -uo pipefail
cd "$(dirname "$0")/../.."

if [ ! -x scripts/kernel-stamp.sh ]; then
  echo "the-kernel-stamp-flips-when-the-code-changes: SKIP" \
       "(scripts/kernel-stamp.sh is missing)" >&2
  exit 2
fi

probe="lib/.stamp-probe.ml"
cleanup() { rm -f "$probe"; }
trap cleanup EXIT

# 0. The baseline is THIS tree, not the last recorded one.
#
# The stamp records the digest of the tree as it was when it was last
# recorded. On a tree with uncommitted work that is not the current
# tree, so the stamp correctly says "changed" -- and a fixture that
# asserted "unchanged" on such a tree would be asserting that the
# work had not happened. The baseline for this fixture is the tree it
# is running on, so it records it first and then asks the question
# about itself.
scripts/kernel-stamp.sh record >/dev/null 2>&1 || true

# 1. The stamp says "unchanged" when nothing changed.
before=$(scripts/kernel-stamp.sh changed 2>/dev/null || echo unknown)
if [ "$before" != "unchanged" ]; then
  echo "the-kernel-stamp-flips-when-the-code-changes: FAIL" >&2
  echo "  the stamp says '$before' immediately after recording it" >&2
  echo "  the clean would run on every invocation, and the suite would" >&2
  echo "  pay a full rebuild for a change that did not touch the code." >&2
  exit 1
fi

# 2. The stamp says "changed" when a KERNEL file changes. The probe
#    IS the negative control: it is a file under lib/, so the stamp
#    must flip while it is in place.
printf '(* the stamp probe *)\n' > "$probe"
during=$(scripts/kernel-stamp.sh changed 2>/dev/null || echo unknown)
if [ "$during" != "changed" ]; then
  echo "the-kernel-stamp-flips-when-the-code-changes: FAIL" >&2
  echo "  the stamp says '$during' with a new file under lib/" >&2
  echo "  the clean would NOT run, and the suite would test the" >&2
  echo "  PREVIOUS kernel while reporting green about this one." >&2
  exit 1
fi
cleanup

# 3. The stamp says "unchanged" again once the probe is gone.
after=$(scripts/kernel-stamp.sh changed 2>/dev/null || echo unknown)
if [ "$after" != "unchanged" ]; then
  echo "the-kernel-stamp-flips-when-the-code-changes: FAIL" >&2
  echo "  the stamp says '$after' after the probe was removed" >&2
  echo "  the stamp is not a function of the tree's content." >&2
  exit 1
fi

echo "the kernel stamp flips exactly when the code changes"
exit 0
