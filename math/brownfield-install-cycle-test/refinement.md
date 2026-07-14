# Refinement: brownfield-install-cycle-test

## State

- pre: install.sh is hand-tested during genesis. axiom A6
  holds in the source repository. The installed copy is
  not auto-tested.
- post: a hermetic test runs install + verify + uninstall
  in /tmp. axiom A6 holds in the copy. The host repository
  is unchanged.

## Operation

`core/install/install-smoke-test.sh`:

```
TEST_DIR=$(mktemp -d)
sh install.sh "$TEST_DIR"
(cd "$TEST_DIR" && sh .math-coding/math-coding probe)
(cd "$TEST_DIR" && sh .math-coding/math-coding uninstall "$TEST_DIR")
[ -d "$TEST_DIR/.math-coding" ] && echo "FAIL: uninstall" || echo "ok"
rm -rf "$TEST_DIR"
```

`tests/run.sh` Case 16 calls this script and reports PASS/FAIL
based on the exit code.

## Mapping

| step             | check                          |
|------------------|--------------------------------|
| install          | exit 0 of install.sh           |
| probe-in-copy    | exit 0 of probe in $TEST_DIR   |
| uninstall        | exit 0 of uninstall.sh         |
| cleanup          | $TEST_DIR removed              |

## Invariant preservation

- The host repository is unchanged.
- The host's .git/ is unchanged.
- axiom Self-Application holds in both source and copy.
- $TEST_DIR is removed at end of test.

## Test obligation

`tests/run.sh` Case 16:
```
TEST_DIR=$(mktemp -d) || exit 2
sh install.sh "$TEST_DIR" || { rm -rf "$TEST_DIR"; exit 1; }
(cd "$TEST_DIR" && sh .math-coding/math-coding probe) || { ...; exit 1; }
(cd "$TEST_DIR" && sh .math-coding/math-coding uninstall "$TEST_DIR") || { ...; exit 1; }
[ -d "$TEST_DIR/.math-coding" ] && { ...; exit 1; }
rm -rf "$TEST_DIR"
exit 0
```

The test exits 0 iff install + verify + uninstall cycle
completes without error. axiom Self-Application holds iff
the test passes.

## Runtime check

None. The test runs at commit time (in CI and locally).