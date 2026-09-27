---
schema: math-coding/3.0-alpha
id: yaml-block-scalars
revision: 2

intent: |
  Close deficit D1 and D2 from doc/AUDIT-0.0.11.md by extending
  lib/codec.ml's hand-rolled YAML loader to recognise `|` and
  `>` block scalars with the standard chomping indicators
  (`|-`, `|+`, `>-`, `>+`) and the default clip behaviour. The
  subset covered is what hand-written YAML in this repository
  uses and what the existing bootstrap files require.

commitment: |
  lib/codec.ml's load_yaml_string recognises a value starting
  with `|` or `>` (optionally followed by `-` or `+`) as a block
  scalar header. Content lines are collected at the indent of
  the first non-empty content line, joined by '\n' for literal
  (`|`) and by ' ' for folded (`>`), and chomped according to
  the indicator. The change is backward-compatible: every
  fixture that the loader accepted at v0.0.12 still parses to
  the same Jsonl.value. bootstrap/*.yaml's commitment,
  intent.text, and reason fields now serialise through
  Decision.parse_decision as the multi-line strings they are,
  instead of coming back as `Jsonl.Null` (the previous
  failure mode of the CLI validate path).

scope:
  capabilities:
    - yaml-block-scalars-supported
  paths:
    - "lib/codec.ml"
    - "tests/yaml_block_scalars.ml"
    - "tests/dune"
    - "tests/fixtures/yaml-block-scalars.sh"
    - "OCAML_BEST_PRACTICES.md"
    - "doc/AUDIT-0.0.11.md"
    - "bootstrap/yaml-block-scalars.md"
  exclusions:
    - "bootstrap/decision.yaml"
    - "bootstrap/infrastructure-honesty.yaml"
    - "bootstrap/kernel-conformance-runner.yaml"
    - "bootstrap/validate-and-context.md"
    - "bootstrap/adapters.md"
    - "tests/conformance.ml"
    - "lib/memory.ml"

outcomes:
  - id: kernel-handles-block-scalars
    statement: |
      lib/codec.ml's load_yaml_string returns a Jsonl.String
      whose body matches the canonical reading of the YAML
      block scalar: literal keeps newlines, folded joins
      adjacent non-empty lines with spaces, clip leaves one
      trailing newline, strip leaves none, keep preserves the
      trailing newlines present in the source (or one if the
      source had none). Block scalars at any nesting level
      (top-level mapping, nested mapping, inside a sequence
      item) are supported.
  - id: bootstrap-yaml-parses-with-commitment
    statement: |
      `mc validate bootstrap/decision.yaml` exits 0 with an
      accept verdict, and the parsed decision's commitment
      field is the multi-line text from the source (`Build
      math-coding 3.0 from an executable specification...`
      is no longer empty after YAML parse).
  - id: backward-compatibility-preserved
    statement: |
      All conformance fixtures that the runner accepted at
      v0.0.12 (nine fixtures under fixtures/conformance/)
      still parse to the same Jsonl.value via the same path.
      Adding block-scalar support must not change the parser
      output for a single existing fixture. The new unit test
      for block scalars is additive; it does not modify any
      existing fixture.
  - id: kernel-stays-offline
    statement: |
      lib/codec.ml does not import Unix, call exit, or write
      to a channel after this change. The block-scalar parser
      is a pure transformation on the string and the token
      list. No new dependency enters the closure.

countercase: |
  Why not pull in a real YAML library (e.g., `yaml`/`ocaml-yaml`)?
  Because the kernel must remain offline and side-effect-free
  (OCAML_BEST_PRACTICES §1.3, §7.3). Adding a parser dependency
  would drag in transitive packages and break the
  reproducibility guarantee the kernel is built around. The
  hand-rolled subset loader is sufficient for the bootstrap
  files and stays tiny.

  Why not factor a shared YAML loader between lib/codec.ml and
  tests/conformance.ml? Because tests/conformance.ml is already
  an inlined, self-contained fixture walker; coupling its YAML
  loader to a kernel module would tangle test inputs with
  kernel inputs. The duplication is acceptable and the fix
  history (the yaml_strip bug in OCAML_BEST_PRACTICES §11.13)
  is small enough that both copies can be kept aligned by hand.
  This decision extends lib/codec.ml only; tests/conformance.ml
  keeps its narrower loader, which is sufficient for the
  conformance fixtures it walks (none of which use block
  scalars).

  Why not keep the workaround in lib/memory.ml that strips
  `---` front-matter and calls Codec.load_yaml_string? Because
  the workaround only fixes the missing-front-matter path for
  the capsule loader; it does not fix the YAML loader itself.
  Any other caller that points at a bootstrap/*.yaml file
  (including future adapters) would hit D1 again.

  Why is the explicit-indentation form (`|2`, `>4`) not
  supported? Because hand-written YAML in this repo never uses
  it. Adding the parser logic for it would be dead code. If a
  future YAML fixture needs explicit indentation indicators,
  the fix is to extend parse_block_scalar; trap log entry
  §11.22 (see OCAML_BEST_PRACTICES) records the simpler form
  this commit ships.

  Why are anchors/aliases (`&` / `*`), tags (`!!str`, `!!int`),
  multi-document YAML (`---` / `...`), flow style inside block
  scalars, and comments inside block scalars not supported?
  Because they are out of scope for v0.0.13, which exists to
  close D1/D2 against the bootstrap files. They can land in
  v0.0.14+ if a future decision records the obligation.

  Why preserve backward compatibility so strictly? Because the
  nine conformance cases are the only evidence corpus the
  3.0-alpha kernel has. If block-scalar support changes the
  Jsonl.value of an existing fixture, the conformance
  runner's verdicts become incomparable across the v0.0.12
  → v0.0.13 transition. A3 (axioms/self-application.md)
  forbids that without an explicit verdict-diff declaration.

assumptions:
  - id: bootstrap-files-use-only-pipe-clip
    state: assumed
    statement: |
      All block scalars in bootstrap/*.yaml and bootstrap/*.md
      are literal (`|`) with the default chomping (clip).
      None use `|` with `|-`/`|+`, none use `>` at all, and
      none use nested block scalars more than two levels
      deep. The folded `>` cases exercised by
      tests/yaml_block_scalars.ml are forward-looking
      regression tests, not coverage of current bootstrap
      files.
    owner: human:maintainer
    consequence_if_false: |
      A bootstrap file that introduces `|-`/`|+`/`>` would
      round-trip through the kernel unchanged because the
      chomping indicators ship together. If a bootstrap file
      started using blank lines inside a `|` block, those
      blanks would be eaten by the loader (yaml_tokens strips
      whitespace-only lines) and the surrounding paragraphs
      would collapse into a single line. This is acceptable
      for v0.0.13; the loader is documented as not preserving
      blank lines inside block scalars.
    review_on:
      - signal: bootstrap-file-uses-folded-or-chomp
      - signal: bootstrap-file-uses-blank-lines-in-block
  - id: parse-decision-returns-decision-t
    state: assumed
    statement: |
      Decision.parse_decision returns Some Domain.decision
      when all required fields (id, revision, intent.source,
      intent.text, commitment, risk.owner) are present in the
      Jsonl.value. After this commit, the commitment field of
      bootstrap/decision.yaml will be a non-empty multi-line
      string instead of Jsonl.Null (which was the previous
      failure mode of the CLI validate path).
    owner: human:maintainer
    consequence_if_false: |
      If Decision.parse_decision rejected bootstrap/decision.yaml
      for some other reason besides the missing commitment,
      the fixture in this commit would still fail post-fix.
      The fixture is designed to assert the specific failure
      mode closed by this decision (commitment empty after
      YAML parse) — not the general "decision parses"
      obligation, which is the responsibility of
      bootstrap/validate-and-context.md.
    review_on:
      - signal: decision-parser-takes-diagnostic-option
  - id: kernel-offline-pure-unchanged-holds
    state: assumed
    statement: |
      The block-scalar parser added in this commit lives in
      lib/codec.ml and depends only on standard library
      functions (String, Buffer, List, Char). It does not
      import Unix, Sys, Filename, or any module from bin/
      or lib/git/ or lib/junit/. The dune closure for
      mathcoding_core is unchanged.
    owner: human:maintainer
    consequence_if_false: |
      A Unix-only call in lib/ would break the kernel-offline
      invariant (OCAML_BEST_PRACTICES §1.3) and the obligation
      kernel-offline-pure-unchanged in
      bootstrap/validate-and-context.md. dune build --root .
      would still succeed because the closure includes unix;
      only the architectural separation would be lost.
    review_on:
      - signal: kernel-imports-unix

obligations:
  - id: yaml-block-scalars-supported
    outcome: kernel-handles-block-scalars
    claim: |
      lib/codec.ml's load_yaml_string parses YAML block
      scalars `|`, `|-`, `|+`, `>`, `>-`, `>+` to
      Jsonl.String values whose body matches the canonical
      YAML reading: literal preserves newlines; folded
      joins adjacent non-empty lines with spaces; clip keeps
      exactly one trailing newline; strip removes all
      trailing newlines; keep preserves all trailing newlines
      present in the source (or one if none). Block scalars
      at any nesting level (top-level mapping, nested
      mapping, inside a sequence item) are supported.
    acceptance:
      all:
        - verifier: tests/yaml_block_scalars.ml
          result: pass
        - verifier: tests/fixtures/yaml-block-scalars.sh
          result: pass
  - id: yaml-block-scalars-loader-extended
    outcome: kernel-handles-block-scalars
    claim: |
      lib/codec.ml's load_yaml_string recognises a value
      starting with `|`, `|-`, `|+`, `>`, `>-`, `>+` (after
      trim) as a block scalar header, collects subsequent
      tokens at the parent's first-content-indent or deeper
      as the block body, applies the joining and chomping
      rules declared by outcome: kernel-handles-block-scalars,
      and returns Jsonl.String. The extension is additive:
      every non-zero value's parse path is unchanged. Leading
      YAML front-matter (`---` as a token whose ycontent is
      exactly `---`) is dropped because bootstrap/decision.yaml
      begins with one and the alternative (a stripper at every
      call site) would push D1 into the next caller; this is
      the minimum change that lets `mc validate
      bootstrap/decision.yaml` exit 0.
    acceptance:
      all:
        - verifier: dune build --root . tests/yaml_block_scalars.exe
          result: pass
        - verifier: dune test --root . --force
          result: pass
        - verifier: tests/fixtures/yaml-block-scalars.sh
          result: pass
        - verifier: mc validate bootstrap/decision.yaml
          result: accept

reversal:
  - signal: kernel-self-check-passes
    action: archive-yaml-block-scalars-md-after-3.0-kernel-adopted
  - signal: fixture-uses-anchor-alias
    action: replace-hand-rolled-loader-with-real-yaml-library-when-allowed

risk:
  declared_triggers:
    - block-scalar-content-mis-folded
    - explicit-indent-indicator-ignored
    - blank-lines-in-block-eaten
  owner: human:maintainer

relations:
  addresses:
    - doc/AUDIT-0.0.11.md#D1
    - doc/AUDIT-0.0.11.md#D2
  superseded_by: []