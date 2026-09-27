---
schema: math-coding/3.0-alpha
id: adapters
revision: 1

intent: |
  Add the first non-CLI adapter to the math-coding 3.0-alpha
  protocol: a JUnit XML importer. Attestations today carry
  results sourced from human review (kind=review), build
  pipelines (kind=build), and observation (kind=observation), but
  not from automated test runners that publish JUnit XML. The
  v3-alpha obligation junit-attestation-import closes that gap
  by giving `mc attest FILE` the ability to read a JUnit XML
  report and emit a JSON summary on stdout. The kernel stays
  offline and pure; the JUnit importer lives under `lib/junit/`
  as a hand-rolled XML parser (no new deps), and `bin/Mathc.ml`
  is the only I/O boundary. This decision records the
  obligation; the implementation lands as a separate commit so
  that the decision itself is reviewable without bundling code.

commitment: |
  bin/Mathc.ml gains an `attest FILE` subcommand. `mc attest
  FILE` exits 0 on success and prints a JSON object on stdout
  containing at minimum the keys "suite_name", "test_count",
  "failure_count", "error_count", "skip_count", and "tests"
  (an array of per-testcase records each carrying at minimum
  "name", "classname", and "result"). Exit code 2 is used when
  the path is wrong (file not found, unreadable) so callers can
  distinguish "missing path" from "unusual XML"; malformed or
  unusual XML inside an existing file is reported via a JSON
  field and does not produce a non-zero exit. The XML parser
  is hand-rolled inside `lib/junit/junit.ml` and is a JUnit-
  specific subset (testsuite, testcase, failure, error, skipped,
  system-out/system-err CDATA, attribute name="value"). The
  kernel (lib/codec.ml, lib/decision.ml, lib/diagnostic.ml,
  lib/jsonl.ml) remains unchanged and offline. No new runtime
  dependency is added; the parser relies only on Stdlib.

scope:
  capabilities:
    - junit-attestation-import
  paths:
    - "bin/Mathc.ml"
    - "bin/dune"
    - "lib/junit/junit.ml"
    - "lib/junit/dune"
    - "lib/dune"
    - "tests/fixtures/junit-adapter.sh"
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

countercase: |
  Why not defer `mc attest` until the 3.0 kernel exists? The
  3.0 kernel's `attestations` collection already expects
  attestations of kind=test that carry a producer_run linking
  them to a CI artifact. A JUnit XML report is the natural
  upstream producer for those attestations. Implementing the
  importer now lets the conformance corpus exercise the round
  trip (XML → JSON → attestation candidate) without waiting
  for kernel 3.0.

  Why not add a dependency (yojson, xmlm, ocaml-xml)? The
  protocol forbids adding runtime deps to the kernel, and
  OCAML_BEST_PRACTICES §7.3 explicitly rejects yojson for the
  bin/ layer too. Adding xmlm or ocaml-xml would expand the
  reproducible-build closure for a parser that only needs the
  JUnit subset. A 150-line hand-rolled tokenizer is enough
  for `<testsuite ...>`, `<testcase ...>`, `<failure>`,
  `<error>`, `<skipped/>`, CDATA-safe text, and attribute
  name="value" pairs. Anything outside the subset is reported
  via the "error" JSON field with exit 0.

  Why exit 0 on malformed XML? An attestation importer is
  observational: the caller wants a report, not a fatal. The
  obligation is "report what we found", not "guarantee the
  XML is well-formed". Exit 2 is reserved for "we couldn't
  even open the path" so CI wrappers can distinguish
  infrastructure failure (missing path) from data-shape
  surprise (unusual XML). The decision rule is documented
  in the obligation's claim above.

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
  parallel structure (lib/git/dune + lib/git/git.ml,
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
  superseded_by: []
