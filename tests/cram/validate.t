Validate a Decision fixture via the mathc CLI.

The test invokes `_build/default/bin/mathc.exe validate` against the
positive-minimal Decision fixture and asserts the accept verdict.

We anchor the binary at `$INSIDE_DUNE/bin/mathc.exe` because dune 3.23
cram tests are sandboxed and do not expose the build dir through
relative `../bin/` paths from inside the cram test working dir.
`$INSIDE_DUNE` is set in the cram test environment to the absolute
build directory (e.g. `_build/default`), so the binary resolves
unambiguously.

The fixture path is anchored at `$DUNE_SOURCEROOT`, the project root
where dune was invoked. Together these two env vars let the cram test
address both the build artefact and the source tree without depending
on the sandbox-internal layout.

  $ mathc="$INSIDE_DUNE/bin/mathc.exe"
  $ fixture="$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json"
  $ "$mathc" validate "$fixture"
  accept: /home/az/Projects/math-coding/fixtures/conformance/decision/positive-minimal.json
    decision: redis-origin-fallback
    revision: rev:41aa92
    obligations: 1
    assumptions: 1
