(* lib/rebuttal.ml — hybrid rebuttal mechanism (algebra-3.2 §10).
 *
 * Pure module: file I/O is confined to the load functions
 * (`load_rebuttals`); the rest are total transformations.
 *
 * The algebra §10 contract is:
 *
 *   rebuttals(c) = rebuttals_yaml(c) ⊕ forge_mirror(c).comments
 *   rebuttals_yaml(c) ≔ rebuttals/<commit-sha>.yaml if exists
 *   forge_mirror(c) ≔ forge_api.comments_for(commit_sha) if forge
 *                     integrated else ∅
 *
 *   ∀ rebuttal r ∈ rebuttals(c):
 *     r = ⟨rebutter: 𝓐, objection: String, evidence: Evidence,
 *          outcome: pending|accepted|rejected_with_reason|
 *                   ignored_non_binding|never_resolved,
 *          trust_level_at_rebuttal: 𝓣⟩
 *
 *   binding(r) ≔ trust(r.rebutter, obligation_domain(c))
 *                 ≥ authority(c.mode)
 *
 * The forge mirror is not yet wired (no forge integration in this
 * revision; see ROADMAP Tier 3.5 #7). `forge_mirror` returns the
 * empty list and is the seam where `forge_api.comments_for` will
 * be called once the forge adapter lands. *)

(* --- outcome (algebra §10) --- *)

type outcome =
  | Pending
  | Accepted
  | Rejected_with_reason
  | Ignored_non_binding
  | Never_resolved

let[@warning "-32"] outcome_to_string = function
  | Pending -> "pending"
  | Accepted -> "accepted"
  | Rejected_with_reason -> "rejected_with_reason"
  | Ignored_non_binding -> "ignored_non_binding"
  | Never_resolved -> "never_resolved"

let[@warning "-32"] parse_outcome s =
  match String.lowercase_ascii s with
  | "accepted" -> Accepted
  | "rejected_with_reason" -> Rejected_with_reason
  | "ignored_non_binding" -> Ignored_non_binding
  | "never_resolved" -> Never_resolved
  | _ -> Pending

(* --- rebuttal record --- *)

type rebuttal = {
  rebutter : string;
  objection : string;
  evidence : string;
  outcome : outcome;
  trust_level_at_rebuttal : Domain.trust;
  domain : Domain.obligation_domain option;
  binding : bool;
  timestamp : string;
}

(* --- trust helpers (algebra §12) --- *)

let[@warning "-32"] trust_rank = function
  | `Untrusted -> 0
  | `Authenticated -> 1
  | `Delegated -> 2
  | `Authoritative -> 3

(* Authority floor per mode (algebra §10 binding).
   Tiny/Light/Standard accept any authenticated rebutter;
   Strict demands Delegated; Exhaustive demands Authoritative. *)
let[@warning "-32"] authority_required = function
  | `Tiny -> `Authenticated
  | `Light -> `Authenticated
  | `Standard -> `Authenticated
  | `Strict -> `Delegated
  | `Exhaustive -> `Authoritative

(* Parse a string trust value into the polymorphic variant. *)
let[@warning "-32"] parse_trust s =
  match String.lowercase_ascii s with
  | "untrusted" -> `Untrusted
  | "authenticated" -> `Authenticated
  | "delegated" -> `Delegated
  | "authoritative" -> `Authoritative
  | _ -> `Authenticated

(* --- domain sub-parser --- *)

let[@warning "-32"] parse_domain_opt v =
  match v with
  | Some ps ->
      let kind =
        match Schema.take_string ps "obligation_kind" with
        | Some s -> s
        | None -> ""
      in
      let ns =
        match Schema.take_string ps "path_namespace" with
        | Some s -> s
        | None -> ""
      in
      if kind = "" && ns = "" then None
      else Some { Domain.obligation_kind = kind; Domain.path_namespace = ns }
  | None -> None

(* --- JSON object ↔ rebuttal --- *)

(* Re-compute `binding` for a parsed rebuttal at Standard mode.
   Other modes are checked by the gate; this default matches the
   most common admission policy (per §10 standard acceptance). *)
let[@warning "-32"] compute_binding trust domain =
  match domain with
  | None -> false
  | Some _ -> trust_rank trust >= trust_rank (authority_required `Standard)

let[@warning "-32"] parse_rebuttal v =
  match v with
  | Jsonl.Object ps ->
      let get_str key = Schema.take_string ps key in
      let get_obj key = Schema.take_object ps key in
      let rebutter = match get_str "rebutter" with Some s -> s | None -> "" in
      let objection =
        match get_str "objection" with Some s -> s | None -> ""
      in
      let evidence = match get_str "evidence" with Some s -> s | None -> "" in
      let outcome_str =
        match get_str "outcome" with Some s -> s | None -> "pending"
      in
      let trust_str =
        match get_str "trust_level_at_rebuttal" with
        | Some s -> s
        | None -> "authenticated"
      in
      let ts = match get_str "timestamp" with Some s -> s | None -> "" in
      if rebutter = "" then None
      else
        let trust = parse_trust trust_str in
        let domain = parse_domain_opt (get_obj "domain") in
        let binding = compute_binding trust domain in
        Some
          {
            rebutter;
            objection;
            evidence;
            outcome = parse_outcome outcome_str;
            trust_level_at_rebuttal = trust;
            domain;
            binding;
            timestamp = ts;
          }
  | _ -> None

(* Parse a YAML node containing a list of rebuttal records. Each
   item must be a JSON object (produced by Codec.load_yaml_string);
   non-object items are dropped silently. *)
let[@warning "-32"] parse_rebuttals_node v =
  match v with Jsonl.Array xs -> List.filter_map parse_rebuttal xs | _ -> []

let[@warning "-32"] to_json r =
  let domain_pairs =
    match r.domain with
    | Some d ->
        [
          ( "domain",
            Jsonl.Object
              [
                ("obligation_kind", Jsonl.String d.obligation_kind);
                ("path_namespace", Jsonl.String d.path_namespace);
              ] );
        ]
    | None -> []
  in
  let pairs =
    [
      ("rebutter", Jsonl.String r.rebutter);
      ("objection", Jsonl.String r.objection);
      ("evidence", Jsonl.String r.evidence);
      ("outcome", Jsonl.String (outcome_to_string r.outcome));
      ( "trust_level_at_rebuttal",
        Jsonl.String
          (match r.trust_level_at_rebuttal with
          | `Untrusted -> "untrusted"
          | `Authenticated -> "authenticated"
          | `Delegated -> "delegated"
          | `Authoritative -> "authoritative") );
      ("binding", Jsonl.Bool r.binding);
      ("timestamp", Jsonl.String r.timestamp);
    ]
    @ domain_pairs
  in
  Jsonl.Object pairs

(* --- binding check (algebra §10) --- *)

(* is_binding trust domain:
   a rebuttal whose rebutter carries `trust` and whose
   `obligation_domain` is `domain` would bind at Standard mode iff
   the trust rank meets or exceeds the authority floor.
   No domain → no binding (no obligation to rebut). *)
let[@warning "-32"] is_binding trust domain =
  match domain with
  | None -> false
  | Some _ -> trust_rank trust >= trust_rank (authority_required `Standard)

(* --- queries --- *)

(* any_binding: true if at least one rebuttal in `rs` binds for the
   given obligation_domain (per is_binding). Empty domain list →
   false (no binding without an obligation target). *)
let[@warning "-32"] any_binding rs domain =
  List.exists (fun r -> is_binding r.trust_level_at_rebuttal domain) rs

let[@warning "-32"] filter_outcome wanted rs =
  List.filter (fun r -> r.outcome = wanted) rs

(* --- statistics (algebra §12) --- *)

type rebuttal_stats = {
  total : int;
  accepted : int;
  rejected_with_reason : int;
  ignored_non_binding : int;
  never_resolved : int;
  pending : int;
}

let[@warning "-32"] stats rs =
  let bump field = if field then 1 else 0 in
  let[@warning "-32"] loop acc r =
    {
      total = acc.total + 1;
      accepted = acc.accepted + bump (r.outcome = Accepted);
      rejected_with_reason =
        acc.rejected_with_reason + bump (r.outcome = Rejected_with_reason);
      ignored_non_binding =
        acc.ignored_non_binding + bump (r.outcome = Ignored_non_binding);
      never_resolved = acc.never_resolved + bump (r.outcome = Never_resolved);
      pending = acc.pending + bump (r.outcome = Pending);
    }
  in
  List.fold_left loop
    {
      total = 0;
      accepted = 0;
      rejected_with_reason = 0;
      ignored_non_binding = 0;
      never_resolved = 0;
      pending = 0;
    }
    rs

(* --- loaders (file I/O confined here) --- *)

(* rebuttals_path: where to find a sibling rebuttal artifact for a
   commit. Per algebra §10: rebuttals/<commit-sha>.yaml. *)
let rebuttals_path sha = "rebuttals/" ^ sha ^ ".yaml"

(* load_rebuttals: read `rebuttals/<sha>.yaml` if it exists.
   Missing file or parse failure → empty list (algebra §10:
   ∃ rebuttal ∀ c, mode(c) ≥ strict; rebuttal list may be empty).
   All errors are caught at the boundary; this function is total. *)
let[@warning "-32"] load_rebuttals sha =
  let path = rebuttals_path sha in
  if not (Sys.file_exists path) then []
  else
    let content =
      try In_channel.with_open_text path In_channel.input_all with _ -> ""
    in
    if content = "" then []
    else
      let yaml = try Some (Codec.load_yaml_string content) with _ -> None in
      match yaml with
      | Some (Jsonl.Object ps) -> (
          match List.assoc_opt "rebuttals" ps with
          | Some node -> parse_rebuttals_node node
          | None -> [])
      | _ -> []

(* forge_mirror: hybrid rebuttal seam (algebra §10).
   Reads `MATH_CODING_FORGE_API`. When unset or empty, returns
   `[]` (the §10 fallback for an unintegrated forge). When set,
   issues `GET <api>/comments?commit=<sha>` via `curl
   -sS --max-time 5` and parses the JSON array response via
   `Jsonl.parse`. Each element is run through `parse_rebuttal`;
   elements without a `rebutter` field are silently dropped.

   All error paths (env unset, env empty, curl non-zero exit,
   curl timeout, empty body, JSON parse failure, response not
   a top-level array) return `[]`. The hybrid `all_rebuttals`
   is YAML-authoritative: forge failure does NOT raise into the
   gate. This is the meta-decision
   `plan-2026-10-improvements@1` obligation `t1-1-forge-mirror`
   and is closed by the matching sub-decision
   `decisions/plan-2026-10-improvements/t1-1.yaml@1`.

   No new OCaml dependency is introduced (cohttp is
   intentionally NOT pulled in to keep the kernel
   closure-tight per ROADMAP Tier 3.5); the HTTP transport
   uses `curl` invoked through `Unix.open_process_args_in`,
   the same pattern as `bin/Mathc.ml:run_git_command`. *)
let forge_mirror sha =
  match Sys.getenv_opt "MATH_CODING_FORGE_API" with
  | None -> []
  | Some api -> (
      let api_trim = String.trim api in
      if api_trim = "" then []
      else
        let url = api_trim ^ "/comments?commit=" ^ sha in
        let argv = [| "curl"; "-sS"; "--max-time"; "5"; url |] in
        let ic = Unix.open_process_args_in "curl" argv in
        let buf = Buffer.create 4096 in
        (try
           while true do
             Buffer.add_channel buf ic 4096
           done
         with End_of_file -> ());
        let _status = Unix.close_process_in ic in
        let body = Buffer.contents buf in
        if body = "" then []
        else
          try
            match Jsonl.parse body with
            | Jsonl.Array xs -> List.filter_map parse_rebuttal xs
            | _ -> []
          with _ -> [])

(* all_rebuttals: union of sibling YAML and forge mirror.
   The forge mirror is appended after the YAML rebuttals; if the
   forge integration ever returns duplicates, dedup is the
   caller's responsibility (rebuttals carry only the rebutter,
   not a forge-stable id in this revision). *)
let[@warning "-32"] all_rebuttals sha =
  let from_yaml = load_rebuttals sha in
  let from_forge = forge_mirror sha in
  from_yaml @ from_forge
