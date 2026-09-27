---
schema: math-coding/3.0-alpha
id: adapters
revision: 2

intent: |
  Add the first non-CLI adapters to the math-coding 3.0-alpha
  protocol: a JUnit XML importer and a Git changed-files
  emitter. Attestations today carry results sourced from human
  review (kind=review), build pipelines (kind=build), and
  observation (kind=observation), but not from automated test
  runners that publish JUnit XML; and there is no machine-readable
  way to enumerate the files changed between two git refs, which
  the `mc context` capsule and any future diff-driven obligation
  both need. The v3-alpha obligations `junit-attestation-import`
  and `git-changed-files-adapter` close those two gaps by giving
  `mc attest FILE` the ability to read a JUnit XML report and
  emit a JSON summary on stdout, and by giving `mc assess BASE
  HEAD` the ability to emit a JSON array of changed file paths.
  The kernel stays offline and pure; the JUnit importer lives
  under `lib/junit/` and the Git emitter lives under `lib/git/`,
  both as hand-rolled parsers (no new deps), and `bin/Mathc.ml`
  is the only I/O boundary. This decision records both
  obligations; the implementations land as separate commits so
  that the decision itself is reviewable without bundling code.

  This is the implementation record (revision 2): the
  git-changed-files-adapter obligation is added as a parallel
  obligation to the existing junit-attestation-import obligation.
  Both adapters landed in v0.0.8 (commits 5486c13 and bcce74d);
  the original decision (revision 1, v0.0.8) recorded only the
  JUnit obligation explicitly. Per audit D7 from
  doc/AUDIT-0.0.11.md, the cheaper remedy is to keep a single
  decision file covering both obligations and document that fact
  in the audit; this revision adopts that remedy.

commitment: |
  bin/Mathc.ml gains two new subcommands: `attest FILE` and
  `assess BASE HEAD`.

  `mc attest FILE` exits 0 on success and prints a JSON object
  on stdout containing at minimum the keys "suite_name",
  "test_count", "failure_count", "error_count", "skip_count",
  and "tests" (an array of per-testcase records each carrying
  at minimum "name", "classname", and "result"). Exit code 2 is
  used when the path is wrong (file not found, unreadable) so
  callers can distinguish "missing path" from "unusual XML";
  malformed or unusual XML inside an existing file is reported
  via a JSON field and does not produce a non-zero exit. The
  XML parser is hand-rolled inside `lib/junit/junit.ml` and is
  a JUnit-specific subset (testsuite, testcase, failure, error,
  skipped, system-out/system-err CDATA, attribute
  name="value").

  `mc assess BASE HEAD` exits 0 on success and prints a JSON
  array of changed file paths on stdout, obtained by running
  `git -C <cwd> diff --name-only BASE..HEAD` via
  `lib/git/git_diff.changed_files`. cwd is `Sys.getcwd ()`;
  BASE and HEAD may be any git ref. Exit code 2 is used when
  the git invocation fails (git not on PATH, not a git repo,
  BASE or HEAD unknown, or wrong number of positional
  arguments); exit 3 only on uncaught internal exceptions.
  Each line of git's output is trimmed of trailing whitespace
  and empty lines are filtered; the result is rendered with
  `Jsonl.stringify` for correctness.

  The kernel (lib/codec.ml, lib/decision.ml, lib/diagnostic.ml,
  lib/jsonl.ml) remains unchanged and offline. No new runtime
  dependency is added; both adapters rely only on Stdlib and
  on the existing `mathcoding_core` library.

scope:
  capabilities:
    - junit-attestation-import
    - git-changed-files-adapter
  paths:
    - "bin/Mathc.ml"
    - "bin/dune"
    - "lib/junit/junit.ml"
    - "lib/junit/dune"
    - "lib/git/git_diff.ml"
    - "lib/git/dune"
    - "lib/dune"
    - "tests/fixtures/junit-adapter.sh"
    - "tests/fixtures/git-adapter.sh"
    - "bootstrap/adapters.md"
  exclusions:
    - "lib/codec.ml"
    - "lib/decision.ml"
    - "lib/diagnostic.ml"
    - "lib/jsonl.ml"
    - "lib/domain.ml"

outcomes:
  - id: junit-attestation-import
    statement: |
      `mc attest FILE` reads FILE as a JUnit XML report,
      parses it via Junit.parse_junit, and prints a JSON object
      on stdout with at least the keys "suite_name",
      "test_count", "failure_count", "error_count",
      "skip_count", and "tests". Each item in "tests" carries
      "name", "classname", and "result" (one of "pass",
      "fail", "error", "skip", or "unknown"). Exit 0 on
      success. Exit 2 only when the file path is wrong
      (missing, unreadable). Malformed XML is reported via
      an "error" JSON field with exit 0 because attestation
      import is informational.

  - id: git-changed-files-adapter
    statement: |
      `mc assess BASE HEAD` reads the cwd via `Sys.getcwd ()`,
      invokes `Git_diff.changed_files ~cwd ~base ~HEAD` (which
      runs `git -C cwd diff --name-only BASE..HEAD` via
      `Sys.command` with stdout redirected to a temp file),
      and prints a JSON array of the resulting file paths on
      stdout via `Jsonl.stringify`. Exit 0 on success. Exit 2
      when the git invocation fails (git not on PATH, not a
      git repo, BASE or HEAD unknown) or when the wrong number
      of positional arguments is supplied. Exit 3 only on
      uncaught internal exceptions. Empty trailing lines from
      git's output are filtered; the adapter never silently
      drops non-empty entries.

countercase: |
  Why not defer `mc attest` until the 3.0 kernel exists? The
  3.0 kernel's `attestations` collection already expects
  attestations of kind=test that carry a producer_run linking
  them to a CI artifact. A JUnit XML report is the natural
  upstream producer for those attestations. Implementing the
  importer now lets the conformance corpus exercise the round
  trip (XML → JSON → attestation candidate) without waiting
  for kernel 3.0.

  Why not defer `mc assess` until the 3.0 kernel exists?
  Because the `mc context` capsule and any future diff-driven
  obligation both need to enumerate the files changed between
  two git refs, and shelling out from the kernel would violate
  OCAML_BEST_PRACTICES §1.3 (kernel stays offline). Implementing
  the Git emitter now, in the same release as the JUnit
  importer, lets the conformance corpus exercise both adapters
  side-by-side and keeps the kernel pure.

  Why one decision file for two adapters instead of two?
  Because (a) both adapters share the same architectural rule
  (separate library, hand-rolled parser, no new dep, kernel
  stays offline); (b) they landed in adjacent commits (5486c13
  and bcce74d) at v0.0.8; and (c) splitting them into two
  decision files would duplicate the §10.1 split rule, the
  bin/Mathc.ml is-the-only-I/O-boundary rule, and the
  no-new-deps rule. One file, two obligations, two outcomes,
  two fixtures: the cheapest correct shape.

  Why not add a dependency (yojson, xmlm, ocaml-xml)? The
  protocol forbids adding runtime deps to the kernel, and
  OCAML_BEST_PRACTICES §7.3 explicitly rejects yojson for the
  bin/ layer too. Adding xmlm or ocaml-xml would expand the
  reproducible-build closure for a parser that only needs the
  JUnit subset. A 150-line hand-rolled tokenizer is enough
  for `<testsuite ...>`, `<testcase ...>`, `<failure>`,
  `<error>`, `<skipped/>`, CDATA-safe text, and attribute
  name="value" pairs. Anything outside the subset is reported
  via the "error" JSON field with exit 0. The Git emitter
  needs no parser at all; it just consumes one line per file
  via `In_channel.with_open_bin` on a tempfile (avoiding the
  `in_channel_length` on pipes trap, OCAML_BEST_PRACTICES
  §11.16).

  Why exit 0 on malformed XML? An attestation importer is
  observational: the caller wants a report, not a fatal. The
  obligation is "report what we found", not "guarantee the
  XML is well-formed". Exit 2 is reserved for "we couldn't
  even open the path" so CI wrappers can distinguish
  infrastructure failure (missing path) from data-shape
  surprise (unusual XML). The decision rule is documented
  in the obligation's claim above.

  Why exit 2 on a failed `mc assess`? The Git emitter
  depends on an external tool (the `git` binary) and on
  the cwd being a git working tree; both can be wrong even
  when the user typed the right thing. Exit 2 is the same
  "infrastructure" exit code `mc attest` uses for a missing
  path, and it is reserved by spec/semantics.md for "we
  couldn't even attempt the operation". Exit 3 is reserved
  for uncaught internal exceptions. A successful git call
  with zero changed files still exits 0 with the empty array
  `[]` on stdout — the obligation does not require at least
  one file to be present.

  Why hand-rolled XML in `lib/junit/junit.ml` rather than
  OCAML_BEST_PRACTICES §10.1's split-into-subdirectories?
  The kernel still has 11 modules; §10.1 says split when we
  add the 12th-and-onward. The JUnit adapter is the 12th.
  But it is also the first adapter, so the split is
  justified: `lib/junit/dune` is a new library stanza
  declaring only its own deps, and `lib/junit/junit.ml`
  becomes the public module `Junit`. The kernel's
  `lib/dune` is updated to add the new library to its
  `(libraries ...)` list. OCAML_BEST_PRACTICES §10.1
  rule 1 says "Adapter `dune` files list **only** their
  own deps"; the JUnit adapter has none, so its `dune`
  has no `:libraries` clause beyond `(wrapped false)`.

  Why a separate library rather than adding to
  mathcoding_core? Because (a) the kernel is intentionally
  pure and offline; an XML parser over arbitrary input is a
  step away from "string -> Jsonl.value" toward "string ->
  structured value"; (b) the Git adapter, landing in parallel,
  also produces structured values from raw text, and the
  parallel structure (lib/git/dune + lib/git/git_diff.ml,
  lib/junit/dune + lib/junit/junit.ml) is easier to review
  than one flat module; (c) a future MCP adapter that needs
  either parser can pull both without dragging in the kernel.

assumptions:
  - id: junit-xml-subset-stable
    state: assumed
    statement: |
      Real-world JUnit XML reports (Surefire, Gradle,
      pytest-junit, Cargo's `cargo test -- --format junit`)
      all use a stable subset: a top-level `<testsuite>`
      (or `<testsuites>` wrapper around multiple), zero or
      more `<testcase>` children, optional `<failure>`,
      `<error>`, `<skipped/>` children per testcase, and
      attribute-style name="value" pairs for identifiers
      and counters. The hand-rolled parser handles this
      subset and treats anything outside it as a soft parse
      error reported via the JSON "error" field.
    owner: human:maintainer
    consequence_if_false: |
      If a real CI tool emits JUnit XML the parser cannot
      read, the JSON "tests" array is shorter than expected
      and the "error" field is populated. The fixture asserts
      exit 0 even in the soft-error case so the adapter stays
      observable. A future obligation may extend the parser
      to handle more of the spec (e.g., `<testsuites>`
      wrappers, `<system-out>`, `<properties>`).
    review_on:
      - signal: fixture-shows-soft-error-on-real-xml
      - signal: testsuite-wrapper-needed

  - id: attest-is-informational
    state: assumed
    statement: |
      The `mc attest` subcommand is observational; it does
      not write to the kernel's attestation store and does
      not produce a Decision.t. It emits JSON. A future
      obligation may add `mc attest FILE --into DECISION_ID`
      which calls into the kernel to register an attestation;
      that obligation is not part of this decision.
    owner: human:maintainer
    consequence_if_false: |
      If `mc attest` becomes a write-path, it must respect
      OCAML_BEST_PRACTICES §1.3 (kernel stays offline) by
      funneling through a new lib/attest.ml adapter that
      builds the Domain.attestation record and emits it
      through Jsonl.stringify.
    review_on:
      - signal: attest-becomes-write-path

obligations:
  - id: junit-attestation-import
    outcome: junit-attestation-import
    claim: |
      `mc attest FILE` MUST:
        - parse a JUnit XML file into a typed Test_run.t
          via the hand-rolled parser in lib/junit/junit.ml
        - return JSON on stdout with keys including
          "suite_name", "test_count", "failure_count",
          "error_count", "skip_count", and "tests"
        - exit 0 on a successful parse, even when the XML
          is unusual; exit 2 only when the path is wrong
          (file not found, unreadable); exit 3 only on
          uncaught internal exceptions
        - add no new runtime dependency; the XML parser
          is hand-rolled
      The kernel (lib/codec.ml, lib/decision.ml,
      lib/diagnostic.ml, lib/jsonl.ml) remains offline.
    acceptance:
      all:
        - verifier: tests/fixtures/junit-adapter.sh
          result: pass

  - id: git-changed-files-adapter
    outcome: git-changed-files-adapter
    claim: |
      `mc assess BASE HEAD` MUST:
        - resolve cwd via Sys.getcwd () (the user's working
          directory at invocation time) and BASE/HEAD via the
          positional arguments
        - call Git_diff.changed_files ~cwd ~base ~head, which
          runs `git -C cwd diff --name-only BASE..HEAD` via
          Sys.command (with stdout redirected to a tempfile)
          and returns Ok paths or Error message
        - return a JSON array of changed file paths on stdout
          via Jsonl.stringify, with empty lines filtered and
          trailing whitespace trimmed; the empty array [] is a
          valid response when no files differ
        - exit 0 on a successful git call (including the
          empty-result case); exit 2 when the git invocation
          fails (git not on PATH, not a git repo, BASE or HEAD
          unknown) or the wrong number of positional arguments
          is supplied; exit 3 only on uncaught internal
          exceptions
        - add no new runtime dependency; the emitter uses
          only Stdlib (Sys.command, In_channel.with_open_bin)
          and the existing mathcoding_core library
      The kernel (lib/codec.ml, lib/decision.ml,
      lib/diagnostic.ml, lib/jsonl.ml) remains offline.
      This is the obligation declared by the v0.0.8 commit
      5486c13 (the implementation commit) and recorded
      explicitly in this decision at revision 2; the original
      revision 1 grouped it implicitly under the JUnit
      obligation, which audit D7 in doc/AUDIT-0.0.11.md
      flagged as a documentation gap.
    acceptance:
      all:
        - verifier: tests/fixtures/git-adapter.sh
          result: pass

reversal:
  - signal: kernel-attestation-store-arrives
    action: promote-attest-to-write-path
  - signal: junit-xml-parser-becomes-bottleneck
    action: extract-xml-tokenizer-to-its-own-module
  - signal: ocaml-xml-or-xmlm-becomes-stdlib
    action: replace-hand-rolled-parser-with-library-and-revise-bp

risk:
  declared_triggers:
    - hand-rolled-xml-parser-diverges-from-real-junit
    - exit-code-2-vs-exit-0-confusion
    - adapter-pulls-yaml-or-other-deps-into-kernel
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3@2
    - doc/AUDIT-0.0.11.md#D7
  superseded_by: []
