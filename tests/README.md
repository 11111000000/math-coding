# tests/ — math-coding v0.854 self-tests (axiom Self-Application)

The tests in this directory verify that the convention
applies to itself. `sh tests/run.sh` runs all cases and
reports PASS/FAIL.

## What we test

  probe-axiom-a6         axiom Self-Application exits 0
  verify-structural      five-file contract holds
  drift-check            applications[] SHA vs HEAD
  seven-axiom-packets    all seven axiom directories exist
  seven-axioms-doc       docs/axioms.md lists seven axioms
  eight-theories         theories/ has eight .md files
  dispatcher-help        math-coding dispatcher responds
  axiom-a6-chain-closes  A6 depends on A0

## Adding a new test

Edit `tests/run.sh`. Each `run_case` invocation:

  run_case "<name>" "<shell command that exits 0 on success>"

The orchestrator tallies PASS/FAIL and exits with the number
of failures. Use this in CI:

  sh tests/run.sh && echo "all tests passed"

## Why these tests live in tests/, not in core/

Tests are a separate role. They are not part of the
convention's install payload; they live in the source
repository only. axiom Self-Application is verified by `core/self/probe.sh`;
the broader battery lives here.