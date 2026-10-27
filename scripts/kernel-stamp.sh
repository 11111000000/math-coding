#!/usr/bin/env bash
# scripts/kernel-stamp.sh -- one definition of "has the code changed?".
#
# WHAT IT IS. A digest over the sources whose CONTENT changes what the
# test suite MEANS: the kernel (lib, bin), the tests themselves, the
# scripts they call, and the schemas. The digest is stored in
# .local/kernel-stamp.
#
# WHY IT EXISTS. dune's cram sandbox can keep a STALE copy of the
# binary it runs. Measured on 2026-10-27: after a change to
# bin/Mathc.ml, `dune build @install` rebuilt the installed binary
# (the exit code of `mathc verify` changed from 3 to 4) and
# `dune runtest` STILL ran the old binary -- the cram case expected
# the new exit code and passed. After `dune clean`, the same
# `dune runtest` saw the new binary and failed, as it should.
#
# So a developer can change the kernel and have the conformance suite
# certify the PREVIOUS kernel, and the suite reports green. That is
# the worst possible shape for a gate: it says "verified" about code
# that was never run.
#
# The cure is the clean, and the clean is expensive, so it is paid
# only when the code actually changed. That is what this script
# answers.
#
# USAGE.
#   scripts/kernel-stamp.sh changed    print "changed" or "unchanged"
#   scripts/kernel-stamp.sh record     write the current digest
#
# The caller compares the answer and decides. Two commands, so the
# comparison and the write cannot disagree about what "the current
# digest" is.

set -uo pipefail
cd "$(dirname "$0")/.."

STAMP_FILE=".local/kernel-stamp"

current_digest() {
  find lib bin tests scripts schemas -type f \
    \( -name '*.ml' -o -name '*.mli' -o -name '*.t' -o -name '*.sh' \
       -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) \
    -print0 2>/dev/null \
    | sort -z \
    | xargs -0 sha256sum 2>/dev/null \
    | sha256sum \
    | cut -d' ' -f1
}

case "${1:-}" in
  changed)
    now=$(current_digest)
    if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$now" ]; then
      echo "unchanged"
    else
      echo "changed"
    fi
    ;;
  record)
    mkdir -p .local
    current_digest > "$STAMP_FILE"
    echo "recorded"
    ;;
  *)
    echo "usage: scripts/kernel-stamp.sh {changed|record}" >&2
    exit 2
    ;;
esac
