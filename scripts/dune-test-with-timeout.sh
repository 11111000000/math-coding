#!/usr/bin/env bash
# scripts/dune-test-with-timeout.sh
#
# Workaround wrapper around `dune test` for the dune 3.23.1 RPC
# deadlock tracked at https://github.com/ocaml/dune/issues/12900
# (fixed by https://github.com/ocaml/dune/pull/12979). Symptom: when
# `dune test` runs the full `(tests ...)` stanza, the harness hangs
# at a non-deterministic point (anywhere between suite 8 and 16, on
# every reproducer we've tried). The hang survives `-j 1`. Per-test
# `dune runtest tests/<name>.exe` and per-test
# `_build/default/tests/<name>.exe` runs each suite in under 100 ms;
# the hang is therefore a dune-internal RPC sync bug, not a kernel or
# test bug. Disabling individual test suites only shifts the hang
# point but does not eliminate it. The cheapest available fix is to
# give the whole test run a wall-clock budget: if `dune test` does
# not return in N seconds, the wrapper kills the process tree,
# surfaces the failure explicitly, and the developer can fall
# back to the per-test `dune runtest` invocation.
#
# When `flake.lock` is updated to a dune that contains PR #12979
# (post-3.23.1), the workaround can be removed and `dune test`
# will run end-to-end without hanging. See
# docs/upstream-bugs/dune-3.23.1-rpc-hang.md.
#
# Default budget: 600 seconds (10 min). The 22-suite gate
# (the only time `dune test` reliably runs end-to-end in this
# environment) takes ~12 s on warm cache, so 600 s is 50x
# margin; bumping it to 1800 s is safe if the CI host is slow.
set -euo pipefail

TIMEOUT_SECONDS="${DUNE_TEST_TIMEOUT_SECONDS:-600}"

log() { printf '%s dune-test-with-timeout: %s\n' "$(date -Iseconds 2>/dev/null || date)" "$*" >&2; }

# `dune` (3.23.1) sometimes leaves a bwrap child wedged if the
# parent is hard-killed, so we use `timeout --foreground` to
# deliver SIGTERM, wait the full grace, and SIGKILL only on
# timeout. `--foreground` is required so the shell exit status
# reflects `dune test`'s exit, not `timeout`'s.
run_dune() {
  log "running 'dune test --root .' (budget=${TIMEOUT_SECONDS}s)"
  timeout --foreground --kill-after=15 --signal=TERM "${TIMEOUT_SECONDS}" \
    nix develop .#test --command bash -c "dune test --root . 2>&1"
}

if run_dune; then
  log "dune test completed within budget"
  exit 0
else
  # `rc=$?` MUST live inside the `else`. Bash defines the exit status
  # of a false `if` with no `else` as 0, so a bare `rc=$?` on the line
  # after `fi` always reads 0 and this script always exits 0.
  rc=$?
fi
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
  log "dune test exceeded the ${TIMEOUT_SECONDS}s budget (rc=$rc) — dune 3.23.1 RPC deadlock (issue #12900, fixed by PR #12979)"
  log "fall back to per-test 'dune runtest tests/<name>.exe' (see decisions/disable-hanging-alcotest-tests-2026-10.yaml and docs/upstream-bugs/dune-3.23.1-rpc-hang.md)"
  exit 124
fi
log "dune test failed (rc=$rc) without timing out"
exit "$rc"
