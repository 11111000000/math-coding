(* Decision / Obligation decoder. *)

(* sha-match validation per kernel contract §3 and §7.
   Kernel contract §3 requires: if both sibling_yaml(c) and body_section(c)
   exist then sha256(sibling_yaml) = sha256(body_section). Kernel contract §7
   states the same invariant on the Decision entity: if D.body_sha ≠ ∅
   ∧ D.yaml_sha ≠ ∅ then D.body_sha = D.yaml_sha.
   The check is parser-side: when both hashes are recorded on the
   Decision they must agree as strings. If either is absent the
   invariant is vacuously satisfied (no mismatch is possible).
   The string format is `sha256:<64 hex>` per schemas/decision.json,
   so equality of the formatted strings is equality of the digests.

   The byte-range and canonicalisation algorithm that produces the
   two stored hashes is defined in spec/kernel-contract.md §7.1
   (placeholder-substitution sweep on UTF-8 bytes after CRLF→LF
   normalisation, then sha256, prefixed with `sha256:`). See
   decision `d5-body-vs-wrapper-canonical-2026-10` for the
   normative reference; the reference implementation lives in
   scripts/axiom-link-seed.py:105-123 (Python). The OCaml helper
   `body_canonical_sha256` below implements the same algorithm in
   the kernel so future migration tools (and the test in
   tests/body_canonical_test.ml) can compute the digest from raw
   bytes without depending on the Python script.

   T0.2 (stream ε): the original `(d : Domain.decision) -> bool`
   signature was strengthened to a `(bool, Diagnostic.t list) result`
   accumulator so the CLI can surface a single precise
   `MC-SHA-MISMATCH` diagnostic on reject, with the two offending
   hashes embedded in the message and a `next_actions` snippet
   pointing at the recompute algorithm. Callers that only need the
   boolean (e.g., legacy tests) use the `_ignored` accumulator. *)
(* === Slice A (D8 audit closure): typed reject diagnostics ===
 *
 * The parser-level reject reason is now a typed Diagnostic.t. The
 * full parse result is a sum type so the CLI can get both the parsed
 * Domain.decision (on accept) and the actionable Diagnostic.t (on
 * reject). The pure-validation view, `parse_decision`, returns
 * Diagnostic.t option:
 *   - Some diag  → reject; diag is the actionable diagnostic with
 *                  the specific MC-* code, the field name in `path`,
 *                  and a `next_actions` snippet.
 *   - None       → accept (parsing completed without a defect).
 *
 * The full parse view, `parse_decision_value`, returns the typed
 * sum so callers can recover the parsed Domain.decision on accept.
 *
 * Pre-existing binary-reject rules (axiom_link-required,
 * counterexample-required, antithesis-required) keep their current
 * parser-level Reject emit; the CLI pre-parse checks
 * (`bin/Mathc.ml::axiom_link_violation`, etc.) run BEFORE
 * `parse_decision_value` and emit the more specific codes when they
 * fire. The parser still emits its own Reject so the diagnostic
 * surface is informative if the CLI path is bypassed (e.g. unit
 * tests that call `parse_decision_value` directly). *)

type decision_parse = Accept of Domain.decision | Reject of Diagnostic.t

(* body_canonical_sha256 — implements the byte-range and
   canonicalisation algorithm named in spec/kernel-contract.md §7.1
   and decision `d5-body-vs-wrapper-canonical-2026-10`. The input
   is the raw file bytes (UTF-8, LF or CRLF); the output is the
   `sha256:` + 64 hex digest form used in `body_sha` / `yaml_sha`
   fields. The function is pure (no I/O, no allocation beyond the
   result string); the four properties tested in
   tests/body_canonical_test.ml (stability, sensitivity,
   insensitivity-to-placeholder, CRLF-equals-LF) follow from the
   definition. The single-file (trivial) case in the spec
   produces `body_sha = yaml_sha`; the dual-authored case
   (kernel contract §6, sibling YAML) is deferred to a follow-up
   decision. *)
(* The OCaml 5.x `Str` module does not support the
   `\{n\}` interval quantifier (only `*`, `+`, `?`), so
   the placeholder substitution is implemented with
   String.sub + manual character checks rather than
   a regex. The matched shape is:
     `body_sha: "sha256:` + 64 hex chars + `"`
   (total 83 chars). The replacement is the same length
   (length-preserving). Same for `yaml_sha:`.

   Hoisted to top level so `rehash_content` below can stamp a
   real digest through the *same* substitution the digest is
   defined over. Keeping one implementation matters: a second
   copy is exactly how a canonicalisation drifts out of
   agreement with itself. *)
(* The replacement text is the 64 zeros plus the closing quote — NOT
   including the "sha256:" scheme prefix.

   Kernel contract §7.1 reads:
     replace_all(re_body, "body_sha: \"" + placeholder, normalised)
   with placeholder = "sha256:" + "0"*64 + "\"". The matched pattern
   is the WHOLE `body_sha: "sha256:<64hex>`, and the replacement is
   the WHOLE `body_sha: "` + placeholder, i.e.
     `body_sha: "sha256:0000...0"`
   — the scheme prefix appears exactly ONCE.

   The previous value here was `"sha256:" ^ "0"*64 ^ "\""`, and the
   substitution emitted `prefix ^ placeholder` =
   `body_sha: "sha256:sha256:0000...0"` — the prefix twice. Every
   digest the OCaml implementation produced therefore matched
   neither §7.1, nor the Python reference
   (scripts/axiom-link-seed.py:133-169), nor any of the 103 stored
   values that were computed with the correct single-prefix rule.
   It stayed invisible because nothing in the production path ever
   called this function: `sha_match_check` compared two stored
   strings and never recomputed, and tests/body_canonical_test.ml
   asserts only relative properties (stability, sensitivity,
   insensitivity to the placeholder) with no absolute vector
   cross-checked against the reference implementation. *)
let[@warning "-32"] digest_placeholder = String.make 64 '0' ^ "\""

let[@warning "-32"] is_hex_digit c =
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')

(* Replace every occurrence of `<prefix><64 hex>"` with
   `<prefix><placeholder>"`. Length-preserving, so stamping a real
   digest changes no byte offset in the file. *)
let[@warning "-32"] replace_digest_field ~prefix s =
  let prefix_len = String.length prefix in
  let hex_len = 64 in
  let s_len = String.length s in
  let buf = Buffer.create s_len in
  let i = ref 0 in
  let matched_len = prefix_len + hex_len + 1 in
  while !i < s_len do
    if !i + matched_len <= s_len && String.sub s !i prefix_len = prefix then begin
      let hex_start = !i + prefix_len in
      let hex_end = hex_start + hex_len in
      let rec all_hex k =
        if k >= hex_end then true
        else if is_hex_digit s.[k] then all_hex (k + 1)
        else false
      in
      let closing_quote = s.[hex_end] in
      if all_hex hex_start && closing_quote = '"' then begin
        Buffer.add_string buf prefix;
        Buffer.add_string buf digest_placeholder;
        i := !i + matched_len
      end
      else begin
        Buffer.add_char buf s.[!i];
        incr i
      end
    end
    else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  Buffer.contents buf

let[@warning "-32"] crlf_to_lf s =
  let len = String.length s in
  let buf = Buffer.create len in
  let i = ref 0 in
  while !i < len do
    let c = s.[!i] in
    if c = '\r' && !i + 1 < len && s.[!i + 1] = '\n' then begin
      Buffer.add_char buf '\n';
      i := !i + 2
    end
    else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  Buffer.contents buf

let[@warning "-32"] substitute_digest_placeholders s =
  replace_digest_field ~prefix:"body_sha: \"sha256:" s
  |> replace_digest_field ~prefix:"yaml_sha: \"sha256:"

let[@warning "-32"] body_canonical_sha256 (bytes : string) : string =
  let normalized = crlf_to_lf bytes in
  "sha256:" ^ Digest.sha256_hex (substitute_digest_placeholders normalized)

(* Stamp a real digest into both fields. Used by `mathc rehash`.
   `hex` is the 64-character digest WITHOUT the "sha256:" scheme
   prefix — the field prefix already carries it, so passing the full
   `sha256:...` string would write `body_sha: "sha256:sha256:..."`.
   The substitution is length-preserving, so the stamped file's
   canonical form is byte-identical to the form that was hashed:
   the write is a fixed point. *)
let[@warning "-32"] sub_digest_literal ~prefix ~hex text =
  if String.length hex <> 64 || not (String.for_all is_hex_digit hex) then
    invalid_arg
      (Printf.sprintf "stamp_digest: expected 64 hex chars, got %S"
         (String.sub hex 0 (min 16 (String.length hex))));
  let prefix_len = String.length prefix in
  let hex_len = 64 in
  let matched_len = prefix_len + hex_len + 1 in
  let s_len = String.length text in
  let buf = Buffer.create s_len in
  let i = ref 0 in
  while !i < s_len do
    if !i + matched_len <= s_len && String.sub text !i prefix_len = prefix then begin
      let hex_start = !i + prefix_len in
      let hex_end = hex_start + hex_len in
      let rec all_hex k =
        if k >= hex_end then true
        else if is_hex_digit text.[k] then all_hex (k + 1)
        else false
      in
      if all_hex hex_start && text.[hex_end] = '"' then begin
        Buffer.add_string buf prefix;
        Buffer.add_string buf hex;
        (* matched_len consumed the closing quote, so it must be
           re-emitted here or it is silently deleted from the file. *)
        Buffer.add_char buf '"';
        i := !i + matched_len
      end
      else begin
        Buffer.add_char buf text.[!i];
        incr i
      end
    end
    else begin
      Buffer.add_char buf text.[!i];
      incr i
    end
  done;
  Buffer.contents buf

let[@warning "-32"] stamp_digest ~hex s =
  let with_body = sub_digest_literal ~prefix:"body_sha: \"sha256:" ~hex s in
  sub_digest_literal ~prefix:"yaml_sha: \"sha256:" ~hex with_body

(* T0.2 has two layers, and only the first was implemented until this
   revision:

     1. `body_sha = yaml_sha` when both are present (a string
        comparison between the two stored fields).
     2. the stored value equals `body_canonical_sha256(file_bytes)`.

   Layer 1 alone is satisfied by any pair of equal strings, so a
   decision whose *body* was edited after the digest was written
   validated clean, and the 64-zero placeholder emitted by
   `mathc new-decision` validated clean forever (`0^64 = 0^64`).
   That is the property `adoption/SKILL.md:33` advertises as a
   "tamper-evident trail", so layer 2 is the one that carries the
   promise.

   `raw_bytes` is optional so callers that only hold a parsed
   decision keep the old behaviour; every path that has the file on
   disk passes them. Omitting `raw_bytes` is therefore *weaker*,
   which is why the validate path in `bin/Mathc.ml` reads the file
   rather than re-parsing from the value it already holds. *)
let sha_match_check ?raw_bytes (d : Domain.decision) : bool * Diagnostic.t list
    =
  match (d.body_sha, d.yaml_sha) with
  | Some bs, Some ys when bs <> ys ->
      let diag =
        Diagnostic.mc_sha_mismatch ~decision_id:d.Domain.id ~body_sha:bs
          ~yaml_sha:ys ()
      in
      (false, [ diag ])
  | Some bs, Some _ -> (
      match raw_bytes with
      | None -> (true, [])
      | Some bytes ->
          let computed = body_canonical_sha256 bytes in
          if computed = bs then (true, [])
          else
            let diag =
              Diagnostic.mc_sha_digest_stale ~decision_id:d.Domain.id ~stored:bs
                ~computed ()
            in
            (false, [ diag ]))
  | _ -> (true, [])

(* --- digest status over raw bytes (self-check / gate path) ------
 *
 * `sha_match_check` above needs a parsed `Domain.decision`, and the
 * only caller that can supply one is `mathc validate`. Neither
 * `do_self_check` nor `lib/gate.ml::evaluate` has that: self-check
 * enumerates decisions with a line scanner
 * (`bin/Mathc.ml::load_decision_entry`, which deliberately avoids the
 * YAML parser because the parser drops continuation lines of block
 * scalars), and `Gate.evaluate` receives `Memory.t`, whose entries
 * carry the raw text in `Memory.source` and nothing else.
 *
 * Both DO have the bytes. The digest is defined over the file, so the
 * check belongs where the bytes are rather than where a parse
 * succeeded - otherwise the blocking CI step is the one path that
 * cannot see a tampered decision.
 *
 * `Digest_absent` is a first-class outcome, not a silent pass: a
 * waiver or obligations file belongs to another schema family and
 * carries no body_sha, which makes the §7 invariant vacuous. It is
 * returned rather than assumed so a MISSING field stays distinguishable
 * from a CHECKED one in the report. *)
type digest_status =
  | Digest_absent
  | Digest_ok
  | Digest_stale of { stored : string; computed : string }

(* Read back the hex the file itself carries. The matcher is the SAME
   literal shape `replace_digest_field` above substitutes - prefix, 64
   hex digits, closing quote - so the extractor and the canonicaliser
   cannot disagree about which occurrence is "the field". Scanning for
   the shape the substituter rewrites is what makes that guarantee
   mechanical instead of a convention.

   Returns the first match: `replace_digest_field` rewrites every
   occurrence, so a file carrying two is stale either way, and naming
   the first is the least surprising. *)
let[@warning "-32"] stored_digest_hex ~prefix (s : string) : string option =
  let prefix_len = String.length prefix in
  let matched_len = prefix_len + 64 + 1 in
  let s_len = String.length s in
  let i = ref 0 in
  let found = ref None in
  while !i < s_len && !found = None do
    if
      !i + matched_len <= s_len
      && String.sub s !i prefix_len = prefix
      &&
      let hex_start = !i + prefix_len in
      let hex_end = hex_start + 64 in
      let rec all_hex k =
        if k >= hex_end then true
        else if is_hex_digit s.[k] then all_hex (k + 1)
        else false
      in
      all_hex hex_start && s.[hex_end] = '"'
    then found := Some (String.sub s (!i + prefix_len) 64)
    else incr i
  done;
  !found

let[@warning "-32"] digest_status_of_bytes (bytes : string) : digest_status =
  match stored_digest_hex ~prefix:"body_sha: \"sha256:" (crlf_to_lf bytes) with
  | None -> Digest_absent
  | Some hex ->
      let stored = "sha256:" ^ hex in
      let computed = body_canonical_sha256 bytes in
      if String.equal stored computed then Digest_ok
      else Digest_stale { stored; computed }

(* Pure-validation view: maps parse_decision_value into
   Diagnostic.t option. Some diag = reject; None = accept. *)

(* Parse a single obligation acceptance item (verifier OR review).

   An acceptance item NAMES a check. It does not state its outcome:
   the outcome is measured, by running the check, and it is recorded
   in the attestation store. The corpus carried a `result:` key on
   every acceptance item -- 863 of them, all of them `pass` -- and
   the key was read into the domain and then never consulted by
   anything. It was decoration that reads like evidence: a reader
   opening a decision file saw "pass" next to 863 promises and
   could not tell that no check had run.

   The constitution's separation is `declared != derived != attested
   != reviewed != observed`. A `result:` in the promise's own file is
   a DECLARED outcome sitting where an ATTESTED one belongs, and it
   is dropped here: the item keeps the check's name and nothing
   else. A corpus that wants to say "this passed" writes an
   attestation. *)
let[@warning "-32"] parse_verifier v =
  match v with
  | Jsonl.Object ps ->
      let id =
        match Schema.take_string ps "verifier" with Some s -> s | None -> ""
      in
      if id = "" then None else Some (Domain.Verifier { id })
  | _ -> None

let[@warning "-32"] parse_review v =
  match v with
  | Jsonl.Object ps ->
      let rps =
        match Schema.take_object ps "review" with Some o -> o | None -> []
      in
      let authority =
        match Schema.take_string rps "authority" with Some s -> s | None -> ""
      in
      if authority = "" then None
      else
        let minimum_independence =
          match Schema.take_string rps "minimum_independence" with
          | Some s -> Some s
          | None -> None
        in
        Some
          (Domain.Review { review_authority = authority; minimum_independence })
  | _ -> None

let[@warning "-32"] parse_acceptance_item v =
  match v with
  | Jsonl.Object ps when Schema.take_string ps "verifier" <> None ->
      parse_verifier v
  | _ -> ( match parse_review v with Some a -> Some a | None -> None)

(* Shape of a single acceptance item, exposed for diagnostic
   emission. An item with both verifier and review fields is
   ambiguous (A0 separation deficit: two distinct attestation
   sources in the same object) and the conformance runner
   surfaces MC-AMBIGUOUS-ACCEPTANCE per spec/constitution.md
   "Honest status" and OCAML_BEST_PRACTICES §9.1. *)
type acceptance_shape =
  | ShapeVerifier
  | ShapeReview
  | ShapeAmbiguous
  | ShapeMalformed
  | ShapeEmpty
  | ShapeDeclaredResult

let[@warning "-32"] classify_acceptance_item v =
  match v with
  | Jsonl.Object ps -> (
      (* An acceptance item names a check. It no longer states an
         outcome: the `result:` key is gone from the corpus and from
         the schema, because a declared outcome in the promise's own
         file reads like evidence and is not. *)
      let has_verifier_fields = Schema.take_string ps "verifier" <> None in
      let has_review_field = Schema.take_object ps "review" <> None in
      (* An acceptance item that still carries a `result:` key states
         an outcome in the promise's own file. The outcome is
         measured, not declared, so the item is a declared result and
         nothing else. *)
      let declares_result = Schema.take_string ps "result" <> None in
      match (has_verifier_fields, has_review_field) with
      | true, true -> ShapeAmbiguous
      | true, false when declares_result -> ShapeDeclaredResult
      | true, false -> (
          match parse_verifier v with
          | Some _ -> ShapeVerifier
          | None -> ShapeMalformed)
      | false, true -> (
          match parse_review v with
          | Some _ -> ShapeReview
          | None -> ShapeMalformed)
      | false, false -> ShapeEmpty)
  | _ -> ShapeEmpty

(* Per-item position-tagged shape list. Used by the conformance
   runner to emit MC-AMBIGUOUS-ACCEPTANCE per item rather than
   silently dropping the review half. *)
let[@warning "-32"] collect_shapes xs =
  let[@warning "-32"] rec loop i acc = function
    | [] -> List.rev acc
    | v :: rest -> loop (i + 1) ((i, classify_acceptance_item v) :: acc) rest
  in
  loop 0 [] xs

let parse_acceptance v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "all" with
      | Some xs -> Domain.All (List.filter_map parse_acceptance_item xs)
      | None -> (
          match Schema.take_array ps "any" with
          | Some xs -> Domain.Any (List.filter_map parse_acceptance_item xs)
          | _ -> Domain.All []))
  | _ -> Domain.All []

(* `parse_acceptance_with_shapes` is the diagnostic-aware variant:
   it returns both the Domain.acceptance (verifier+review only,
   never ambiguous — ambiguous items are dropped) and the per-item
   shape list for diagnostic emission. Callers that want to surface
   MC-AMBIGUOUS-ACCEPTANCE should iterate the shape list and emit
   one diagnostic per ShapeAmbiguous / ShapeMalformed item. *)
let[@warning "-32"] parse_acceptance_with_shapes v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "all" with
      | Some xs ->
          let shapes = collect_shapes xs in
          (Domain.All (List.filter_map parse_acceptance_item xs), shapes)
      | None -> (
          match Schema.take_array ps "any" with
          | Some xs ->
              let shapes = collect_shapes xs in
              (Domain.Any (List.filter_map parse_acceptance_item xs), shapes)
          | _ -> (Domain.All [], [])))
  | _ -> (Domain.All [], [])

let[@warning "-32"] parse_outcome v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "statement" with
          | Some statement -> Some { Domain.id; Domain.statement }
          | _ -> None)
      | _ -> None)
  | _ -> None

(* `parse_required_attestations` reads the optional
   `required_attestations:` block on a Decision. Each item is a
   (kind_, producer) pair that the kernel will look for in the
   attestation store. Implementation lives here (not in `parse_decision`)
   because `Memory.decision_entry` does not carry the field — the
   gate retrieves it on demand via a parser pass. Kept optional:
   absence → empty list, which is a no-op for the gate. The
   shape-validation (kind enum + producer string) is in
   `bin/Mathc.ml::required_attestations_violation`, mirroring the
   axiom_link/counterexample pattern. *)
type required_attestation = {
  ra_kind : string;
  ra_producer : string;
  ra_scope_paths : string list;
}

let[@warning "-32"] parse_scope_paths ra_obj =
  match Schema.take_array ra_obj "scope_paths" with
  | Some xs ->
      List.filter_map
        (function
          | Jsonl.String s when String.trim s <> "" -> Some s | _ -> None)
        xs
  | _ -> []

let[@warning "-32"] parse_required_attestations v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "required_attestations" with
      | Some items -> (
          let rec loop = function
            | [] -> []
            | item :: rest -> (
                match item with
                | Jsonl.Object item_ps ->
                    let k =
                      match Schema.take_string item_ps "kind_" with
                      | Some s -> s
                      | None -> ""
                    in
                    let p =
                      match Schema.take_string item_ps "producer" with
                      | Some s -> s
                      | None -> ""
                    in
                    if k = "" || p = "" then loop rest
                    else
                      {
                        ra_kind = k;
                        ra_producer = p;
                        ra_scope_paths = parse_scope_paths item_ps;
                      }
                      :: loop rest
                | _ -> loop rest)
          in
          match loop items with _ :: _ as xs -> Some xs | [] -> None)
      | None -> None)
  | _ -> None

let[@warning "-32"] parse_reversal v =
  match v with
  | Jsonl.Object ps ->
      let signal =
        match Schema.take_string ps "signal" with Some s -> s | None -> ""
      in
      if signal = "" then None
      else
        let condition = Schema.take_string ps "condition" in
        let action_str =
          match Schema.take_string ps "action" with Some s -> s | None -> ""
        in
        let action =
          match Codec.parse_action action_str with
          | Some a -> a
          | None -> `Review
        in
        Some { Domain.signal; condition; Domain.action }
  | _ -> None

(* === T6.2 helper: counterexample-mode-required.

   Rule (spec/kernel-contract.md §11 + decisions/plan-2026-10-improvements/t6-2.yaml):
     - mode ∈ {tiny, light}  + empty counterexample → allowed (legacy soft
       warning at most).
     - mode ∈ {standard, strict, exhaustive} + empty counterexample → reject.

   The check fires AFTER the counterexample field has been parsed (so we
   know the value the author intended) and BEFORE the Decision record is
   constructed. Returning None from `parse_decision` for the rule is the
   same path the axiom_link rule uses (lib/decision.ml:845); the CLI's
   `validate_with_counts` distinguishes the two specific causes by
   inspecting the raw JSON BEFORE calling `parse_decision`, so the
   surface diagnostic is precise (see
   bin/Mathc.ml::axiom_link_violation and
   bin/Mathc.ml::counterexample_violation). This split — parser-side
   reject for the kernel's authoritative reading, CLI-side pre-check
   for the precise diagnostic — matches the T0.2 (sha-match) and T2.2
   (axiom_link) patterns. *)

(* Counterexample is "present and meaningful" iff the parsed field is a
   non-empty string after trimming. The parser supports two forms
   (YAML scalar / JSON array); both reduce to a single `string option`
   at this layer. Whitespace-only values are treated as empty so
   authors cannot satisfy the rule with a literal " " placeholder.
   Exposed publicly for use by `bin/Mathc.ml::counterexample_violation`
   so the CLI's pre-parse check and the parser's enforcement agree
   on what "empty" means. *)
let counterexample_meaningful_opt (s : string option) : bool =
  match s with Some t when String.trim t <> "" -> true | _ -> false

(* Antithesis (v3 dialectic slot, per spec/kernel-contract.md §11):
   same "present and meaningful" check as counterexample. Authors cannot
   satisfy the rule with whitespace-only strings. *)
let antithesis_meaningful_opt (s : string option) : bool =
  match s with Some t when String.trim t <> "" -> true | _ -> false

(* mode >= standard: standard | strict | exhaustive | considered. The
   order on the mode sum type is intentional (Domain.mode
   definition), so a simple OCaml polymorphic compare works for the
   floor check. The `Considered` constructor joins the modern floor
   because it carries the same assurance strength as Standard
   (see `decisions/antithesis-mode-considered-2026-10`). *)
let mode_geq_standard (m : Domain.mode) : bool =
  match m with
  | `Standard | `Strict | `Exhaustive | `Considered -> true
  | `Tiny | `Light -> false

(* mode >= considered: only `Considered` triggers the antithesis
   requirement (kernel contract §11). The `mode_geq_considered` predicate
   replaces the prior `mode_geq_standard` guard on
   `antithesis_required_missing`. See
   `decisions/antithesis-mode-considered-2026-10` for the rationale
   and the strongest countercase. *)
let mode_geq_considered (m : Domain.mode) : bool =
  match m with
  | `Considered -> true
  | `Tiny | `Light | `Standard | `Strict | `Exhaustive -> false

(* === Axiom-link detection (kernel contract §17 "Inline axiom change")
   ===
   Helpers below `populate_axiom_addresses` are kept ABOVE the
   mutually-recursive parser chain so the chain can extend all
   the way down to `parse_decision` without `let` interrupting
   `and`. The helpers do not call back into the parser chain. *)

(* A token is "axiom-shaped" iff it starts with `A`, has digits,
   optionally has `@rev` or `.sub` suffix. Mirrors the regex used
   by the prior `lib/re_evaluation.ml::scan_axiom_ids` bridge so
   the parser here accepts the same set of tokens. *)
let[@warning "-32"] is_axiom_token s =
  let n = String.length s in
  if n < 2 then false
  else if s.[0] <> 'A' then false
  else
    let re = Str.regexp "^A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?$" in
    try
      ignore (Str.search_forward re s 0);
      true
    with Not_found -> false

(* Strip surrounding double or single quotes from a YAML scalar
   that survived the loader unquoted. The kernel's loader does
   not strip quotes automatically; we mirror `re_evaluation.ml`'s
   helper so explicit `axiom: 'A0'` and `axiom: "A0"` survive
   identically across the parser and the prior bridge. *)
let[@warning "-32"] strip_quoted s =
  let s = String.trim s in
  let n = String.length s in
  if n >= 2 && s.[0] = '"' && s.[n - 1] = '"' then String.sub s 1 (n - 2)
  else if n >= 2 && s.[0] = '\'' && s.[n - 1] = '\'' then String.sub s 1 (n - 2)
  else s

(* Prose scan: extract every `\<A[0-9]+(\([@.][A-Za-z0-9_.-]*\)?\>`
   token from a single string. Returns tokens in source order,
   deduplicated. *)
let[@warning "-32"] axiom_tokens_in_string s =
  let re = Str.regexp "\\<A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?\\>" in
  let rec scan pos acc =
    try
      ignore (Str.search_forward re s pos);
      let tok = Str.matched_string s in
      let acc' =
        if is_axiom_token tok && not (List.mem tok acc) then tok :: acc else acc
      in
      scan (Str.match_end ()) acc'
    with Not_found -> acc
  in
  scan 0 []

(* Walk the Jsonl tree once; for every Object key that is one of
   `axiom` / `axiom-id` / `axioms`, extract the scalar or list
   value as axiom-shaped tokens (mirrors `collect_value` and the
   `axiom` / `axiom-id` / `axioms` branches of `scan_axiom_ids`).
   For every other key, recurse into the value (and arrays), so
   prose tokens like "per A1 honesty" inside an obligation claim
   are picked up regardless of where they live.

   Order in the returned list is "key-derived first, prose
   last", matching `scan_axiom_ids`'s reverse-occurrence order
   semantics. *)
let[@warning "-32"] rec collect_axiom_tokens_from_value = function
  | Jsonl.String s -> axiom_tokens_in_string s
  | Jsonl.Array xs -> List.concat_map collect_axiom_tokens_from_value xs
  | Jsonl.Object ps ->
      let from_key (k, v) =
        if k = "axiom" || k = "axiom-id" || k = "axioms" then
          match v with
          | Jsonl.String s ->
              let stripped = strip_quoted s in
              if is_axiom_token stripped then [ stripped ] else []
          | Jsonl.Array xs ->
              List.concat_map
                (fun x ->
                  match x with
                  | Jsonl.String s ->
                      let stripped = strip_quoted s in
                      if is_axiom_token stripped then [ stripped ] else []
                  | _ -> [])
                xs
          | _ -> []
        else []
      in
      let from_keys = List.concat_map from_key ps in
      let from_strings =
        List.concat_map (fun (_, v) -> collect_axiom_tokens_from_value v) ps
      in
      from_keys @ from_strings
  | _ -> []

let rec parse_assumption v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | Some id -> (
          match Schema.take_string ps "state" with
          | Some state_str -> (
              match Codec.parse_assumption_state state_str with
              | Some state -> (
                  match Schema.take_string ps "statement" with
                  | Some statement -> (
                      match Schema.take_string ps "owner" with
                      | Some owner ->
                          let consequence =
                            Schema.take_string ps "consequence_if_false"
                          in
                          let review_on =
                            match Schema.take_array ps "review_on" with
                            | Some xs ->
                                List.filter_map
                                  (fun v ->
                                    match v with
                                    | Jsonl.Object rps -> (
                                        match
                                          Schema.take_string rps "signal"
                                        with
                                        | Some s ->
                                            let date =
                                              Schema.take_string rps "date"
                                            in
                                            Some (s, date)
                                        | _ -> None)
                                    | _ -> None)
                                  xs
                            | _ -> []
                          in
                          let evidence = Schema.take_string ps "evidence" in
                          (* confidence is a float in [0.0, 1.0] per
                             spec/kernel-contract.md §7. Jsonl now parses
                             Float values (lib/jsonl.ml); preserve the
                             authored value rather than dropping it. *)
                          let confidence =
                            match List.assoc_opt "confidence" ps with
                            | Some (Jsonl.Float f) -> Some f
                            | Some (Jsonl.Int i) -> Some (float_of_int i)
                            | _ -> None
                          in
                          Some
                            {
                              Domain.id;
                              Domain.state;
                              Domain.statement;
                              Domain.owner;
                              Domain.consequence_if_false = consequence;
                              Domain.review_on;
                              Domain.evidence;
                              Domain.confidence;
                            }
                      | _ -> None)
                  | _ -> None)
              | _ -> None)
          | _ -> None)
      | _ -> None)
  | _ -> None

and parse_obligation_domain v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "obligation_kind" with
      | Some obligation_kind ->
          let path_namespace =
            match Schema.take_string ps "path_namespace" with
            | Some s -> s
            | None -> ""
          in
          Some { Domain.obligation_kind; Domain.path_namespace }
      | _ -> None)
  | _ -> None

(* === Form-aware parsers (Phase 1) ===
   The schema in schemas/decision.json documents TWO forms for
   `intent` and `scope` (YAML form vs JSON form). parse_decision_yaml
   normalises the input to the JSON form before delegating to
   parse_decision. No fields are injected — only the structural
   shape is transformed. *)

and[@warning "-32"] extract_field pairs key = List.assoc_opt key pairs

and[@warning "-32"] parse_intent_field v =
  match v with
  | Jsonl.String s when String.trim s <> "" -> Some (s, s)
  | Jsonl.Object ips -> (
      match Schema.take_string ips "source" with
      | Some source -> (
          match Schema.take_string ips "text" with
          | Some text -> Some (source, text)
          | _ -> None)
      | _ -> None)
  | _ -> None

and[@warning "-32"] parse_scope_yaml_form obj =
  match obj with
  | Jsonl.Object ps ->
      let paths =
        match List.assoc_opt "paths" ps with
        | Some (Jsonl.Array xs) ->
            List.filter_map
              (fun v ->
                match v with
                | Jsonl.String s when String.trim s <> "" ->
                    Some (Domain.PathTarget { path = s; match_ = `Tree })
                | _ -> None)
              xs
        | _ -> []
      in
      let caps =
        match List.assoc_opt "capabilities" ps with
        | Some (Jsonl.Array xs) ->
            List.filter_map
              (fun v ->
                match v with
                | Jsonl.String s when String.trim s <> "" ->
                    Some (Domain.CapabilityTarget s)
                | _ -> None)
              xs
        | _ -> []
      in
      let excls =
        match List.assoc_opt "exclusions" ps with
        | Some (Jsonl.Array xs) ->
            List.filter_map
              (fun v ->
                match v with
                | Jsonl.String s when String.trim s <> "" ->
                    Some (Domain.PathTarget { path = s; match_ = `Tree })
                | _ -> None)
              xs
        | _ -> []
      in
      paths @ caps @ excls
  | _ -> []

and[@warning "-32"] parse_scope_field v =
  match v with
  | Jsonl.Array xs -> Codec.parse_scope xs
  | Jsonl.Object _ -> parse_scope_yaml_form v
  | _ -> []

(* parse_decision_yaml: form-aware entry point.
   Transforms the YAML form to the JSON form expected by
   parse_decision:
     - `intent` (String) → `intent` ({source, text})
     - `scope` (Object) → `scope` (Array of scope_target)
   Risk is required by parse_decision (per the original schema
   intent); if absent, the form-aware path returns None. The schema
   is being updated to make risk optional. *)
and scope_target_to_json (t : Domain.scope_target) : Jsonl.value =
  match t with
  | Domain.PathTarget { path; match_ } ->
      Jsonl.Object
        [
          ("kind", Jsonl.String "path");
          ("path", Jsonl.String path);
          ( "match",
            Jsonl.String
              (match match_ with `Exact -> "exact" | `Tree -> "tree") );
        ]
  | Domain.CapabilityTarget c ->
      Jsonl.Object
        [
          ("kind", Jsonl.String "capability");
          ("capability", Jsonl.String c);
          ("match", Jsonl.String "tree");
        ]
  | Domain.InterfaceTarget i ->
      Jsonl.Object
        [ ("kind", Jsonl.String "interface"); ("interface", Jsonl.String i) ]

and parse_decision_yaml v =
  match v with
  | Jsonl.Object ps -> (
      let ps' =
        match extract_field ps "intent" with
        | Some (Jsonl.String s) when String.trim s <> "" ->
            ( "intent",
              Jsonl.Object
                [ ("source", Jsonl.String s); ("text", Jsonl.String s) ] )
            :: List.remove_assoc "intent" ps
        | _ -> ps
      in
      let ps'' =
        match extract_field ps' "scope" with
        | Some scope_v
          when match scope_v with Jsonl.Object _ -> true | _ -> false ->
            let targets = parse_scope_yaml_form scope_v in
            let json_targets = List.map scope_target_to_json targets in
            ("scope", Jsonl.Array json_targets) :: List.remove_assoc "scope" ps'
        | _ -> ps'
      in
      (* Risk: per parser-risk-owner-default decision (kernel-default-owner-landed),
         the `owner` field in the risk object is treated as optional
         and defaults to "human:maintainer" if absent. We normalise
         the value here so the body of parse_decision sees a proper
         `risk` object with both `declared_triggers` and `owner` fields
         present. If the risk block is missing entirely, we inject
         the schema default { declared_triggers = []; owner =
         "human:maintainer" } (same as the schema's documented default). *)
      let ps_with_risk =
        match extract_field ps'' "risk" with
        | Some (Jsonl.Object risk_pairs) ->
            let owner_present = List.mem_assoc "owner" risk_pairs in
            let risk_pairs' =
              if owner_present then risk_pairs
              else ("owner", Jsonl.String "human:maintainer") :: risk_pairs
            in
            ("risk", Jsonl.Object risk_pairs') :: List.remove_assoc "risk" ps''
        | _ ->
            (* risk missing or non-object: inject the default. *)
            ( "risk",
              Jsonl.Object
                [
                  ("declared_triggers", Jsonl.Array []);
                  ("owner", Jsonl.String "human:maintainer");
                ] )
            :: ps''
      in
      match parse_decision_value (Jsonl.Object ps_with_risk) with
      | Accept d -> Some d
      | Reject _ -> None)
  | _ -> (
      match parse_decision_value v with Accept d -> Some d | Reject _ -> None)

and[@warning "-32"] parse_obligation_with parent_id v =
  match v with
  | Jsonl.Object ps ->
      let id =
        match Schema.take_string ps "id" with Some s -> s | None -> ""
      in
      let decision =
        match Schema.take_string ps "decision" with
        | Some s -> s
        | None -> parent_id
      in
      let claim =
        match Schema.take_string ps "claim" with
        | Some s -> s
        | None -> (
            match Schema.take_string ps "statement" with
            | Some s -> s
            | None -> "")
      in
      if id = "" || decision = "" || claim = "" then None
      else
        let outcome = Schema.take_string ps "outcome" in
        let subjects =
          match Schema.take_array ps "subjects" with
          | Some xs -> Codec.parse_scope xs
          | _ -> []
        in
        let acceptance =
          match Schema.take_object ps "acceptance" with
          | Some a -> parse_acceptance (Jsonl.Object a)
          | _ -> parse_acceptance v
        in
        let phase_str =
          match Schema.take_string ps "phase" with
          | Some s -> s
          | None -> "pre_merge"
        in
        let phase =
          match Codec.parse_phase phase_str with
          | Some p -> p
          | None -> `PreMerge
        in
        let kind_str =
          match Schema.take_string ps "kind" with
          | Some s -> s
          | None -> "invariant"
        in
        let kind =
          match Codec.parse_obligation_kind kind_str with
          | Some k -> k
          | None -> `Invariant
        in
        let obligation_domain =
          match Schema.take_object ps "obligation_domain" with
          | Some ops -> parse_obligation_domain (Jsonl.Object ops)
          | _ -> None
        in
        Some
          {
            Domain.id;
            decision;
            Domain.outcome;
            Domain.claim;
            subjects;
            Domain.acceptance;
            Domain.kind;
            Domain.phase;
            Domain.obligation_domain;
          }
  | _ -> None

(* Relations parser (kernel contract §7, 8 kinds). The JSON object under
   "relations" carries up to 9 array-valued fields; the 8 relation
   kinds defined by kernel contract §7 are revises, supersedes, refines,
   depends_on, conflicts_with, addresses, implements, verifies.
   The 9th field `superseded_by` is the inverse of `supersedes` and
   is already populated by existing decisions; both directions are
   carried for convenience. Missing fields default to the empty
   list. The whole `relations` object may be absent; in that case
   the result is the empty relation set. *)
and parse_relations v =
  let[@warning "-32"] extract_ids ps key =
    match Schema.take_array ps key with
    | Some xs ->
        List.filter_map
          (fun x -> match x with Jsonl.String s -> Some s | _ -> None)
          xs
    | None -> []
  in
  match v with
  | Jsonl.Object ps ->
      {
        Domain.revises = extract_ids ps "revises";
        Domain.supersedes = extract_ids ps "supersedes";
        Domain.superseded_by = extract_ids ps "superseded_by";
        Domain.refines = extract_ids ps "refines";
        Domain.depends_on = extract_ids ps "depends_on";
        Domain.conflicts_with = extract_ids ps "conflicts_with";
        Domain.addresses = extract_ids ps "addresses";
        Domain.implements = extract_ids ps "implements";
        Domain.verifies = extract_ids ps "verifies";
      }
  | _ ->
      {
        Domain.revises = [];
        Domain.supersedes = [];
        Domain.superseded_by = [];
        Domain.refines = [];
        Domain.depends_on = [];
        Domain.conflicts_with = [];
        Domain.addresses = [];
        Domain.implements = [];
        Domain.verifies = [];
      }

(* Populate `relations.addresses` from the three sources listed
   in the comment block above (YAML block, explicit keys, prose
   tokens). Existing `relations.addresses` (already extracted
   from the YAML block by `parse_relations`) is preserved
   verbatim; the new sources are unioned in front, deduplicated.
   The ordering matches `scan_axiom_ids` ∪ existing semantics so
   the post-migration `relations.addresses` is set-equal (and
   the list is order-stable for human readers) for every active
   decision. *)
and populate_axiom_addresses ps (relations : Domain.relations) :
    Domain.relations =
  let existing = relations.Domain.addresses in
  let scanned = collect_axiom_tokens_from_value (Jsonl.Object ps) in
  let merged =
    List.fold_left
      (fun acc id -> if List.mem id acc then acc else id :: acc)
      existing scanned
  in
  { relations with Domain.addresses = merged }

and parse_decision_value v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "id" with
      | None ->
          Reject
            (Diagnostic.mc_missing_id
               "decision is missing the required top-level field: id")
      | Some id when String.trim id = "" ->
          Reject
            (Diagnostic.mc_invalid_id_format ~id
               "id is present but empty: schemas/decision.json requires a \
                short lower-snake-case id, optionally suffixed with @rev")
      | Some id -> (
          (* body_sha / yaml_sha pattern enforcement
             (decisions/kernel-bugs-v3.4-2026-10). The schema
             declares the pattern `^sha256:[0-9a-f]{64}$` but the
             kernel historically only enforced equality between the
             two fields. A literal shell-template artifact like
             `"sha256:' + sha + '"` would survive equality check
             (it equals itself). The pattern check rejects any
             present-but-non-matching value with
             `MC-BODY-SHA-PATTERN-VIOLATION` (Block, exit 1)
             BEFORE the parser continues. Either field may be
             absent (the sha-mismatch invariant is vacuously
             satisfied when one is missing), but if present, must
             match. *)
          let check_sha_pattern field =
            match Schema.take_string ps field with
            | Some s
              when (not (String.starts_with ~prefix:"sha256:" s))
                   || String.length s <> 71 ->
                Some
                  (Diagnostic.mc_body_sha_pattern_violation ~decision_id:id
                     ~field ~value:s ())
            | _ -> None
          in
          match
            (check_sha_pattern "body_sha", check_sha_pattern "yaml_sha")
          with
          | Some diag, _ | None, Some diag -> Reject diag
          | None, None -> (
              match Schema.take_string ps "revision" with
              | None ->
                  Reject
                    (Diagnostic.mc_missing_revision
                       "decision is missing the required top-level field: \
                        revision")
              | Some revision when String.trim revision = "" ->
                  Reject
                    (Diagnostic.mc_invalid_revision_format ~revision
                       "revision is present but empty: schemas/decision.json \
                        requires a non-empty revision string")
              | Some revision -> (
                  let parents =
                    match Schema.take_array ps "parents" with
                    | Some xs ->
                        List.filter_map
                          (fun x ->
                            match x with Jsonl.String s -> Some s | _ -> None)
                          xs
                    | _ -> []
                  in
                  (* counterexample / antithesis / axiom-link precedence
                 (A3 self-application): the dialectical-slot checks fire
                 BEFORE the `intent:` shape check. Without this
                 ordering, an YAML-form intent scalar combined with a
                 missing counterexample surfaces
                 MC-MISSING-INTENT through the pure-validation view
                 (parse_decision, called as a fallback by
                 bin/Mathc.ml when parse_decision_yaml returns None),
                 hiding the real cause. By computing the
                 counterexample/antithesis state here and emitting the
                 precise diagnostic first, the user sees the right
                 MC-COUNTEREXAMPLE-MISSING code. The CLI pre-check in
                 bin/Mathc.ml::counterexample_violation handles the
                 same case at the dispatch level. *)
                  let mode_str_early =
                    match Schema.take_string ps "mode" with
                    | Some s -> s
                    | None -> "standard"
                  in
                  let mode_early =
                    match Codec.parse_mode mode_str_early with
                    | Some m -> m
                    | None -> `Standard
                  in
                  let state_str_early =
                    match Schema.take_string ps "state" with
                    | Some s -> s
                    | None -> "active"
                  in
                  let state_early =
                    match Codec.parse_decision_state state_str_early with
                    | Some s -> s
                    | None -> `Active
                  in
                  let counterexample_present =
                    match Schema.take_string ps "counterexample" with
                    | Some s when String.trim s <> "" -> true
                    | _ -> (
                        match Schema.take_array ps "counterexample" with
                        | Some xs ->
                            List.exists
                              (fun x ->
                                match x with
                                | Jsonl.String s when String.trim s <> "" ->
                                    true
                                | _ -> false)
                              xs
                        | None -> false)
                  in
                  let counterexample_required_missing =
                    mode_geq_standard mode_early
                    && (not counterexample_present)
                    && state_early = `Active
                  in
                  if counterexample_required_missing then
                    let decision_id_early =
                      match Schema.take_string ps "id" with
                      | Some s -> s
                      | None -> ""
                    in
                    Reject
                      (Diagnostic.mc_counterexample_missing
                         ~decision_id:decision_id_early
                         ~severity:Diagnostic.Block
                         "counterexample is required for mode >= standard; see \
                          spec/kernel-contract.md §11. Add a counterexample \
                          section naming the strongest objection considered \
                          and rejected, or downgrade to mode: light. (Reported \
                          in preference to MC-MISSING-INTENT because the \
                          intent slot may legitimately be a YAML block scalar; \
                          the diagnostic must reflect the actual \
                          dialectical-slot deficit.)")
                  else
                    match Schema.take_object ps "intent" with
                    | None ->
                        Reject
                          (Diagnostic.mc_missing_intent
                             "decision is missing the required top-level \
                              field: intent (expected {source, text} object or \
                              YAML scalar)")
                    | Some ips -> (
                        match Schema.take_string ips "source" with
                        | None ->
                            Reject
                              (Diagnostic.mc_missing_intent
                                 "intent.source is missing: \
                                  schemas/decision.json requires intent to \
                                  declare a source key (e.g. {source: \
                                  \"issue:1\", text: \"...\"})")
                        | Some source -> (
                            match Schema.take_string ips "text" with
                            | None ->
                                Reject
                                  (Diagnostic.mc_missing_intent
                                     "intent.text is missing: \
                                      schemas/decision.json requires intent to \
                                      declare a text key")
                            | Some text -> (
                                match Schema.take_string ps "commitment" with
                                | None ->
                                    Reject
                                      (Diagnostic.mc_missing_commitment
                                         "decision is missing the required \
                                          top-level field: commitment")
                                | Some commitment -> (
                                    let scope =
                                      match Schema.take_array ps "scope" with
                                      | Some xs -> Codec.parse_scope xs
                                      | _ -> []
                                    in
                                    let outcomes =
                                      match Schema.take_array ps "outcomes" with
                                      | Some xs ->
                                          List.filter_map parse_outcome xs
                                      | _ -> []
                                    in
                                    let assumptions =
                                      match
                                        Schema.take_array ps "assumptions"
                                      with
                                      | Some xs ->
                                          List.filter_map parse_assumption xs
                                      | _ -> []
                                    in
                                    let obligations =
                                      match
                                        Schema.take_array ps "obligations"
                                      with
                                      | Some xs ->
                                          List.filter_map
                                            (parse_obligation_with id) xs
                                      | _ -> []
                                    in
                                    let reversal =
                                      match Schema.take_array ps "reversal" with
                                      | Some xs ->
                                          List.filter_map parse_reversal xs
                                      | _ -> []
                                    in
                                    match Schema.take_object ps "risk" with
                                    | None ->
                                        Reject
                                          (Diagnostic.mc_missing_risk_owner
                                             "decision is missing the required \
                                              top-level field: risk (with \
                                              declared_triggers and owner)")
                                    | Some rps -> (
                                        let triggers =
                                          match
                                            Schema.take_array rps
                                              "declared_triggers"
                                          with
                                          | Some xs ->
                                              List.filter_map
                                                (fun v ->
                                                  match v with
                                                  | Jsonl.String s -> Some s
                                                  | _ -> None)
                                                xs
                                          | _ -> []
                                        in
                                        match
                                          Schema.take_string rps "owner"
                                        with
                                        | None ->
                                            Reject
                                              (Diagnostic.mc_missing_risk_owner
                                                 "risk.owner is missing: \
                                                  schemas/decision.json \
                                                  requires the risk block to \
                                                  declare an owner key (e.g. \
                                                  owner: human:maintainer)")
                                        | Some owner -> (
                                            (* counterexample: two forms.
                                         YAML form: scalar string.
                                         JSON form: array of strings.
                                         Accept both. *)
                                            let counterexample =
                                              match
                                                Schema.take_string ps
                                                  "counterexample"
                                              with
                                              | Some s -> Some s
                                              | None -> (
                                                  match
                                                    Schema.take_array ps
                                                      "counterexample"
                                                  with
                                                  | Some xs ->
                                                      List.filter_map
                                                        (fun x ->
                                                          match x with
                                                          | Jsonl.String s ->
                                                              Some s
                                                          | _ -> None)
                                                        xs
                                                      |> String.concat "\n"
                                                      |> fun s -> Some s
                                                  | _ -> None)
                                            in
                                            let state_str =
                                              match
                                                Schema.take_string ps "state"
                                              with
                                              | Some s -> s
                                              | None -> "active"
                                            in
                                            let state =
                                              match
                                                Codec.parse_decision_state
                                                  state_str
                                              with
                                              | Some s -> s
                                              | None -> `Active
                                            in
                                            let mode_str =
                                              match
                                                Schema.take_string ps "mode"
                                              with
                                              | Some s -> s
                                              | None -> "standard"
                                            in
                                            let mode =
                                              match
                                                Codec.parse_mode mode_str
                                              with
                                              | Some m -> m
                                              | None -> `Standard
                                            in
                                            let mode_floor_used =
                                              match
                                                Schema.take_string ps
                                                  "mode_floor_used"
                                              with
                                              | Some s -> (
                                                  match Codec.parse_mode s with
                                                  | Some m -> Some m
                                                  | None -> None)
                                              | None -> None
                                            in
                                            let antithesis =
                                              Schema.take_string ps "antithesis"
                                            in
                                            let body_sha =
                                              Schema.take_string ps "body_sha"
                                            in
                                            let yaml_sha =
                                              Schema.take_string ps "yaml_sha"
                                            in
                                            let relations =
                                              match
                                                Schema.take_object ps
                                                  "relations"
                                              with
                                              | Some rps ->
                                                  parse_relations
                                                    (Jsonl.Object rps)
                                              | _ -> parse_relations Jsonl.Null
                                            in
                                            let relations =
                                              populate_axiom_addresses ps
                                                relations
                                            in
                                            let axiom_link =
                                              match
                                                Schema.take_array ps
                                                  "axiom_link"
                                              with
                                              | Some xs ->
                                                  List.filter_map
                                                    (fun x ->
                                                      match x with
                                                      | Jsonl.String s -> Some s
                                                      | _ -> None)
                                                    xs
                                              | _ -> []
                                            in
                                            (* axiom_link format: every token must
                                         match the axiom-shaped regex. *)
                                            let bad_axiom_token =
                                              List.find_opt
                                                (fun tok ->
                                                  not (is_axiom_token tok))
                                                axiom_link
                                            in
                                            let counterexample_required_missing
                                                =
                                              mode_geq_standard mode
                                              && not
                                                   (counterexample_meaningful_opt
                                                      counterexample)
                                            in
                                            let antithesis_required_missing =
                                              mode_geq_considered mode
                                              && not
                                                   (antithesis_meaningful_opt
                                                      antithesis)
                                            in
                                            match bad_axiom_token with
                                            | Some tok ->
                                                Reject
                                                  (Diagnostic
                                                   .mc_invalid_axiom_link
                                                     ~token:tok
                                                     (Printf.sprintf
                                                        "axiom_link contains a \
                                                         non-axiom-shaped \
                                                         token: `%s` (expected \
                                                         form is `A<digits>` \
                                                         optionally suffixed \
                                                         with `@rev` or \
                                                         `.sub`)"
                                                        tok))
                                            | None ->
                                                if
                                                  state = `Active
                                                  && axiom_link = []
                                                then
                                                  Reject
                                                    (Diagnostic
                                                     .axiom_link_missing
                                                       ~decision_id:id ())
                                                else if
                                                  antithesis_required_missing
                                                then
                                                  Reject
                                                    (Diagnostic
                                                     .mc_antithesis_missing
                                                       ~decision_id:id
                                                       ~severity:
                                                         Diagnostic.Block
                                                       "antithesis is required \
                                                        for mode = considered")
                                                else if
                                                  counterexample_required_missing
                                                then
                                                  Reject
                                                    (Diagnostic
                                                     .mc_counterexample_missing
                                                       ~decision_id:id
                                                       ~severity:
                                                         Diagnostic.Block
                                                       "counterexample is \
                                                        required for mode >= \
                                                        standard")
                                                else
                                                  Accept
                                                    {
                                                      Domain.id;
                                                      Domain.rev = revision;
                                                      Domain.parents;
                                                      Domain.intent_source =
                                                        source;
                                                      Domain.intent_text = text;
                                                      Domain.commitment;
                                                      Domain.scope;
                                                      Domain.outcomes;
                                                      Domain.obligations;
                                                      Domain.assumptions;
                                                      Domain.reversal;
                                                      Domain.risk =
                                                        {
                                                          Domain
                                                          .declared_triggers =
                                                            triggers;
                                                          Domain.owner;
                                                        };
                                                      Domain.relations;
                                                      Domain.counterexample;
                                                      Domain.antithesis;
                                                      Domain.state;
                                                      Domain.mode;
                                                      Domain.mode_floor_used;
                                                      Domain.body_sha;
                                                      Domain.yaml_sha;
                                                      Domain.axiom_link;
                                                    }))))))))))
  | _ ->
      Reject
        (Diagnostic.mc_decision_invalid
           "input is not a JSON object: mathc validate expects a top-level \
            mapping (YAML or JSON); got a scalar/array/null")

and parse_decision v =
  match parse_decision_value v with
  | Accept _ -> None
  | Reject diag -> Some diag

(* peek_schema_family: dispatch helper for `mathc validate`.
   The decision parser (`parse_decision_value` above) enforces the
   decision-required fields (intent, commitment, scope, outcomes,
   obligations). Two other schema families live under `decisions/`:
   `math-coding/waiver-<X>` (waivers in `decisions/waivers/`) and
   `math-coding/obligations-<X>` (the obligations aggregator at
   `decisions/obligations.yaml`). Both fail the decision required-
   field check today with `MC-DECISION-INVALID: missing required
   field: <id|intent>` even though they are well-formed for their
   own schema family.

   This helper peeks at the top-level `schema:` field of an already-
   parsed Jsonl.value and returns `Some (kind, id)` when the
   schema family is a recognised non-decision family. The CLI
   (bin/Mathc.ml::validate_with_counts) takes the fast path on
   Some and emits `accept:` with a `kind:` annotation; the
   decision parser is not invoked.

   Anything else returns `None` and the caller falls through to
   the decision parser. A missing or unrecognised `schema:` is
   therefore rejected by the decision parser as before — this
   helper does not widen the accept set, only narrows the reject
   set for the two known non-decision families.

   For waivers: the helper verifies `kind: waiver` is present
   (the schema in `schemas/waiver.json:12` constrains it to a
   constant). The id is read from the top-level `id:` field.

   For obligations aggregators: the helper does NOT require a
   `kind:` field (the obligations aggregator carries none; see
   `decisions/obligations.yaml:1-3`). The id is read from
   `decision.id:` (the aggregator's reference to its parent
   decision). If the parent decision id is missing, the id is
   the empty string — the verdict is still `accept` per the
   permissive policy for this family.

   The dispatch is consulted BEFORE the decision required-field
   check in `bin/Mathc.ml::validate_with_counts`. The list of
   recognised decision schema families is the same as the
   `schema:` enum in `schemas/decision.json` (3.0-alpha, 3.2,
   3.3 — both `/decision` and bare forms). All of those fall
   through to the decision parser unchanged. *)
type non_decision_kind = Waiver | Obligations | Attestation

let[@warning "-32"] peek_schema_family (v : Jsonl.value) :
    (non_decision_kind * string) option =
  let has_prefix ~prefix s =
    let pl = String.length prefix in
    String.length s >= pl && String.sub s 0 pl = prefix
  in
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "schema" with
      | Some s when has_prefix ~prefix:"math-coding/waiver-" s -> (
          match Schema.take_string ps "kind" with
          | Some k when k = "waiver" ->
              let id =
                match Schema.take_string ps "id" with Some i -> i | None -> ""
              in
              Some (Waiver, id)
          | _ -> None)
      | Some s when has_prefix ~prefix:"math-coding/obligations-" s ->
          let id =
            match Schema.take_object ps "decision" with
            | Some dps -> (
                match Schema.take_string dps "id" with
                | Some i -> i
                | None -> "")
            | None -> ""
          in
          Some (Obligations, id)
      | Some s when has_prefix ~prefix:"math-coding/attestation-" s -> (
          match Schema.take_string ps "id" with
          | Some s -> Some (Attestation, s)
          | None -> Some (Attestation, ""))
      | _ -> None)
  | _ -> None

(* --- axiom-link inference (C2 of plan-2026-10-adoption-fixes) ---
 *
 * `infer_axiom_candidates` maps a decision's `scope.paths` to the
 * top-3 most-likely axiom IDs based on a small, opinionated
 * inference table. The mapping is SUGGEST-ONLY: the caller
 * (`lib/new_decision/new_decision.ml`) uses the result to emit a
 * soft-warn that names the candidates; the `axiom_link` field is
 * NEVER auto-filled. The author retains full control over the
 * final axiom choice.
 *
 * Table (from `plan-2026-10-adoption-fixes-2026-10.yaml` §4 C2):
 *
 *     lib/**         → A0, A1
 *     tests/**       → A1
 *     decisions/**   → A0, A4
 *     spec/**        → A0, A3
 *     (fallback)     → A0
 *
 * A path "matches" a rule when it starts with the rule's prefix
 * (case-sensitive; no glob expansion). When multiple rules match,
 * the result is the deduplicated union of their axiom lists,
 * preserving first-occurrence order, capped at 3 entries.
 *
 * Fallback semantics: when no rule matches AND `paths` is empty,
 * the result is `["A0"]` (the universal fallback). When no rule
 * matches but `paths` is non-empty (e.g. `["random.txt"]`), the
 * result is also `["A0"]` — the function's contract is "always
 * return at least one candidate" so the soft-warn always has
 * something to suggest.
 *
 * Cognitive-load motivation (from
 * `docs/experiments/adoption-2026-10.md` §11.3): 5/5 T1 sessions
 * asked which axiom to attach; `A0` is right for "separation"
 * (a distinct kind exists), `A4` is right for "care" (a human
 * owner is required). The mapping is unclear from the README;
 * agents guessed. Inference makes the guess explicit and lets
 * the author override it.
 *
 * Pure function: no I/O, no state. Tested directly in
 * `tests/cli/new-decision-axiom-warn.t` via the
 * `MATH_CODING_NEW_DECISION_SCOPE_PATHS` env-var override on
 * `mathc new-decision`. *)
let[@warning "-32"] infer_axiom_candidates (paths : string list) : string list =
  let[@warning "-32"] starts_with ~prefix s =
    let pl = String.length prefix in
    String.length s >= pl && String.sub s 0 pl = prefix
  in
  let rules =
    [
      ("lib/", [ "A0"; "A1" ]);
      ("tests/", [ "A1" ]);
      ("decisions/", [ "A0"; "A4" ]);
      ("spec/", [ "A0"; "A3" ]);
    ]
  in
  let matched_axioms =
    List.concat_map
      (fun (prefix, axs) ->
        if List.exists (fun p -> starts_with ~prefix p) paths then axs else [])
      rules
  in
  let[@warning "-32"] rec dedup = function
    | [] -> []
    | x :: rest -> x :: dedup (List.filter (fun y -> y <> x) rest)
  in
  let deduped = dedup matched_axioms in
  let[@warning "-32"] rec take n = function
    | [] -> []
    | _ :: _ when n <= 0 -> []
    | x :: rest -> x :: take (n - 1) rest
  in
  let top = take 3 deduped in
  match top with [] -> [ "A0" ] | _ -> top

(* `axiom_candidate_pretty` — format an axiom ID with its
 * short label from `axioms/*.md` headers, so the soft-warn
 * reads as "A0 (separation)" rather than "A0". Labels are
 * derived from the axioms/index.md table-of-contents; the
 * `axiom_label` helper below owns the literal mapping so
 * adding a new axiom is a one-line change. *)
let[@warning "-32"] axiom_label = function
  | "A0" -> "separation"
  | "A1" -> "feedback"
  | "A2" -> "invariants-recovery"
  | "A3" -> "self-application"
  | "A4" -> "care"
  | other -> other

let[@warning "-32"] axiom_candidate_pretty (ax : string) : string =
  Printf.sprintf "%s (%s)" ax (axiom_label ax)

let[@warning "-32"] axiom_candidates_pretty (axs : string list) : string =
  String.concat ", " (List.map axiom_candidate_pretty axs)
