# brownfield-install-cycle-test

## Thesis

The brownfield install cycle (install → verify → uninstall)
must work in isolation. A copy of the convention is
installed into a tmp directory, verified by axiom A6, then
uninstalled. The cycle is non-destructive: the tmp directory
is removed afterwards; the host repository is unchanged.

## Antithesis

A brownfield install that **seems** to work but **silently**
fails to copy critical files is a foot-gun. axiom Self-Application
runs on the source repository, not on the installed copy;
if the copy is incomplete, axiom A6 fails downstream.

A test that runs in the source repository and **trusts** the
install script is **circular**. The test must be **isolationist**:
it must verify that the installed copy **itself** is functional.

## Synthesis

`core/install/install-smoke-test.sh` performs the cycle:

```
1. Create a tmp directory: /tmp/mc-test-XXXXXX
2. Copy the convention payload: install.sh /tmp/mc-test-XXXXXX
3. Run axiom A6 in the copy: sh .math-coding/math-coding probe
4. Assert: probe exits 0
5. Uninstall: sh .math-coding/math-coding uninstall /tmp/mc-test-XXXXXX
6. Assert: .math-coding/ is removed
7. Cleanup: rm -rf /tmp/mc-test-XXXXXX
```

Each step is a check. The test fails if any step fails. The
test runs **in** `tests/run.sh` as Case 16.

## Worked example

```
$ sh tests/run.sh
...
Case 16: brownfield-install-cycle
  install: ok
  probe-in-installed: ok (axiom A6 in /tmp/mc-test-XXXXXX)
  uninstall: ok
  cleanup: ok
  PASS: brownfield-install-cycle
```

The test is hermetic: nothing in the host repository is
modified. The test only uses /tmp/, which is **outside** the
git working tree.

## Surface impact

touches: `core/install/install-smoke-test.sh` (new),
`tests/run.sh` (Case 16), `.github/workflows/convention-ci.yml`
(additionally runs the test in CI)

## Proof

`tests/run.sh` Case 16 runs the cycle and asserts each
step. axiom Self-Application holds iff the test exits 0.
The test is reproducible: a fresh tmp directory is created
each run, so state from previous runs does not contaminate
the new run.