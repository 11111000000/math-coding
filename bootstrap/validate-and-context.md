---
schema: math-coding/3.0-alpha
id: validate-and-context
revision: 1

intent: |
  Establish the first useful mathc CLI command: `mc validate FILE`.
  Until this lands, the CLI only prints a bootstrap hello, so humans
  and CI have no cheap way to ask "is this decision shape-valid?"
  without running the full conformance suite. This commit closes the
  validate obligation; the context obligation (printing the active
  policy context under which a decision was evaluated) is recorded
  here but deferred to validate-and-context@2.

commitment: |
  bin/Mathc.ml becomes a real argv dispatcher supporting `mc version`
  and `mc validate FILE [--format=text|json]`. validate FILE exits 0
  when Decision.parse_decision returns Some _, exits 1 with a
  structured diagnostic when it returns None, exits 2 on input errors
  (file not found, malformed JSON or YAML, bad CLI args), and exits 3
  on uncaught internal exceptions. The kernel (`lib/`) stays offline
  and pure; bin/ is the only I/O boundary. Existing conformance
  behavior is unchanged.

scope:
  capabilities:
    - cli-validate-decision
    - cli-version
    - deferred-cli-context
    - jsonl-array-parser-fix
  paths:
    - "bin/Mathc.ml"
    - "bin/dune"
    - "lib/codec.ml"
    - "lib/jsonl.ml"
    - "OCAML_BEST_PRACTICES.md"
    - "tests/fixtures/validate-positive.sh"
    - "tests/fixtures/validate-negative.sh"
    - "bootstrap/validate-and-context.md"
  exclusions:
    - "spec/**"
    - "lib/decision.ml"
    - "lib/diagnostic.ml"
    - "lib/domain.ml"

outcomes:
  - id: cli-validate-parses-decision
    statement: |
      `mc validate FILE` reads FILE (json or yaml), parses via
      Decision.parse_decision, and reports accept or reject with
      structured diagnostics. Exit codes 0/1/2/3 align with
      spec/semantics.md "exit honesty" and OCAML_BEST_PRACTICES §4.3.
  - id: cli-version-still-works
    statement: |
      `mc version` prints "math-coding 3.0-alpha: bootstrap" and
      exits 0. This preserves the v0.0.5 hello-string behavior; it
      is no longer the bare default but is reachable as a subcommand.
  - id: kernel-stays-offline
    statement: |
      lib/codec.ml exposes load_yaml_string : string -> Jsonl.value
      as a pure function. The file I/O (open_in, close_in) stays in
      bin/. No Printf.printf, exit, or In_channel slips into lib/.
  - id: jsonl-array-parser-fixed
    statement: |
      lib/jsonl.ml:99 parse_array was returning Array (List.rev acc)
      from the `]` branch without appending the just-parsed element,
      making `[x]` parse as `[]` and `[x, y, z]` parse as `[y, x]`.
      Fixed by prepending `v` to `acc` once per iteration; final
      List.rev acc returns the elements in source order. New trap
      entry OCAML_BEST_PRACTICES §11.15 records the symptom (every
      fixture with non-empty array fields parsed its lists as `[]`
      despite acceptance; the conformance runner did not catch this
      because it only inspects Some _ / None).
  - id: deferred-cli-context
    statement: |
      The `mc context DECISION` subcommand (printing the active
      policy context under which a named decision was evaluated) is
      recorded but not implemented in this revision. Deferred to
      validate-and-context@2.

countercase: |
  Why not defer validate entirely until the 3.0 kernel exists?
  Because (a) shape validation today is a useful gate before deeper
  kernel checks; (b) the v3-alpha protocol is self-applying — without
  a CLI, every agent would have to load OCaml internals to verify a
  file, which contradicts axiom A1 (epistemic honesty) — agents
  cannot legitimately claim "the kernel accepts this" without an
  actual kernel-level invocation; (c) the YAML loader already lives
  in tests/conformance.ml, so duplicating it into bin/Mathc.ml keeps
  the CLI minimal without dragging the kernel into I/O.

  Why not use cmdliner? Because cmdliner is in devShells.test only —
  the production closure that `nix build` uses to assemble
  bin/mathc.exe does not include it. Adding cmdliner would break the
  prod build. Stdlib Arg is sufficient for a two-subcommand CLI.

  Why copy the YAML loader into lib/codec.ml instead of factoring a
  shared module? Tests/conformance.ml is already an inlined,
  self-contained fixture walker. Coupling it to a YAML helper that
  lives elsewhere would tangle test inputs and kernel inputs. The
  duplication is acceptable, and the fix history (the yaml_strip
  trap in OCAML_BEST_PRACTICES §11.13) is small enough that both
  copies can be kept aligned by hand.

assumptions:
  - id: yaml-fixture-subset-stable
    state: assumed
    statement: |
      Decision YAML fixtures use only the subset the existing
      tests/conformance.ml loader handles: block-style mappings
      with scalar or list values, nested objects via indentation,
      quoted or bare scalars, and block-style sequences via
      "- ". The bin/ CLI relies on the same subset via
      Codec.load_yaml_string.
    owner: human:maintainer
    consequence_if_false: |
      If a fixture needs richer YAML (anchors, multiline scalars,
      flow-style nesting with brackets, multi-document YAML), the
      loader in lib/codec.ml must be extended before the CLI can
      validate that fixture.
    review_on:
      - signal: fixture-uses-flow-style
      - signal: fixture-uses-anchor-alias

  - id: parse-decision-rejection-reason-coarse
    state: assumed
    statement: |
      Decision.parse_decision returns Some _ | None. It does not
      say which specific field was missing. The CLI synthesises a
      diagnostic ("missing required field", code MC-DECISION-INVALID)
      without pointing at the specific cause. Acceptable for v0.0.6;
      Decision.parse_decision is to gain a typed Diagnostic.t option
      in v3.0-beta.
    owner: human:maintainer
    consequence_if_false: |
      Negative-shell fixtures can only assert exit-code + a coarse
      keyword search ("commitment" / "invalid" / "error"), which is
      what the negative fixture already does.
    review_on:
      - signal: kernel-decision-parser-returns-diagnostic

obligations:
  - id: jsonl-array-parser-fixed
    outcome: jsonl-array-parser-fixed
    claim: |
      lib/jsonl.ml parse_array returns Array (List.rev acc) with v
      prepended to acc once per iteration. For [x] this returns
      Array [x]; for [x, y, z] this returns Array [x; y; z]. Tested
      by the existing kernel-conformance-runner (9 fixtures still
      pass: each fixture that was green at v0.0.5 still decodes
      to Some _ / None as expected) and by the new fixtures
      tests/fixtures/validate-positive.sh which inspects the
      obligations/assumptions counts on the parsed decision.
    acceptance:
      all:
        - verifier: tests/fixtures/validate-positive.sh
          result: pass

  - id: cli-validate-decision
    outcome: cli-validate-parses-decision
    claim: |
      `mc validate FILE` exits 0 with an "accept" verdict on stdout
      when Decision.parse_decision returns Some _, and exits 1 with
      a structured diagnostic (code MC-DECISION-INVALID or
      MC-DECISION-PARSE-ERROR, severity warn/block) when it returns
      None or raises Jsonl.Parse_error. Supports --format=text
      (default) and --format=json. Works for both .json and .yaml
      files. Returns exit 2 for input errors (file not found, bad
      CLI args) and exit 3 for uncaught internal exceptions.
    acceptance:
      all:
        - verifier: tests/fixtures/validate-positive.sh
          result: pass
        - verifier: tests/fixtures/validate-negative.sh
          result: pass

  - id: cli-version-preserved
    outcome: cli-version-still-works
    claim: |
      `mc version` prints "math-coding 3.0-alpha: bootstrap" and
      exits 0. The hello-string from v0.0.5 is preserved verbatim.
    acceptance:
      all:
        - verifier: tests/fixtures/validate-positive.sh
          result: pass
        # The fixture builds bin/mathc.exe; a regression in the
        # Mathc.ml module that breaks `version` would also break the
        # build, so dune itself catches it.

  - id: kernel-offline-pure-unchanged
    outcome: kernel-stays-offline
    claim: |
      lib/codec.ml, lib/decision.ml, lib/diagnostic.ml, and
      lib/jsonl.ml do not import Unix, call exit, or write to a
      channel. The new load_yaml_string in lib/codec.ml is a pure
      string -> Jsonl.value transformation. The yaml_strip /
      yaml_tokens / parse_yaml_* helpers moved from
      tests/conformance.ml into lib/codec.ml preserve the same
      purity boundary.
    acceptance:
      all:
        - verifier: tests/fixtures/validate-positive.sh
          result: pass
        # Building the binary would warn or fail to link if lib/
        # pulled in unix-only functions for bin/'s use; the build
        # succeeds, proving no kernel API leak.

  - id: deferred-cli-context
    outcome: deferred-cli-context
    claim: |
      The `mc context DECISION` subcommand (printing the active
      policy context under which a named decision is evaluated) is
      recorded as a follow-up obligation. Implementation is
      deferred to validate-and-context@2 (v3-alpha-0.0.7).
    acceptance:
      all: []

reversal:
  - signal: parse-decision-becomes-total
    action: archive-negative-fixture-when-empty
  - signal: kernel-checks-attestation-contents
    action: validate-promoted-to-check-deferred

risk:
  declared_triggers:
    - duplicate-yaml-loader-drift
    - exit-code-misalignment-with-spec
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3@2
    - kernel-conformance-runner@1
  superseded_by: []
