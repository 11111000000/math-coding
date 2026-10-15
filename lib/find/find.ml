(* lib/find/find.ml — keyword / obligation-id search across the
 * decisions corpus.
 *
 * Pure module. Operates on Jsonl.value trees produced by
 * `mathc packages --format=json` (see lib/packages.ml::to_json)
 * or on any structurally-equivalent tree the caller builds.
 * No I/O: the caller reads/writes the JSON; this module only
 * filters and reshapes.
 *
 * The expected input shape (per lib/packages.ml:452-462):
 *
 *   { "as_of": <iso>,
 *     "counts": <counts>,
 *     "decisions": [ { "decision_id": <s>,
 *                      "decision_revision": <s|null>,
 *                      "obligations": [ { "id": <s>,
 *                                         "verifier": <s>,
 *                                         "verdict": <s>,
 *                                         "remedies": [<s>...],
 *                                         "attestation_id": <s|null>,
 *                                         "attestation_expires": <s|null> },
 *                                       ... ] },
 *                    ... ],
 *     "policy_id": <s>,
 *     "source": <s> }
 *
 * Fields the kernel intentionally OMITS from this shape (to keep
 * the package-list payload bounded, per lib/packages.ml:443-448):
 *
 *   - decision.intent
 *   - decision.commitment
 *   - obligation.claim
 *
 * `search` is written to be tolerant: any *additional* string
 * field on each decision or obligation is also scanned. A caller
 * that wants to match against `intent` / `commitment` / `claim`
 * can inject them into a synthetic decision record before calling
 * `search`; the field names are documented below as
 * `extended_intent_field`, `extended_commitment_field`,
 * `extended_claim_field` for clarity.
 *
 * The same lower-case substring rule applies in all cases:
 * the keyword is normalised via `String.lowercase_ascii`
 * before comparison, so matches are case-insensitive but
 * the output preserves the input casing. *)

(* Extended field names. The kernel-side JSON output does NOT
 * include these; callers that want `intent`/`commitment`/`claim`
 * matching can build a richer Jsonl.value with these keys on
 * each decision / obligation. *)
let extended_intent_field = "intent"
let extended_commitment_field = "commitment"
let extended_claim_field = "claim"

(* --- small Jsonl helpers (mirrors lib/jsonl.ml + lib/schema.ml) --- *)

let string_of (v : Jsonl.value) : string option =
  match v with
  | Jsonl.String s -> Some s
  | Jsonl.Int i -> Some (string_of_int i)
  | _ -> None

let fields_of (v : Jsonl.value) : (string * Jsonl.value) list =
  match v with Jsonl.Object ps -> ps | _ -> []

let array_items (v : Jsonl.value) : Jsonl.value list =
  match v with Jsonl.Array xs -> xs | _ -> []

let find_string_field (obj : (string * Jsonl.value) list) (k : string) :
    string option =
  match List.assoc_opt k obj with Some v -> string_of v | None -> None

let has_string_field obj k needle =
  match find_string_field obj k with
  | Some s ->
      let sl = String.lowercase_ascii s in
      let nl = String.lowercase_ascii needle in
      let len_nl = String.length nl in
      let len_sl = String.length sl in
      if len_nl = 0 then true
      else if len_nl > len_sl then false
      else
        let rec scan i =
          if i + len_nl > len_sl then false
          else if String.sub sl i len_nl = nl then true
          else scan (i + 1)
        in
        scan 0
  | None -> false

let find_obj_field obj k =
  match List.assoc_opt k obj with
  | Some (Jsonl.Object _ as v) -> v
  | _ -> Jsonl.Object []

let find_array_field obj k =
  match List.assoc_opt k obj with
  | Some (Jsonl.Array _ as v) -> v
  | _ -> Jsonl.Array []

(* --- search --- *)

(* Return true iff any of the decision-level string fields
 * (and any obligation's string fields, including the
 * extended `intent` / `commitment` / `claim` if present) contain
 * `needle` as a case-insensitive substring. *)
let decision_matches (needle : string) (decision : Jsonl.value) : bool =
  let obj = fields_of decision in
  let fields_to_check =
    [ "decision_id"; extended_intent_field; extended_commitment_field ]
  in
  let decision_level_match =
    List.exists (fun k -> has_string_field obj k needle) fields_to_check
  in
  if decision_level_match then true
  else
    let obligations = array_items (find_array_field obj "obligations") in
    List.exists
      (fun ob ->
        let oo = fields_of ob in
        let fields = [ "id"; "verifier"; "claim" ] in
        List.exists (fun k -> has_string_field oo k needle) fields)
      obligations

(* --- top-level shape manipulation --- *)

let decisions_of (packages : Jsonl.value) : Jsonl.value list =
  match packages with
  | Jsonl.Object ps -> (
      match List.assoc_opt "decisions" ps with
      | Some (Jsonl.Array xs) -> xs
      | _ -> [])
  | _ -> []

let replace_decisions (packages : Jsonl.value)
    (new_decisions : Jsonl.value list) : Jsonl.value =
  match packages with
  | Jsonl.Object ps ->
      let new_ps =
        List.map
          (fun (k, v) ->
            if k = "decisions" then (k, Jsonl.Array new_decisions) else (k, v))
          ps
      in
      Jsonl.Object new_ps
  | _ -> packages

(* --- public API --- *)

(* Filter the `decisions[]` array of `packages` to those whose
   decision-level or obligation-level fields contain `needle`
   as a case-insensitive substring. Returns a Jsonl.value with
   the same shape as the input (the surrounding `as_of`,
   `counts`, `policy_id`, `source` are preserved verbatim). *)
let search ~keyword (packages : Jsonl.value) : Jsonl.value =
  let ds = decisions_of packages in
  let keep = List.filter (fun d -> decision_matches keyword d) ds in
  replace_decisions packages keep

(* Find the decision that owns `obligation_id` (i.e. the decision
   whose `obligations[]` contains an entry with `id == obligation_id`).
   Returns the matched decision as a single-element array on the
   `decisions` key, or an empty `decisions` array if no match.
   The matched obligation is enriched with an `attestation_path`
   field naming the conventional attestation file path
   (`attestations/<decision-id>-<obligation-id>.json`) so the
   caller can locate the evidence. *)
let lookup_obligation ~obligation_id (packages : Jsonl.value) : Jsonl.value =
  let ds = decisions_of packages in
  let matched =
    List.filter
      (fun d ->
        let obj = fields_of d in
        let did =
          match find_string_field obj "decision_id" with
          | Some s -> s
          | None -> ""
        in
        let obligations = array_items (find_array_field obj "obligations") in
        List.exists
          (fun ob ->
            match find_string_field (fields_of ob) "id" with
            | Some id -> id = obligation_id
            | None -> false)
          obligations
        && did <> "")
      ds
  in
  (* Attach attestation_path to each matched obligation so the
     agent that lands here has the canonical evidence path. *)
  let enriched =
    List.map
      (fun d ->
        let obj = fields_of d in
        let did =
          match find_string_field obj "decision_id" with
          | Some s -> s
          | None -> ""
        in
        let obligations = array_items (find_array_field obj "obligations") in
        let enriched_obs =
          List.map
            (fun ob ->
              let oo = fields_of ob in
              let oid =
                match find_string_field oo "id" with Some s -> s | None -> ""
              in
              if oid = obligation_id then
                let att_path =
                  Printf.sprintf "attestations/%s-%s.json" did oid
                in
                Jsonl.Object
                  (oo @ [ ("attestation_path", Jsonl.String att_path) ])
              else ob)
            obligations
        in
        Jsonl.Object (obj @ [ ("obligations", Jsonl.Array enriched_obs) ]))
      matched
  in
  replace_decisions packages enriched
