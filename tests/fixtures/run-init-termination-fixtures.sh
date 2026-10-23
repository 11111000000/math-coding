#!/usr/bin/env bash
# Runs the fixtures that back the init-walk and attest-batch decisions.
# A separate script because `mathc attest-batch --run` splits its
# command on whitespace and refuses shell metacharacters: a `--run`
# with `&&` in it is rejected, and the rejection is correct.
set -uo pipefail
cd "$(dirname "$0")/../.."
fail=0
bash tests/fixtures/init-terminates-outside-tree.sh || fail=1
bash tests/fixtures/attest-batch-run-digest.sh || fail=1
exit "$fail"
