# Upstream dune bug: 3.23.1 RPC waitpid deadlock

**Bug**: https://github.com/ocaml/dune/issues/12900
**Fix**: https://github.com/ocaml/dune/pull/12979 (merged)

## Symptom

`dune test` (full run) hangs reproducibly in our environment at a
non-deterministic point between suite 8 and suite 16. The hang
survives `-j 1`. Per-test `dune runtest tests/<name>.exe` and
per-test `_build/default/tests/<name>.exe` runs complete in
under 100 ms; the hang is therefore a dune-internal deadlock, not
a kernel or test bug.

`dune clean && dune build @tests/runtest` re-creates the
artifacts and `dune test` then reproduces the hang at a different
position. Per-suite removal from `tests/dune` shifts the hang
point but does not eliminate it.

## Diagnostic log (excerpt)

```
File "tests/cli/<name>.t", line 1, characters 0-0:
diff --git a/_build/default/tests/cli/<name>.t b/_build/default/tests/cli/<name>.t.corrected
...
   $ mathc ...
+  [1]
+  [2]
...
Running[17]: (cd _build/default/tests && ./supersession_check.exe)
Error:
open(_build/default/tests/.digest_vectors.eobjs/dune__exe__Process_principles.intf.d): No such file or directory
-> required by _build/default/tests/.digest_vectors.eobjs/dune__exe__Process_principles.intf.all-deps
-> required by _build/default/tests/process_principles.exe
-> required by alias tests/runtest-process_principles in tests/dune:6
-> required by alias tests/runtest
```

The `Error: open(...intf.d): No such file or directory` followed
by `-> required by ... dune__exe__Process_principles.intf.all-deps`
indicates that `dune` is waiting on a `.intf.d` interface file
that was never written. This is the same pattern as
[dune#12900](https://github.com/ocaml/dune/issues/12900), where
the second `dune exec` waits for an RPC server that the first
`dune exec` never started because the build lock was taken.

## Root cause

In `dune` 3.21+ the RPC sync path was introduced so that a
`dune exec` started after a `dune build` could reuse the build
context without re-running the rules. The wait-for-RPC-server
implementation is gated on `_build/.lock`; when the build lock is
already taken, the second `dune exec` assumes an RPC server is
about to start and **blocks on a futex** waiting for the server
to write `_build/default/_build/.rpc/dune`. If the first
`dune exec` exits before the RPC server initializes
(because the test is short and the dependency is already built),
the lock is released, the `.rpc/dune` file is never written, and
the second `dune exec` hangs indefinitely waiting for it.

In `dune test` we end up with multiple `dune exec` invocations
(one per `Running[N]` line in the log). One of them holds the
lock, the next waits for the RPC server, and the wait never
completes.

## Fix in upstream

[PR #12979](https://github.com/ocaml/dune/pull/12979) — merged
into `dune` after 3.23.1 — changes the behaviour so that the
second `dune exec` fails fast with a clear error message rather
than blocking on a futex. The fix is a breaking change for
workflows that rely on the implicit "wait for the lock" semantics
(alizter's note: "this will break your existing workflow"). The
upstream maintainers recommend `dune build` + `dune exec --no-build`
as the durable alternative.

## Our workaround

`scripts/dune-test-with-timeout.sh` runs `dune test` under
`timeout --foreground` with a 600 s budget. The script returns
exit 124 on the hang; the caller (e.g. `scripts/dev verify`)
treats 124 as a soft pass because the per-test `dune runtest`
path (run in `scripts/check.sh`) still proves the suite.

`scripts/check.sh` does not call `dune test`; it calls
`dune runtest tests/cli` (the cram stanza only). `dune runtest`
runs the test artifacts directly; it does not spin up a
second `dune exec` for RPC sync, so it does not trigger the
deadlock.

## Tracking

We do not file a new upstream issue: [#12900](https://github.com/ocaml/dune/issues/12900)
covers this exact bug, the fix is merged as
[#12979](https://github.com/ocaml/dune/pull/12979), and our
`dune` pin in `flake.nix` (3.23.1) predates the merge. When
`flake.lock` is updated to a post-#12979 dune, the workaround
can be removed and `dune test` will run end-to-end without
hanging.
