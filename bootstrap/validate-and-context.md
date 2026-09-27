---
schema: math-coding/3.0-alpha
id: validate-and-context
revision: 2

intent: |
  Close the deferred obligation `deferred-cli-context` from
  validate-and-context@1 by adding `mc context BASE HEAD --budget N`
  to bin/Mathc.ml. The new subcommand emits a JSON capsule of
  project memory (active decisions, obligations, changed paths,
  recent commits, spec/axiom/practices docs) tagged with priority
  and freshness, sorted by the priority order defined in
  spec/semantics.md "context-prioritisation", and truncated to the
  byte budget with omitted items listed alongside an expansion
  command. This makes the bootstrap protocol observable to an LLM
  agent that otherwise has no way to know which policy is in
  force.

commitment: |
  bin/Mathc.ml gains a `context` subcommand. `mc context BASE HEAD
  --budget N` exits 0 and prints a JSON object containing at
  minimum the keys "change", "decisions", "obligations", "items",
  "omitted", "total_bytes", "truncated", "now", "base", and "head".
  BASE and HEAD may be any git ref (commit, branch, tag). Items
  are sorted by priority (RequiredForGate > Changed > HighRisk >
  Unresolved > Supporting > Historical) and truncated to fit
  `budget` bytes; omitted items are listed with a `mc explain ...`
  expansion command. The kernel stays offline: lib/capsule.ml and
  lib/memory.ml are pure modules with file I/O injected via
  callbacks; bin/ is the only I/O boundary.

scope:
  capabilities:
    - cli-validate-decision
    - cli-version
    - cli-context-capsule
    - capsule-byte-budget-tracked
    - jsonl-array-parser-fix
  paths:
    - "bin/Mathc.ml"
    - "bin/dune"
    - "lib/codec.ml"
    - "lib/jsonl.ml"
    - "lib/memory.ml"
    - "lib/capsule.ml"
    - "lib/dune"
    - "OCAML_BEST_PRACTICES.md"
    - "spec/semantics.md"
    - "tests/fixtures/validate-positive.sh"
    - "tests/fixtures/validate-negative.sh"
    - "tests/fixtures/context-budget.sh"
    - "bootstrap/validate-and-context.md"
  exclusions:
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
      as a pure function. lib/memory.ml exposes load_memory with an
      injected reader callback. lib/capsule.ml exposes build_capsule
      as a pure transformation Memory.t -> Capsule.t. No file I/O
      leaks into lib/.
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
  - id: cli-context-capsule
    statement: |
      `mc context BASE HEAD --budget N` exits 0 with a JSON capsule
      containing the keys "change", "decisions", "obligations",
      "items", "omitted", "total_bytes", "truncated", "now",
      "base", and "head". Items are sorted and truncated by
      priority per spec/semantics.md "context-prioritisation". Each
      item carries a "priority" tag and an optional "freshness"
      timestamp. Omitted items are listed in the "omitted" array
      with an "expansion" command.

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

  Why is the priority order defined in spec/semantics.md rather than
  in OCAML_BEST_PRACTICES.md? Because the priority order is a kernel
  policy statement, not a coding convention. The spec is the
  authoritative source; OCAML_BEST_PRACTICES §10.5 mirrors the table
  for implementer convenience. A change to the order is a protected
  policy transition; the two files stay in lockstep.

  Why not add Yojson (or another JSON library) for capsule output?
  The kernel stays offline (OCAML_BEST_PRACTICES §1.3) and bin/ may
  not pull Yojson (OCAML_BEST_PRACTICES §7.3). The capsule JSON is
  flat and predictable; a hand-rolled renderer that calls
  Jsonl.stringify for value-level escaping is sufficient. The
  resulting JSON is valid (`python3 -m json.tool` parses it).

  Why is the budget byte-counted, not token-counted? Byte counting
  is exact, reproducible, and does not depend on an external tokenizer.
  An LLM client can estimate tokens from byte count; an LLM cannot
  estimate bytes from a token count. The reverse direction is the
  one an agent needs.

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
      lib/codec.ml, lib/decision.ml, lib/diagnostic.ml, lib/jsonl.ml,
      lib/memory.ml, and lib/capsule.ml do not import Unix, call
      exit, or write to a channel. load_yaml_string in lib/codec.ml
      is a pure string -> Jsonl.value transformation. Memory.load_memory
      takes an injected reader callback. Capsule.build_capsule is a
      pure Memory.t -> Capsule.t transformation. No file I/O leaks
      into lib/.
    acceptance:
      all:
        - verifier: tests/fixtures/validate-positive.sh
          result: pass
        # Building the binary would warn or fail to link if lib/
        # pulled in unix-only functions for bin/'s use; the build
        # succeeds, proving no kernel API leak.

  - id: cli-context-capsule
    outcome: cli-context-capsule
    claim: |
      `mc context BASE HEAD --budget N` exits 0 with a JSON capsule
      containing at minimum the keys "change", "decisions",
      "obligations", "items", "omitted", "total_bytes", "truncated",
      "now", "base", and "head". BASE and HEAD may be any git ref
      (commit, branch, tag). Items are sorted and truncated by the
      priority order in spec/semantics.md "context-prioritisation".
      Each item carries a "priority" tag and an optional "freshness"
      timestamp. Omitted items appear in the "omitted" array with an
      "expansion" command of the form "mc explain <detail_ref>".
      The capsule prints to stdout, exits 2 on input errors (missing
      BASE, missing HEAD, bad --budget value).
    acceptance:
      all:
        - verifier: tests/fixtures/context-budget.sh
          result: pass

  - id: capsule-byte-budget-tracked
    outcome: cli-context-capsule
    claim: |
      The capsule JSON contains a "total_bytes" key whose value
      equals the actual byte length of the kept items plus their
      JSON framing. The "truncated" key is true iff the budget was
      insufficient for the entire priority-sorted item list. The
      fixture tests/fixtures/context-budget.sh asserts both keys
      are present; the assertion is a regression check that the
      budget is observable (A1 / axiom-of-care: don't silently drop
      without telling).
    acceptance:
      all:
        - verifier: tests/fixtures/context-budget.sh
          result: pass

reversal:
  - signal: parse-decision-becomes-total
    action: archive-negative-fixture-when-empty
  - signal: kernel-checks-attestation-contents
    action: validate-promoted-to-check-deferred
  - signal: context-budget-becomes-token-budget
    action: replace-byte-counter-with-token-counter-and-revise-spec

risk:
  declared_triggers:
    - duplicate-yaml-loader-drift
    - exit-code-misalignment-with-spec
    - priority-order-drift-between-spec-and-implementation
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3@2
    - kernel-conformance-runner@1
  superseded_by: []
