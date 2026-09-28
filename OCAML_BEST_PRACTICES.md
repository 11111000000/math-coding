# math-coding 3.0-alpha — OCaml Best Practices (project-specific)

This is **not** generic OCaml advice. It is the convention we are standardizing
on for `lib/`, `bin/`, `tests/`, and the build, derived from the code we
already have. The rule is stated up front; the reason follows.

---

## 1. Project conventions

### 1.1 Module layout we already have

```
lib/
├── dune              (library mathcoding_core, wrapped false)
├── domain.ml         (Domain)         — pure type definitions only
├── canonical.ml      (Canonical)      — JSON canonicalization
├── jsonl.ml          (Jsonl)          — JSON value + parser + pretty-printer
├── schema.ml         (Schema)         — schema-aware field extractors
├── diagnostic.ml     (Diagnostic)     — Diagnostic.t record + renderers
├── identifier.ml     (Identifier)     — id / timestamp / digest parsers
├── digest.ml         (Digest)         — SHA-256 (hand-rolled; see §5)
├── scope.ml          (Scope)          — scope_target + covers
├── reference.ml      (Reference)      — Ref/Parent/Subject reference parser
└── decision.ml       (Decision)       — Domain constructors from Jsonl.value
```

**Rule.** Every kernel module lives under `lib/`. Every executable-only logic
lives under `bin/`. No exceptions, no transitive includes. The kernel must
remain reusable from adapters later (Git, JUnit, MCP — see §10) without them
dragging CLI baggage.

### 1.2 Library vs binary boundary, and `(wrapped false)`

`lib/dune:2` declares `(wrapped false)`. We chose this deliberately.

**Reason.** The library exposes eleven modules that callers compose flat. With
`(wrapped true)` every consumer would write `Mathcoding_core.Domain.foo` and
the shadowing of `Domain` (it almost collides with the OCaml `Domain` syntax
keyword in some contexts) would force ugly prefixes everywhere. Flat exposure
lets `bin/Mathc.ml` write `Domain.Pass` directly — which we need, because
`Domain` is both a module name and a type-name concept.

**Trade-off.** We lose namespace isolation. Future modules with generic names
(`Digest`, `Jsonl`) will collide if we ever import another `Digest` lib.

**Action.** When we add `lib/git.ml`, `lib/junit.ml`, `lib/mcp.ml`, prefix the
filename to avoid collisions: `lib/git_diff.ml`, `lib/junit_render.ml`,
`lib/mcp_server.ml`.

**Boundary rules.**

| | `lib/` | `bin/` |
|---|---|---|
| Depends on | `str` only (currently) | `mathcoding_core`, `str`, `unix` |
| Side effects | none | argv parsing, I/O, exit codes |
| Errors | `Result` or typed exception | catches and maps to exit code |
| Calls `exit` | forbidden | allowed at top level only |

### 1.3 Why we keep the kernel offline and side-effect-free

`spec/constitution.md:127` says: *"Determinism: equal canonical inputs and
equal evaluation time produce equal verdicts."* That is the contract.

**Rule.** No I/O in `lib/`. No `Unix.*`, no `Printf.printf` (use `Buffer` and
return `string`), no `Random.self_init`. The single existing exception is
`jsonl.ml:14` which raises `Parse_error` — typed, scoped to the parser, caught
at the bin boundary.

**Currently.** `domain.ml`, `canonical.ml`, `identifier.ml`, `digest.ml`,
`scope.ml`, `reference.ml`, `decision.ml`, `schema.ml`, `diagnostic.ml` are
pure functions over inputs. Verified by reading. Keep it that way.

### 1.4 File/module naming — what we should standardize on going forward

**Current state.** All-lowercase filenames (`domain.ml` → module `Domain`).
OCaml convention is `snake_case.ml` → `Snake_case`. We diverge deliberately
because the modules are short enough that the all-lowercase form is
unambiguous and reads better at call sites.

**The actual rule the existing code is following accidentally:** never use a
filename that shadows an OCaml reserved word or stdlib name. `Domain` was
chosen *because* it would otherwise collide — ironically — with the OCaml
`Domain` keyword (which only matters in object contexts, but still).

| We have | Reason it works | Lesson for new modules |
|---|---|---|
| `Domain.ml` | reserved-word territory; double-purpose | OK as-is |
| `Jsonl.ml` | not a stdlib name | OK |
| `Digest.ml` | not a stdlib name, but collides with `digestif` if we add it | rename to `Hash.ml` if we ever add `digestif` |
| `Canonical.ml` | OK | OK |
| `Diagnostic.ml` | OK | OK |

**Decision.** Keep all-lowercase filenames. But before creating any new
`lib/foo.ml`, check that `Foo` doesn't collide with stdlib (`String`, `List`,
`Buffer`, `Char`, `Int`, `Option`, `Result`, `Hashtbl`, `Set`, `Map`, `Printf`,
`Scanf`, `Format`, `Fun`, `Lazy`, `Seq`, `Uchar`, `Bytes`). If it does,
prefix: `Render_string.ml`, `Format_buf.ml`, etc.

---

## 2. Type design

### 2.1 Variants over records for sealed cases

**Rule.** If a field is "one of N named cases," use a variant, not a string.
Add a hand-written codec to JSON if needed.

We already do this correctly in most places:

| Field | Type | Location | Status |
|---|---|---|---|
| `Diagnostic.class_` | polymorphic variant `[ \`Input \| ... ]` | `domain.ml:179` | rename to `kind` (see §2.5) |
| `freshness` | concrete variant | `domain.ml:19-23` | ✅ |
| `gate` | concrete variant + payload | `domain.ml:172-175` | ✅ |
| `gap.kind` | concrete variant | `domain.ml:151-159` | ✅ |
| `Diagnostic.severity` | concrete variant | `diagnostic.ml:4` | ✅ |
| `result` | concrete variant | `domain.ml:37-41` | ✅ |
| `Reference.kind` | concrete variant | `reference.ml:3` | ✅ |

**Anti-pattern we should not regress to.** Stringly-typed enums at the record
boundary. We have one near-miss: `parse_acceptance` in `decision.ml:79-119`
takes a `Jsonl.value` and re-discriminates with nested `match` instead of
using a per-shape helper. Refactor target (see §3).

**Rule.** Every JSON → variant codec lives next to the variant definition,
not in the parser. Today `parse_result` is in `decision.ml:3-9`; it belongs
in `domain.ml` (or a new `lib/codec.ml`) next to `type result`. **Move all of
`parse_result`, `parse_kind`, `parse_phase`, `parse_assumption_state`,
`parse_action`, `parse_match` from `decision.ml` into `lib/codec.ml`.**

### 2.2 Polymorphic variants vs sum types

We currently use polymorphic variants for:

- `Domain.phase` = `[ \`PreMerge \| \`PreRelease \| \`PostRelease ]`
- `Domain.kind` (obligation kind) = `[ \`Invariant \| \`Acceptance \| \`Recovery \| \`Operational ]`
- `Domain.state` (assumption) = `[ \`Assumed \| \`Unknown ]`
- `Domain.action` (reversal) = `[ \`Revert \| \`Halt \| \`Review \| \`Rework ]`
- `Domain.match_` (scope match) = `[ \`Exact \| \`Tree ]`
- `Diagnostic.class_` = `[ \`Input \| \`Question \| ... ]`
- `Gap.state` = `[ \`Missing \| \`Stale \| ... ]`

**Problem.** Polymorphic variants are open. `[ \`Invariant ]` matches a
function typed `[> \`Invariant ]` — you can pass `\`Review` accidentally if
you forget the type annotation. They have no clean JSON schema either, so
every test that wants to assert "phase is pre-merge" must compare strings.

**Rule (going forward).** For closed sets declared in `spec/domain.md`, use
concrete variants. Reserve polymorphic variants only for cases where you
genuinely want extensibility (a future plugin's verifier kinds, perhaps).

```ocaml
(* lib/domain.ml — going forward *)
type phase = PreMerge | PreRelease | PostRelease
type obligation_kind = Invariant | Acceptance | Recovery | Operational
type assumption_state = Assumed | Unknown
type reversal_action = Revert | Halt | Review | Rework
type scope_match = Exact | Tree
```

**Migration cost.** Every consumer of these fields. We defer until v3.0-beta
when the field names stabilize (post-§2.5 rename).

### 2.3 Phantom types for IDs

**Current state.** `type id = string` (`domain.ml:3`). Every entity —
decision, obligation, attestation, waiver, change — uses the same `id` type.

**Why we use a single string today.** At the JSON boundary, all ids are
strings; the canonical form is 1-128 char lowercase alnum/dot/dash/underscore
(`schemas/common.json:9-12`). The validator in `identifier.ml:24-47` does not
currently enforce per-kind prefixes.

**Going forward.** Phantom types prevent the wrong id at the function level
without changing runtime representation:

```ocaml
module Id = struct
  type 'a t = string
  type decision = [`Decision] t
  type obligation = [`Obligation] t
  type attestation = [`Attestation] t
end

val link : Id.decision -> Id.obligation -> unit  (* won't compile otherwise *)
```

**Why we haven't done it yet.** The bootstrap parses JSON where ids are
strings; promoting to phantom types is mechanical but means changing
`domain.ml:64` (`obligation.decision : id`) into
`obligation.decision : [`Decision] t`. Defer until v3.0-beta when we have
stable field names.

**Rule.** Once we add the first non-trivial cross-reference check (the
`K(R, P, now)` DAG check from `spec/constitution.md:127`), introduce
phantom-typed ids in one pass. Not before — too much churn for marginal
benefit today.

### 2.4 Tagged arguments to enforce invariants

We already do this for `Diagnostic.create` (`diagnostic.ml:31-36`). Good.

**Rule.** For any record with > 4 fields where > 1 are option-typed and
> 1 are mutually constrained, require a `create` smart constructor.

Today: `Decision`, `Obligation`, `Diagnostic`, `Attestation`, `Waiver`,
`Change`, `Risk`, `Reversal`, `Acceptance` all have inline record literals.
**Action.** The next time someone writes `Some { Domain.id; Domain.kind; ... }`
they should ask whether a smart constructor is justified.

### 2.5 Records vs tuples

**Rule.** Tuples are for transient local values. A `(value, int)` cursor
position is fine — see `jsonl.ml:65`. Anything that crosses a function
boundary or is stored in a list should be a record.

**Currently violated.** `(string * string) list` for `gap.remedies`,
`reversal.signal`, etc. (`domain.ml:169`, `domain.ml:75-79`). These represent
`(kind, value)` pairs. Fix:

```ocaml
type remedy = { kind : [`Run | `Review | `Waive]; value : string }
type reversal = {
  signal : string;
  condition : string option;
  action : reversal_action;
}
```

### 2.6 Avoid `class` as a field name — rename to `kind`

We hit this. `diagnostic.ml:18-19` uses `class_`. The underscore is a wart.

**Decision.** Rename `Diagnostic.class_` to `Diagnostic.kind`. Cascade to:

- `Diagnostic.string_of_class` → `string_of_kind`
- `Diagnostic.class_of_string` → `kind_of_string`
- All call sites in `bin/Mathc.ml` once it has any.

**Why now.** The `_` suffix is ugly, propagates to every constructor
(`~class_:Input`), and JSON already uses `"class"` for this field
(`schemas/attestation.json:7` lists it, ironically, as `kind_` for
*attestation kind*). Two name collisions (`class_` vs `kind_`) is a code
smell. Rename before v3.0-beta.

The same applies to `scope.match_` (`domain.ml:44`) — `match` is a keyword.
We added `_`. Prefer renaming to `scope_match`:

```ocaml
PathTarget { path : string; scope_match : Exact | Tree }
```

---

## 3. Parsing

### 3.1 Hand-rolled JSON vs yojson

**We use** ~190 lines of handwritten parser in `lib/jsonl.ml`. It handles:
null, bool, int, string (with escapes), array, object, recursive composition.
It rejects trailing data (`jsonl.ml:166-171`).

**Trade-off.**

| | Hand-rolled | yojson |
|---|---|---|
| Lines | 190 | ~5000 (transitively) |
| Runtime deps | 0 | `yojson` |
| Correctness risk | we own it | battle-tested |
| Compliance with RFC 8259 | partial (we reject floats; see below) | full |
| Speed | ~2× faster (no allocations) | slower |
| Build reproducibility | trivially reproducible | depends on opam resolver |

**Our context.** "Pure deterministic kernel, no network, no shell" (from the
request). Deps are not free — every dependency is a surface for reproducibility
bugs. We pin OCaml 5.0+ in `math-coding.opam:11`. Adding `yojson` would also
pin `dune` more tightly and force CI to compile 5000 more lines we don't use.

**Decision.** Keep the handwritten parser. **But:**

1. Reject floats. We use `parse_number` (`jsonl.ml:132-164`) which only accepts
   ints via `int_of_string_opt`. Any JSON with a decimal point currently
   rejects. Either document "math-coding 3.0-alpha JSON does not use floats" in
   `spec/semantics.md` or add `parse_float`. **Recommendation: document, do
   not add.** The schema in `schemas/decision.json` has no floats anywhere.

2. Reject very long strings. `canonical.ml:5` pre-allocates with no upper bound.
   Add `if String.length s > 1_000_000 then parse_error "string too long" i`
   near `jsonl.ml:30` (before allocating `Buffer.create 16`).

3. Add RFC 8259 conformance test (see §6).

### 3.2 `parse_acceptance` refactor

`lib/decision.ml:79-119` is the worst spot in the kernel. It mixes:

- a triple-tuple match `| Some id, Some r, _ -> ...` (`decision.ml:103-106`);
- a hand-coded nested if-tree (`vid`/`result`/`review`);
- a `to_acceptance` polymorphic-variant wrapper that does no work;
- pattern fallthrough `| _, _, Some (a, b)` that ignores whether `vid`/`result`
  are present.

**Cleaner pattern.** Decode each shape to its own helper, return `option`,
combine at the end with `List.filter_map`. No polymorphic variants in the
helper output.

```ocaml
(* lib/decision.ml — refactor target *)

let[@warning "-32"] parse_verifier v : Domain.verifier option =
  match v with
  | Jsonl.Object ps ->
    let* id   = Schema.take_string ps "verifier" in
    let* rstr = Schema.take_string ps "result" in
    let* r    = parse_result rstr in
    Some { Domain.id; Domain.result = r }
  | _ -> None

let[@warning "-32"] parse_review v : Domain.review option =
  match v with
  | Jsonl.Object ps ->
    let* rps = Schema.take_object ps "review" in
    let* a   = Schema.take_string rps "authority" in
    let ind  = Schema.take_string rps "minimum_independence" in
    Some { Domain.review_authority = a; Domain.minimum_independence = ind }
  | _ -> None

let[@warning "-32"] parse_acceptance_item v =
  match parse_verifier v with
  | Some r -> Some (Domain.Verifier r)
  | None ->
    (match parse_review v with
     | Some r -> Some (Domain.Review r)
     | None -> None)

let parse_acceptance v =
  match v with
  | Jsonl.Object ps ->
    (match Schema.take_array ps "all" with
     | Some xs -> Domain.All (List.filter_map parse_acceptance_item xs)
     | None ->
       (match Schema.take_array ps "any" with
        | Some xs -> Domain.Any (List.filter_map parse_acceptance_item xs)
        | None -> Domain.All []))
  | _ -> Domain.All []
```

**Why not a parser combinator library (`angstrom`, `menhir`)?** They add a
dep and we don't need backtracking. The current parser is hand-written
recursive descent and that's correct for JSON. Keep that. The fix is
*structural*, not library-based.

### 3.3 Helper functions we keep forgetting

`lib/schema.ml:7-35` has `string_opt`, `array_opt`, `object_pairs`,
`take_string`, `take_array`, `take_object`, `take_diag`. **Use them
everywhere.**

`decision.ml` re-implements `List.assoc_opt` + pattern match ~20 times.
Replace:

```ocaml
(* instead of: *)
let id = match List.assoc_opt "id" ps with
  | Some (Jsonl.String s) -> Some s | _ -> None in

(* use: *)
let id = Schema.take_string ps "id" in
```

---

## 4. Error handling

### 4.1 Result vs exception — clear boundary

**Kernel (`lib/`).** Uses `Result` where applicable. **Currently:**
`jsonl.ml:14` raises `Parse_error` because recursive descent is cleaner with
exceptions. That's fine; just convert at the boundary in `bin/Mathc.ml`:

```ocaml
(* bin/Mathc.ml — sketch *)
let parse_or_exit path =
  try Jsonl.parse (In_channel.with_open_bin path In_channel.input_all)
  with Jsonl.Parse_error (msg, pos) ->
    Diagnostic.create ~code:"MC-PARSE" ~class_:Input
      ~path:[path] (Printf.sprintf "%s at byte %d" msg pos)
    |> Diagnostic.render |> print_endline;
    exit 64
```

**Rule.** `lib/` functions never call `exit`, `print_endline`, or write to
a channel. They return `('a, Diagnostic.t) result` or raise a typed exception
that `bin/` catches.

**CLI (`bin/`).** Uses exceptions (`try`/`with`) freely. Maps them to exit
codes (§4.3).

### 4.2 `Diagnostic.t` record vs exception

`diagnostic.ml:17-29` is a record. **Don't make it an exception.** Reasons:

1. The kernel collects diagnostics. A gate may produce 12 gaps → 12
   diagnostics. Exceptions short-circuit at the first one.
2. The JSON output spec (`spec/semantics.md:150-160`) requires the kernel to
   emit "rule identifier; subject; verdict; reason; references; remedies;
   retryability; autofix safety; next actions" — all of which are fields of
   `Diagnostic.t`. An exception would lose this structure.
3. We need to map diagnostics to `Gate.blocked_of_gaps` (`domain.ml:175`)
   without unwinding.

**Use exception only for the parser** — `Jsonl.Parse_error (msg, int)` —
because the recursive parser is naturally continuation-passing and exceptions
are the cheapest way to bubble a position. Document this.

### 4.3 Stable exit codes

| Code | Meaning | Source |
|---|---|---|
| 0 | All gates pass (or `open-with-waiver` at merge when policy permits) | `mathc check` on a clean tree |
| 1 | Block: one or more gates blocked by unwaived gaps | `mathc check` with missing attestation |
| 2 | Bad input: parse error, schema mismatch, missing file | `Jsonl.Parse_error` |
| 3 | Internal/infrastructure: bug, unhandled invariant | uncaught exception |

`spec/constitution.md:148` — "Exit honesty: a blocking verdict MUST produce
nonzero exit code" — we honor it via 1 for policy blocks and 2 for input
errors.

**Rule.** Thread exit codes through a single `bin/Mathc.ml` entry point. Don't
call `exit 1` from inside a helper — return `'a * int` and let the top level
decide.

---

## 5. Digest / crypto

### 5.1 Hand-rolled SHA-256

`lib/digest.ml:1-107` is 107 lines of SHA-256 per RFC 6234. Constant table at
lines 3-11, padding at 21-40, compression at 63-104.

**Trade-off.**

| | Hand-rolled | `digestif` |
|---|---|---|
| Deps | 0 | `digestif` + `eqaf`/`bigstring-compat` |
| Lines | 107 | ~500 transitively |
| Compliance | RFC 6234 (claimed) | FIPS 180-4 validated |
| Side channels | we don't claim any | timing-safe variants available |
| Test coverage | **zero vectors** | extensive |

**Recommendation.** Keep the hand-rolled implementation **but** ship a
`tests/digest_vectors.ml` that checks against RFC 6234 §4.1 ("`abc`" →
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`), §4.2
(56-byte test), §4.3 (112-byte test), and §4.4 (1,000,000-byte "a" test).

**Until those pass, do not use `Digest.sha256_hex` for canonicalization.**
Sign externally with `sha256sum` instead. The hand-rolled code looks correct
but is **untested against vectors** and that is the single biggest residual
risk in the kernel.

---

## 6. Conformance testing

### 6.1 Layout

We have `fixtures/conformance/{decision,attestation,waiver}/` with
`positive-*.json` and `negative-*.json` files. There is **no `tests/` runner**
yet. **Add it now.**

**Recommended structure:**

```
tests/
├── dune
├── digest_vectors.ml       (* RFC 6234 vectors *)
├── identifier_parsers.ml   (* id / timestamp / digest valid + invalid *)
├── jsonl_roundtrip.ml      (* parse + stringify + re-parse == identity *)
├── decision_fixtures.ml    (* walks fixtures/conformance/decision/ *)
├── attestation_fixtures.ml (* walks fixtures/conformance/attestation/ *)
└── waiver_fixtures.ml      (* walks fixtures/conformance/waiver/ *)
```

`tests/dune`:

```ocaml
(test
 (name digest_vectors)
 (libraries mathcoding_core alcotest))

(test
 (name decision_fixtures)
 (libraries mathcoding_core alcotest))
```

### 6.2 Concrete example: walking decision fixtures

```ocaml
(* tests/decision_fixtures.ml *)

let fixture_dir = "fixtures/conformance/decision"

let collect kind =
  let files = Sys.readdir fixture_dir in
  Array.fold_left
    (fun acc f ->
      if Filename.check_suffix f ".json"
         && Astring.String.is_prefix ~affix:kind f
      then (Filename.concat fixture_dir f) :: acc
      else acc)
    [] files

let parse_file path =
  match In_channel.with_open_bin path In_channel.input_all
        |> Jsonl.parse with
  | v -> Ok v
  | exception Jsonl.Parse_error (m, p) ->
    Error (Printf.sprintf "%s at %d" m p)

let case_path kind path =
  let label = Filename.basename path in
  let expected = if kind = "positive-" then `Accept else `Reject in
  Alcotest.test_case label `Quick @@ fun () ->
    let r = parse_file path in
    match expected with
    | `Accept ->
      Alcotest.(check (result ok))
        "parses" (Ok ()) (Result.map (fun _ -> ()) r)
    | `Reject ->
      Alcotest.(check (result Error))
        "rejected" (Ok ()) (Result.map (fun _ -> ()) r)

let () =
  let positives = collect "positive-" in
  let negatives = collect "negative-" in
  let cases = List.map (case_path "positive-") positives
            @ List.map (case_path "negative-") negatives in
  Alcotest.run "decision conformance"
    [ "fixtures", cases ]
```

The same shape for attestation and waiver.

### 6.3 Negative-fixture example: waiver

`fixtures/conformance/waiver/negative-missing-expiry.json` has no `expires_at`
field; the kernel must reject it. Test:

```ocaml
let parse_file = ... (* as above *)

let case_negative_missing_expiry () =
  Alcotest.check Alcotest.(result Error)
    "waiver without expires_at is rejected"
    (Ok ()) (Result.map (fun _ -> ()) (parse_file
       "fixtures/conformance/waiver/negative-missing-expiry.json"))
```

### 6.4 Why `Alcotest`

The de facto OCaml test framework. No async, no js, no lwt dependency.
Outputs TAP for CI. Minimal dep tree (~3 packages). Add to
`math-coding.opam` as dev-only:

```ocaml
(dev)
(depends
 (alcotest (>= 1.7)))
```

`dune-project` does not change — opam pins the dep.

---

## 7. Build, deps, CI

### 7.1 Current state

`dune-project` has `(lang dune 3.16)` and nothing else.
`math-coding.opam:11` depends only on `ocaml (>= 5.0)` and `dune (>= 3.16)`.
`lib/dune:7` lists `str` as a dep.

`flake.nix:14` selects `dune_3`. `flake.nix:40` runs
`dune build --root . bin/mathc.exe`.

### 7.2 Should we add Alcotest? **Yes.**

It's dev-only, doesn't ship with the binary, and we need conformance testing
before 3.0-beta.

### 7.3 Should we add Yojson? **No.**

- Adds ~5000 lines of runtime code.
- The kernel never imports it.
- Our hand-rolled parser is sufficient for the subset of JSON the kernel needs
  (no floats, no comments, RFC 8259 subset).
- Repro-build risk.

If a future adapter needs broad JSON (e.g., JUnit import), add Yojson in that
adapter only (`lib/junit_import.ml`'s `dune`). Kernel stays zero-dep.

### 7.4 nix develop vs opam vs dune

Standardize on:

- **opam for developer workflow** (fast iteration, predictable for OCaml devs).
- **nix for CI reproducibility** (`nix develop .#default` and `nix build`).
- **dune for build** (`dune build`, `dune test`, `dune exec bin/mathc.exe`).

### 7.5 `flake.nix` needs update

`flake.nix:40` currently builds only `bin/mathc.exe`. Update it to also
build the test alias so CI exercises conformance:

```nix
buildPhase = ''
  runHook preBuild
  dune build --root . bin/mathc.exe
  dune build --root . @tests/runtest
  runHook postBuild
'';
```

`installPhase` stays the same — tests don't ship.

---

## 8. Style specifics

### 8.1 `[@warning "-32"]` / `"-26"` / `"-8"` usage

`"-32"` ("unused declaration"): used at `schema.ml:3`, `decision.ml:3,11,20,27,33,41,47,79,121,133`, `digest.ml:30,42,54,69,81`. All are intentional suppressions: the function is used (called from another module) or it's a helper used in a `let rec ... and ...` mutual recursion where one branch appears unused.

**Rule.** `-32` is fine when the silence is real. **Add a one-line comment** when not obvious:

```ocaml
let[@warning "-32"] rec words_of s =
  (* Used as `and words_to_ints` below; appears unused at this scope. *)
  ...
```

`"-26"` ("unused variable"): `jsonl.ml:16` (`skip_ws s i` uses `i` only to
enter recursion). Same rule.

`"-8"` ("partial match"): we **don't** use this. Good — we always match
exhaustively on variants (e.g., `Diagnostic.string_of_class` at
`diagnostic.ml:66-72` lists all 6 cases).

**Rule.** The moment we add `let[@warning "-8"]` to silence a partial match,
the kernel stops being total. Forbid it. Add a missing case instead.

### 8.2 `let rec` vs `and`

`jsonl.ml:65-160` uses `let rec parse_value ... and parse_array ... and
parse_object ... and parse_number ...`. Correct — these are mutually
recursive.

**Rule.** Use `and` only when recursion is genuinely mutual. Don't write:

```ocaml
let rec foo x = bar x
and bar x = foo x   (* usually indicates a typo *)
```

### 8.3 `open Stdlib` vs `open Domain` vs no open

We currently `open Stdlib` at the top of `canonical.ml`, `jsonl.ml`,
`schema.ml`, `diagnostic.ml`, `identifier.ml`, `reference.ml`. We **don't**
`open Domain` anywhere.

**Rule.**

- `open Stdlib` is **optional**. OCaml 5 stdlib modules don't need an open if
  you qualify: `Stdlib.String.length`, `Stdlib.List.map`. But unqualified
  `String.length` reads better. Acceptable.
- **Never** `open Domain`. Domain types collide with the module name. Write
  `Domain.Pass`, `Domain.Decision`.
- **Never** `open Mathcoding_core` from inside `lib/`. It's circular.

### 8.4 Avoiding `class` field name

Already discussed in §2.5. The `_` suffix is ugly and the underscore shadows
in pattern matches (`{ class_ = Input; _ }`). Rename to `kind`.

### 8.5 CamelCase record fields vs snake_case modules

OCaml convention: **modules PascalCase, fields snake_case**. We do this
consistently: `Domain.outcome`, `Domain.relations`, `Diagnostic.code`. Good.

**Exceptions.**

- `scope.match_` (`domain.ml:44`) — `match` is a keyword. We added `_`.
  Consider `scope_match` field name instead (see §2.5).
- `diagnostic.class_` — already discussed.
- `Jsonl.Object` — `Object` does not collide with `Stdlib.Object` (no such
  type). Fine.

**Rule.** If a field would shadow an OCaml reserved word, prefer renaming the
field to a non-colliding name over suffixing with `_`.

---

## 9. What we already did wrong

A frank list. None of these is a bug; they're style/structure corrections to
make once and document.

### 9.1 `parse_acceptance` triple-tuple match

`lib/decision.ml:103-106` (pre-refactor):

```ocaml
match vid, result, review with
| Some id, Some r, _ -> Some (to_acceptance (`Verifier (id, r)))
| _ , _, Some (a, b) -> Some (to_acceptance (`Review (a, b)))
| _ -> None
```

**Problem.** If both `vid`/`result` and `review` are present, we pick
`Verifier` and silently drop `review`. If only `review` is present, we use
it. The wildcard `_ , _, Some (a, b)` says "ignore vid/result" — correct —
but the first arm doesn't check `review = None`, so if both fields are
present, `review` is lost without a diagnostic.

**Fix.** Split into `parse_verifier` + `parse_review` + `parse_acceptance_item`
helpers (§3.2). Each helper returns `option`; a combined `parse_acceptance_item`
returns `Some _` only when exactly one shape is present. If both are present,
return `None` and the caller emits `Diagnostic.code = "MC-AMBIGUOUS-ACCEPTANCE"`.

**Status (2026-09-27, T4): DONE.** The current `lib/decision.ml` has
`parse_verifier`, `parse_review`, `parse_acceptance_item` (§3.2),
plus a new `classify_acceptance_item : Jsonl.value -> acceptance_shape`
that distinguishes `ShapeAmbiguous`, `ShapeMalformed`, `ShapeVerifier`,
`ShapeReview`, `ShapeEmpty`. The kernel still prefers Verifier on
ambiguity (verifier half parses, review is dropped) but `mc validate`
surfaces `MC-AMBIGUOUS-ACCEPTANCE` to stderr per obligation id and
position so the author can disambiguate. The CLI JSON output also
includes a `diagnostics` array. `MC-MALFORMED-ACCEPTANCE` is the
sister diagnostic for items whose fields are right but values are
unparseable (e.g., `result: "bogus"`). Positive fixtures:
`fixtures/conformance/decision/positive-ambiguous-acceptance.json`,
`fixtures/conformance/decision/positive-malformed-acceptance.json`;
shell fixtures: `tests/fixtures/ambiguous-acceptance.sh`,
`tests/fixtures/malformed-acceptance.sh`. The conformance runner
still classifies these as `Accept` because the decision parses;
the diagnostics are the side-channel.

### 9.2 `domain.ml` used `class` as a record field name

Originally `class : [...]`. Compiler accepted it because OCaml 5 reserves
`class` only in `class ... = object ... end`. Field labels *can* shadow, but
the field-name-as-keyword ambiguity makes every pattern match ugly:
`{ class = Input }` works in records but not in some pattern positions.

We renamed to `class_`. **Now rename to `kind`** (§2.5).

### 9.3 `jsonl.ml` fragile indentation

`lib/jsonl.ml:90-105` and `:107-130` have nested `if`/`else`/`begin`/`end`
blocks at +1/+2 indent. We added `begin ... end` markers at `:93` and `:115`
to make `else` branches unambiguous.

**The rule, going forward:**

> Use `begin ... end` whenever an `else` branch contains more than one
> statement. Use a layout with explicit parentheses around `if` conditions
> matching the body indent.

A `match` with two short arms should be one-line:

```ocaml
match foo with
| A -> 1
| B -> 2
```

A match with longer bodies uses the `(* begin *)`/`end` brackets. We've done
this; document it.

### 9.4 `bin/dune` executable rename churn

History (per git): `main.ml` → `mathc.ml` → `Mathc.ml`. Each time the module
name changed, the binary exe name followed.

**Settle on `Mathc.ml` (PascalCase) and never rename.** Update `bin/dune:2` if
needed. Delete the stale `bin/mathc_main.ml` (currently identical to
`bin/Mathc.ml`).

### 9.5 SHA-256 untested against vectors

Already discussed (§5). Single biggest residual risk in the kernel. Ship
`tests/digest_vectors.ml` before any digest participates in canonicalization.

---

## 10. Forward-looking

### 10.1 Adapter convention

When we add `lib/git.ml` (Git adapter), `lib/junit.ml` (JUnit import),
`lib/mcp.ml` (MCP server), split into subdirectories:

```
lib/
├── kernel/                (* flat layout stays until v3.0-beta *)
│   ├── domain.ml
│   ├── canonical.ml
│   └── ...
├── git/
│   ├── dune              (library mathcoding_git, depends on mathcoding_core)
│   ├── diff.ml
│   └── refs.ml
├── junit/
│   ├── dune              (library mathcoding_junit, depends on yojson)
│   └── import.ml
└── mcp/
    ├── dune              (library mathcoding_mcp, depends on cohttp-lwt)
    └── server.ml
```

**Rules.**

1. Adapter `dune` files list **only** their own deps. Kernel `lib/dune` is
   unchanged.
2. Adapters may use `Unix`, `Printf`, `Str`, networking libraries. Kernel
   cannot.
3. Adapter modules that produce `Diagnostic.t` for downstream rendering live
   alongside the adapter (`Git.missing_commit` returns `Diagnostic.t option`).
4. Adapters have their own `tests/` runner per directory.
5. Adapters may depend on `yojson` (or anything else). Kernel may not.

**Migration.** We don't move existing modules today — they stay flat. The
flat layout is fine for 11 modules. When we add the 12th-and-onward, split.

### 10.2 JSON output: own stringify, no Yojson in kernel

`jsonl.ml:173-190` already implements `stringify` using
`Canonical.canonicalize_string` (`canonical.ml:3-26`) and recursive
structure. Object keys are sorted lexicographically before concatenation.

**Rule.** Kernel output goes through `Jsonl.stringify` (with sorted keys) for
canonicalization. Adapters that emit *non-canonical* JSON (e.g., `Mathc
render` → human-readable) may use whatever, but **must** call
`Jsonl.stringify` for any data that's part of a digest computation.

**Concrete rule for the JUnit adapter:** it produces *reports*, not *digests*.
Use any JSON lib. The kernel producing the gate verdict that flows into the
JUnit report goes through `Jsonl.stringify` first.

### 10.3 What we don't need yet

- `lwt`/`eio`: kernel is synchronous. Only adapters with network use them.
- `ppx_*`: not yet. If we add `ppx_sexp_conv` for `Diagnostic.t` debugging
  output, that's an isolated dev-time add.
- `odoc`: defer until v3.0 release. The spec documents the API; `odoc`
  generates from `mli` files we haven't written. Add `mli` files as part of
  stabilizing each module, before adding `odoc`.

### 10.4 What we should write next — prioritized

1. `tests/digest_vectors.ml` — gates SHA-256 against RFC vectors. Without
   this, do not use `Digest.sha256` for canonicalization.
2. `tests/decision_fixtures.ml` — walks `fixtures/conformance/decision/`.
   Confirms kernel parses positives, rejects negatives.
3. Rename `Diagnostic.class_` → `Diagnostic.kind`. Cascade.
4. Refactor `parse_acceptance` into `parse_verifier` + `parse_review` +
   `parse_acceptance_item` + `parse_acceptance`. Delete `to_acceptance`.
5. Add `lib/codec.ml` with `parse_result`, `parse_kind`, `parse_phase`,
   `parse_assumption_state`, `parse_action`, `parse_match`. Remove them
   from `decision.ml`.
6. Fix `flake.nix:40` to also build `@tests/runtest`.
7. Delete `bin/mathc_main.ml`. Confirm `bin/dune` says `(name mathc)` with
   `(modules Mathc)`.
8. Introduce phantom-typed IDs in `lib/identifier.ml` (§2.3). Defer until
   v3.0-beta.
9. Move polymorphic variants to concrete variants in `domain.ml` (§2.2).
   Defer until 3.0-beta — touches every consumer.
10. Move the 11 modules under `lib/kernel/` (§10.1) when the first adapter
    lands.

### 10.5 Context-capsule priority order (for `mc context`)

`mc context BASE HEAD --budget N` builds a JSON capsule whose items
are sorted and truncated by priority. The order is normative; an
agent MUST NOT silently reorder or rebucket it. See
`spec/semantics.md` "context-prioritisation" for the authoritative
table.

```text
RequiredForGate > Changed > HighRisk > Unresolved > Supporting > Historical
```

| Priority | Source class |
|---|---|
| `RequiredForGate` | bootstrap/decision.yaml, the currently active policy. The capsule ALWAYS includes this even if budget is exhausted (skippable in practice — see spec/semantics.md) |
| `Changed` | `git diff BASE..HEAD --name-only` paths; commit log BASE..HEAD |
| `HighRisk` | Decisions whose `risk.declared_triggers` is non-empty |
| `Unresolved` | Assumptions with `state: unknown` (kernel-decision aware) |
| `Supporting` | spec/*, OCAML_BEST_PRACTICES.md |
| `Historical` | axioms/* (rarely changed) |

When the budget is exhausted, items are dropped in reverse priority
order. The dropped items appear in the JSON `omitted` array with an
`expansion` command (e.g., `"mc explain decision:Foo"`) so an LLM
agent can fetch the missing context on demand. The total bytes used
are reported as `total_bytes`.
---

## 11. OCaml 5 trap log

Real errors encountered in this repo, with minimal reproducers and fixes.
**Before debugging an OCaml syntax/type error, read this section.**
If you trip a new trap, append it here with the exact error message.

### 11.1 Inline record shorthand forbids qualified labels

```ocaml
(* FAILS *)
Some (Domain.Verifier { Domain.id; Domain.result })

(* Error: The field Domain.id belongs to the record type
   Domain.attestation but a field was expected belonging to the record
   type Domain.acceptance.Verifier *)

(* WORKS *)
Some (Domain.Verifier { id; result })
(* Or explicitly: *)
Some (Domain.Verifier { Domain.id = id; Domain.result = r })
```

OCaml 5 does not allow `Module.field` qualification on inline record
labels when the type of the record constructor must be inferred from
context. Use unqualified labels or write `field = value` pairs.

**Trigger**: record constructor `Foo { Module.x; Module.y }` for a
constructor `Foo` whose argument type contains fields named `x` and `y`.

### 11.2 Reserved keyword in record field name

```ocaml
(* FAILS — "class" is a keyword in object contexts *)
type t = { code : string; class : [...] }

(* WORKS *)
type t = { code : string; class_ : [...] }
(* Or rename entirely — class_ is a wart *)
```

The original `class` field in `lib/diagnostic.ml:18` was renamed to
`kind`. Don't reintroduce `class` even with `_` suffix; rename.

**Trigger**: any record field name that is an OCaml reserved word:
`class`, `match`, `object`, `type`, `val`, `inherit`, `initializer`,
`method`, `private`, `virtual`, `when`.

### 11.3 Mutually recursive `let` must be one group

```ocaml
(* FAILS — parse_decision and parse_obligation cannot see each other *)
let parse_decision v = ...
let parse_obligation v = ... uses parse_decision ...

(* WORKS *)
let rec parse_decision v = ...
and parse_obligation v = ... uses parse_decision ...
```

When two functions call each other, they MUST be declared as a single
`let rec ... and ...` group. Putting `let` before `and` is not the
same group.

**Trigger**: `Error: Unbound value X` where `X` is defined right above.

### 11.4 `let ... and ...` requires the first definition to be `let rec`

```ocaml
(* FAILS — and must follow let rec, not let *)
let parse_yaml mapping = ...
and parse_scalar s = ... uses parse_yaml ...

(* WORKS *)
let rec parse_yaml mapping = ...
and parse_scalar s = ...
```

The first `let` in a mutually recursive group must be `let rec`. The
rest follow with `and`. Without `rec`, OCaml treats `and` as a
definition that cannot call back into the group.

### 11.5 `rec` keyword on a non-recursive function is a warning

```ocaml
let[@warning "-32"] parse_acceptance v = ...
(* Error (warning 39 [unused-rec-flag]): unused rec flag. *)

(* WORKS *)
let parse_acceptance v = ...
```

Only use `[@warning "-32"] rec` when the function genuinely calls itself.
The compiler warns even when warnings are suppressed with `[@warning "-32"]`.

### 11.6 Dune does not re-read `modules` lists incrementally

Adding a new file `lib/foo.ml` to `lib/`:

```lisp
(modules ... foo)        ; ← newly added
```

…does NOT cause `dune build` to compile `foo.ml`. The change is
detected, but the existing `_build/default/lib.cmxs` is kept.
You must run `dune build --force` or `dune clean && dune build`.

**Fix**: `./scripts/dev rebuild` — never `rm -rf _build` directly.
See `scripts/dev`, which exists specifically to avoid this superstition.

**Trigger**: new file in `lib/` not picked up; or `Unbound module Foo`
when `Foo` should exist.

### 11.7 Adding a new OCaml package to `flake.nix` requires a clean rebuild

When you add `ocamlPackages.foo` to `flake.nix:devShells.test.packages`,
the new `foo` package is not yet on the closure. `nix develop .#test`
will either:
- rebuild the dev-shell (slow first time), or
- fail to find `foo` in `OCAMLPATH` if the shell was cached.

After `nix develop .#test`, run `./scripts/dev rebuild` so dune
re-evaluates the closure.

### 11.8 `Sys.getcwd()` inside a test runs from `_build/default/tests/...`

When `dune test` runs an executable, the working directory is the
stanza output directory, not the source root. Relative paths like
`"fixtures/conformance"` resolve against the wrong root.

**Fix**: anchor on a known file at the repo root:

```ocaml
let fixture_root =
  let cwd = Sys.getcwd () in
  let rec find_dune_project d =
    let candidate = Filename.concat d "dune-project" in
    if Sys.file_exists candidate then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd  (* fallback *)
      else find_dune_project parent
  in
  Filename.concat (find_dune_project cwd)
    "fixtures" |> Filename.concat "conformance"
```

### 11.9 `nix develop --command bash -c '...'` parses one shell string

```sh
# WRONG — embedded ' inside single-quoted string breaks the shell
nix develop .#test --command "bash -c 'echo 'literal''"
# Bash sees: bash -c 'echo literal' — single-quote eats literal''

# WORKING PATTERN (what scripts/dev uses)
nix develop .#test --command bash -c "cmd && other"
```

`--command` takes a SHELL COMMAND as one argument. The shell then parses
it. Don't wrap the shell's `-c` argument in single quotes from inside.

### 11.10 `Array.filter` does not exist in OCaml stdlib

```ocaml
(* FAILS — Unbound value Array.filter *)
Array.filter (fun n -> ...) dir

(* WORKS *)
List.filter (fun n -> ...) (Array.to_list dir)
```

OCaml stdlib has `Array.exists`, `Array.iter`, `Array.map`, etc., but
not `Array.filter`. Convert to list first.

### 11.11 `Sys.is_directory` returns `bool`, not `bool option`

```ocaml
(* FAILS — pattern match against a bool *)
match Sys.is_directory path with
| Some true -> ...
| _ -> ...

(* WORKS *)
match Sys.is_directory path with
| true -> ...
| false -> ...
```

`Sys.is_directory` returns plain `bool` (true = is a directory).
Only some `Sys` functions return `option` (e.g., `Sys.getenv_opt`,
`Sys.argv`-related).

### 11.13 A whitespace-stripping helper destroys source structure

The original `yaml_strip` in `tests/conformance.ml` (pre-fix) looked
innocuous — strip `#` comments, then drop `' ' | '\t' | '\r'`:

```ocaml
| ' ' | '\t' | '\r' -> loop (i + 1)
```

But this dropped **every** space/tab/CR, including the leading
indentation that gives YAML its structure. The result:

```yaml
intent:
  source: issue:143
  text: ...
```

…became `intent:\nsource:issue:143\ntext:...` after stripping — every
line collapsed to indent 0, and the nested object became three sibling
top-level keys with names like `source`, `text`. `parse_yaml` happily
returned a flat object and the parser couldn't recover the hierarchy.
The kernel then rejected the fixture because `intent.source` was
missing.

**Symptom**: every nested YAML fixture parses but with a totally wrong
shape — keys with embedded `-` appear (`-rev:102abc`), and nested
mappings collapse into siblings. The fix looks like it should be in
the loader, but the bug is upstream in the preprocessor.

**Fix**: only strip `#`-to-EOL comments and `\r`. Preserve all spaces
and tabs so the tokenizer can compute indentation.

```ocaml
(* only strip comments and CR *)
| '#' -> skip_to_eol i
| '\r' -> loop (i + 1)
| _ -> Buffer.add_char buf c; loop (i + 1)
```

**Trigger**: any hand-rolled YAML/indentation-sensitive loader that
delegates preprocessing to a "strip whitespace" helper.

### 11.14 `dune test` emits no output when nothing changed

When every test in a stanza passes, `dune test` caches the result and
emits *no* Alcotest output on subsequent runs (no `Testing` line, no
per-case `[OK]` lines). Shell fixtures that grep the output for a
suite name then fail — but only on the *second* run, after the cache
warms.

**Symptom**: a fixture passes once (when something triggers a rebuild
that re-runs the tests) and fails on the next `check.sh` invocation.
Flaky green/red between calls.

**Fix**: pass `--force` to `dune test` from shell fixtures that grep
its output. `--force` rebuilds the test executables and re-runs them,
guaranteeing output regardless of cache state.

```sh
nix develop .#test --command bash -c 'dune test --root . --force'
```

`dune test` has no `--error-on-warnings` flag (only `dune build` does
in older versions); do not assume test-time strict-warnings is
available.

**Trigger**: a shell fixture `grep`s for a string in the output of
`dune test`, and the fixture's input tree has been stable long enough
for dune's build cache to short-circuit the run.

### 11.12 Warnings classified as errors during compilation

`dune build` returns nonzero exit code on warnings when:
- `tests/dune` declares a `(test ...)` stanza and the test source has warnings
- An executable's source has unused fields that flow into record literals

`warning 8 [partial-match]`, `warning 32 [unused-value-declaration]`,
and `warning 39 [unused-rec-flag]` are the most common ones. Fix the
warning; don't suppress with `[@warning "-32"]` unless intentional.
Use `./scripts/dev lint` to fail fast on warnings.

### 11.15 `parse_array` drops the last element when followed by `]`

The hand-rolled JSON parser at `lib/jsonl.ml:99` (pre-fix) returned
`Array (List.rev acc)` from the `]` branch without appending the just-
parsed element `v`:

```ocaml
and parse_array s i : value * int =
  ...
  let rec loop acc i =
    let v, j = parse_value s i in
    let i = skip_ws s j in
    ...
    if i < len && s.[i] = ',' then
      loop (acc @ [v]) (skip_ws s (i + 1))
    else if i < len && s.[i] = ']' then
      Array (List.rev acc), i + 1     (* missing v *)
    ...
  in loop [] i
```

For a single-element array, `v` is parsed and `acc` is `[]`; the `]`
branch returns `Array []` — element lost. For a multi-element array
like `[1,2,3]`, the `,` branch appends the previous element to `acc`,
but the final `]` branch returns `List.rev acc` minus the latest `v`.
`[1,2,3]` decoded as `[2;1]`; `[{...}, {...}]` lost the last object.

The conformance corpus did not detect this because every fixture's
arrays happen to be single-element under the keys the runner
inspects (`obligations`, `assumptions`, `outcomes`, `reversal`,
`parents`, etc.). Single-element arrays go through the
return-missing-v branch and become `[]`; the runner's accept/reject
verdict on a `Some _` result still holds because the top-level
required fields (id, revision, intent, commitment) are parsed
correctly.

**Symptom**: any code path that inspects `d.obligations` (or any list
field built through `List.filter_map` over an array) sees `[]` even
when the JSON source has elements. `mc validate FILE` showed
`obligations: 0, assumptions: 0` for `positive-minimal.json` which
genuinely contains one of each.

**Fix** (lib/jsonl.ml:99): prepend `v` to `acc` once, before the
dispatch on `,`/`]`:

```ocaml
let v, j = parse_value s i in
let i = skip_ws s j in
let len = String.length s in
let acc = v :: acc in
if i < len && s.[i] = ',' then
  loop acc (skip_ws s (i + 1))
else if i < len && s.[i] = ']' then
  Array (List.rev acc), i + 1
else parse_error "expected ',' or ']'" i
```

The `@ [v]` per-iteration pattern is replaced by single cons; the
final `List.rev acc` already yields the correct order. `[]` keeps
working through the early `]` shortcut at line 92.

**Trigger**: any fixture with non-empty array fields the kernel
parses into a list — and the conformance runner doesn't transitively
inspect list contents, only `Some _` / `None` on top-level decisions.

### 11.16 `in_channel_length` on a subprocess pipe returns 0

When you spawn a subprocess with `Unix.open_process_args_in` and try
to read its stdout with `really_input_string ic (in_channel_length ic)`,
you get an empty string. Pipes are not seekable; `in_channel_length`
returns 0 because no bytes have been buffered yet (the subprocess
may not even have started writing).

```ocaml
(* FAILS — output looks empty *)
let raw =
  let ic = Unix.open_process_args_in "git" [|"git"; "log"; "--oneline"|] in
  let len = in_channel_length ic in
  really_input_string ic len
```

```ocaml
(* WORKS — read until EOF *)
let read_all ic =
  let buf = Buffer.create 256 in
  (try while true do Buffer.add_channel buf ic 4096 done
   with End_of_file -> ());
  Buffer.contents buf
```

**Trigger**: any subprocess invocation whose output is captured into
a string for parsing (e.g., `mc context` reading `git log` /
`git diff`). Symptom: every parsed field is empty even though the
command runs fine from the shell.

### 11.17 `Arg.parse` calls `anonfun` once per positional, overwriting refs

`Arg.parse` treats the third argument as the *anonfun*, which is
called for every positional argument. If `anonfun` writes into a
single ref, each positional overwrites the previous one:

```ocaml
(* FAILS — `base` ends up holding "HEAD", `head` is never set *)
let base = ref "" in
let head = ref "" in
let set_base s = base := s in
let set_head s = head := s in
Arg.parse ["--budget", ...] (fun s -> if !base = "" then set_base s else set_head s) "..."
```

The clean fix is to collect positionals into a list, then pattern-match
the list (expected length, named fields):

```ocaml
(* WORKS *)
let positionals = ref [] in
let anon s = positionals := s :: !positionals in
Arg.parse ["--budget", ...] anon "..."
let args = List.rev !positionals in
match args with
| [b; h] -> ... (* use b, h *)
| [_]    -> error "missing HEAD"
| _      -> error "wrong number of positionals"
```

**Trigger**: a multi-positional CLI command (e.g., `mc context BASE HEAD`)
where the obvious `set_X` pattern collapses the second positional into
the first. Symptom: the second ref is always empty and the parser
falls into a "missing arg" branch.

### 11.18 Structurally identical record types unify under inference

When two record types in the same module have identical fields
(e.g., `Memory.spec_doc = { path : string; body : string }` and
`Memory.axiom_doc = { path : string; body : string }`), OCaml's
structural row polymorphism can unify them at use-sites:

```ocaml
(* FAILS in another module that consumes Memory.t: *)
let build_spec_items mem =
  List.map (fun s -> s.Memory.path) mem.Memory.spec
(* type error: "expression was expected of type axiom_doc list" *)
```

The compiler propagates whichever name it saw first. Annotate at the
construction site *and* at the consumption site:

```ocaml
let[@warning "-32"] load_spec reader root : spec_doc list = ...
let[@warning "-32"] build_spec_items (mem : Memory.t) =
  let spec : Memory.spec_doc list = mem.Memory.spec in
  List.map (fun (s : Memory.spec_doc) -> s.Memory.path) spec
```

**Trigger**: pure-data record types used by both the producer
(lib/memory.ml) and the consumer (lib/capsule.ml); same field set
across two types in the same module. Symptom: confusing "field X has
type A but expected type B" errors at use-sites in another file.

### 11.19 `lib/codec.ml`'s YAML loader does not handle `---` front-matter

The hand-rolled YAML loader in `lib/codec.ml:412` calls
`parse_yaml_pairs tokens 0` directly. When the first token's
`ycontent` is `---`, the inner `String.index_opt ycontent ':'`
returns `None`, and the loop returns the empty accumulator and the
remaining tokens — which `load_yaml_string` then discards. The
result: every document that begins with YAML front-matter parses
to `Jsonl.Object []`.

```yaml
---                        # ← loop exits here, rest of file is dropped
schema: math-coding/3.0-alpha
id: bootstrap-v3
```

**Symptom**: `Decision.parse_decision` returns `None` for files
that start with `---`. The conformance corpus does not catch this
because its YAML fixtures (e.g.,
`fixtures/conformance/decision/positive-minimal.yaml`) do not use
front-matter.

**Fix (capsule-side workaround)**: in `lib/memory.ml`'s decision
loader, strip leading `---` lines before calling
`Codec.load_yaml_string`. Do not modify `lib/codec.ml` without
also extending the loader's block-scalar support (otherwise the
first scalar after `---` is fine but a subsequent `|` literal
block will still break the rest of the document — see
OCAML_BEST_PRACTICES §1.3 — kernel stays offline and pure, so
extending the loader to handle block scalars is the right place,
not in capsule).

**Trigger**: any caller of `Codec.load_yaml_string` whose input
might start with `---`. Currently affects `bootstrap/decision.yaml`,
`bootstrap/infrastructure-honesty.yaml`,
`bootstrap/kernel-conformance-runner.yaml`, and the YAML
front-matter of `bootstrap/validate-and-context.yaml`.

### 11.20 Dune 3.23 cram tests cannot reach binaries via relative paths

Cram tests in `tests/cram/*.t` are sandboxed: their working directory
is `_build/default/tests/cram/` and the bwrap sandbox only exposes
the test's own files plus BPFM-rewritten paths. Going `..` from the
cram shell's cwd does not expose `_build/default/bin/` — declaring
the binary via `(deps ../bin/mathc.exe)` does not whitelist the
path in the bwrap FS.

The fix used by `tests/cli/*.t` is `(public_name mathc)` in
`bin/dune` combined with `(deps %{bin:mathc})` in the cram stanza
(per arvidj/dune_cram_example pattern). `public_name` causes dune
to install `mathc` to `_build/install/default/bin/mathc` and add
that directory to `$PATH` of every cram test that declares the
dep via `%{bin:...}`. The binary is then invocable by its bare
name (`mathc validate ...`), with rebuild tracked as a normal
file dependency.

Two caveats from the dune 3.23 implementation:

1. The cram shell's cwd is a bwrap tmp dir, not the project root.
   mathc reads files relative to its cwd, so tests must `cd
   "$DUNE_SOURCEROOT"` (exported by dune) before invoking mathc,
   or pass absolute paths via the same env var.

2. Dune cram does NOT implement regex/glob output matchers (see
   https://dune.readthedocs.io/en/stable/tests.html). Captured
   stdout is compared verbatim. For non-deterministic fields
   like timestamps, pipe through `jq` to scrub (e.g., `jq -c
   'del(.now)'`) before comparison.

### 11.21 `dune fmt` exits 0 even when files would be reformatted

`dune fmt` and `dune fmt --preview` both exit 0 unconditionally in
dune 3.23, even when source files would change under the
configured formatter (`ocamlformat`). `--preview` only prints
diffs to stdout without writing; it does not turn the exit code
into a check. `dune fmt` itself has no `--check` flag in dune
3.23 (added later; check `dune fmt --help` for the local build).

**Symptom**: any script that runs `dune fmt --check --root .`
either errors with `unknown option '--check'` (3.23.1) or runs
the apply-mode and exits 0 even on a tree that needs
reformatting. A "fmt clean" gate that just trusts dune's exit
code silently passes on dirty trees.

**Fix** (scripts/fmt-check.sh in this repo): set
`DUNE_DISABLE_PROMOTION=1` and run `dune fmt --root . --preview`.
The promotion-disabled mode causes dune to error (exit 1) when
the formatter would change a file, instead of silently writing
the change. The script preserves dune's diff output so the
human can see what would change.

```sh
DUNE_DISABLE_PROMOTION=1 dune fmt --root . --preview
```

**Trigger**: any CI check that wants to prove "the OCaml tree is
ocamlformat-clean" using `dune fmt` in dune 3.23.x. Also: the
ocamlformat option is `indicate-multiline-delimiters` (not
`indicate-multiline-deltas` as documented in some blog posts);
the latter silently produces
`Unknown option "indicate-multiline-deltas"`.

### 11.24 YAML loader rejects flow-style sequences `[a, b, c]`

The hand-rolled YAML loader in `lib/codec.ml` (look for
`parse_yaml_pairs`/`parse_yaml_value`) only understands
**block-style** YAML. Flow-style sequences written as
`key: [a, b, c]` round-trip as a single `Jsonl.String` with the
verbatim text `[a, b, c]` — `parse_yaml_scalar` treats the whole
bracketed expression as one non-int scalar. Consumers that look
up `obj_array` (or just key access on an Array) silently see a
String and never find what they expect.

```yaml
# FAILS — round-trips as Jsonl.String "[p50, p80, p95, p99]"
percentiles_available: [p50, p80, p95, p99]

# WORKS — block style
percentiles_available:
  - p50
  - p80
  - p95
  - p99
```

**Symptom**: any caller of `Codec.load_yaml_string` that expects
an Array gets a String instead. `bin/Mathc.ml time-estimate` keys
on `Jsonl.String ... ~percentile...` and outputs the wrong value
without surfacing an error.

**Fix (workaround, no kernel change)**: write the file in block
style until a separate Decision extends the loader. Block style
for sequences is `\n- item` per item.

**Trigger**: any YAML file under `bin/data/`, `bootstrap/`, or
`fixtures/` that mixes flow-style with block-style. Note that the
existing fixtures use block style consistently, so this trap was
only hit when bootstrapping new data files (e.g.,
`bin/data/time-distribution.yaml`).

### 11.25 YAML loader rejects flow-style mappings `{ a: 1, b: 2 }`

Same loader, same reason as 11.21: flow-style mappings written
inline as `{ key: value, ... }` are not recognised.

```yaml
# FAILS — round-trips as Jsonl.String "{ p50: 1, p95: 3 }"
trivial: { p50: 1, p95: 3 }

# WORKS — block style
trivial:
  p50: 1
  p95: 3
```

**Symptom**: any consumer that looks up `p50` on the inner
object sees `Jsonl.Null` and reports "unknown class" or "missing
field" even though the file declares it.

**Fix (workaround)**: block-style only. The mix of block-mapping
outer + block-mapping inner keeps the file readable and the
parser happy.

**Trigger**: same as 11.21 — first hit was the time-honesty
distribution file. Any new data file should be audited for
flow-style before commit.

### 11.26 YAML loader rejects decimal numbers

The hand-rolled YAML loader's `parse_yaml_scalar` only treats
strings of digits as `Jsonl.Int`. A decimal such as `1.6` fails
`is_int`, fails the quoted-string check, and falls through to
`Jsonl.String "1.6"`.

```yaml
# FAILS — Jsonl.String "1.6"
factor: 1.6

# WORKS — int * 10
factor_x10: 16
# then divide by 10.0 in the OCaml consumer.
```

**Symptom**: arithmetic consumers (`*.0`, division) type-error
because they receive a String where they expected a Float. The
current `Jsonl.value` does not even have a Float constructor
(see `lib/jsonl.ml:5`); some int encoding is mandatory until
the loader is extended.

**Fix (workaround)**: store int * 10, divide by 10.0 in OCaml.
The companion `bin/Mathc.ml time-estimate` subcommand does this
transparently — see `apply_multiplier` and `interp_p50_p95`.

**Fix (root cause, out of scope here)**: extending `Jsonl.value`
with a Float constructor and teaching `parse_yaml_scalar` to
recognise the optional fractional part of a number. This is a
protected transition (`lib/jsonl.ml` is the canonical value
type used by every consumer); defer to a separate Decision with
positive and negative conformance fixtures covering floats
(round-trip, integer-as-float, exponent form `1.0e2`, `-0.5`,
`1.6e-3`).

**Trigger**: any YAML data file that wants floats. In the
existing repo, none do (Decision files use just ints and
strings); the trap is hit only when introducing a new data
file.

### 11.27 Two copies of the priority table will drift if no fixture compares them

The priority order in `spec/semantics.md` "context-prioritisation"
is the kernel policy; the mirror in `OCAML_BEST_PRACTICES.md` §10.5
exists for implementer convenience
(`bootstrap/validate-and-context.yaml` countercase line 124). Both
files currently carry the same line:

```text
RequiredForGate > Changed > HighRisk > Unresolved > Supporting > Historical
```

A change to either table without a matching change to the other is
a "priority-order drift between spec and implementation"
(`bootstrap/validate-and-context.yaml` risk). Code review alone does
not catch this; the trap is silent because the build succeeds and
the runtime emits the priority list from the OCaml source, not
from the spec.

```text
# Symptom: spec/semantics.md was edited to add "Blocking"
RequiredForGate > Blocking > Changed > HighRisk > Unresolved > Supporting > Historical

# OCAML_BEST_PRACTICES.md §10.5 was NOT edited, still:
RequiredForGate > Changed > HighRisk > Unresolved > Supporting > Historical

# `mc context main HEAD --budget 100000` still emits items[]
# sorted by the unchanged OCaml order. The build passes. The
# spec has drifted.
```

**Fix (mandatory after v0.0.12)**: edit both files together, or
fail the audit gate. The fixture
`tests/fixtures/spec-vs-bp-priority.sh` runs as part of
`./scripts/check.sh` and exits 1 (with a unified diff) on any
byte-level drift between the two lines; passing the check.sh
aggregator therefore requires the two tables to be equal. If a
new priority name is added (e.g., `Blocking` in the example
above), update both files in the same commit. Decisions that
name a new priority without updating the mirror will fail
check.sh.

**Trigger**: any commit that touches `spec/semantics.md` line
~157 ("context-prioritisation" ```text block) or
`OCAML_BEST_PRACTICES.md` line ~892 (§10.5 ```text block)
without touching the other.

**Cross-reference**: `bootstrap/priority-drift.yaml@2`
obligation `priority-drift-detector`. Doc deficit
`doc/AUDIT-0.0.11.md` D3 (closed at v3-alpha-0.0.12).

