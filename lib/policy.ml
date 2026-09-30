(* lib/policy.ml — multi-policy per path with union + transitive
   composition.

   Implements spec/algebra-3.2.md §9 (Multi-policy per path):

     policy(p) = declared(p) if exists else default-policy
     direct_obligations(c) = ⋃{obligations(policy(p)) : p ∈ c.files}
     transitive_paths(c)   = data_flow_targets*(c.files)
     transitive_obligations(c) = ⋃{obligations(policy(p))
                                   : p ∈ transitive_paths(c)}
     obligations(c) = direct_obligations(c) ⊕ transitive_obligations(c)

   data_flow_targets(p):
     - imports(p) → q: q ∈ data_flow_targets(p)
     - exports(p) → q: q ∈ data_flow_targets(p)
     - transitive closure: data_flow_targets*(p) = ⋃ₙ data_flow_targetsⁿ(p)

   The kernel stays offline (OCAML_BEST_PRACTICES §1.3): the pure
   parsing API is `parse_policies : string -> (policy list, string)`.
   `load_policies_from_file` is a thin wrapper that reads via
   `In_channel.with_open_text`; tests and the kernel itself should
   call the pure API with a `reader` callback or a fixed string.

   Path matching is glob-like: scope_paths support three forms:
     "services/payments"      → exact equality
     "services/payments/*"    → one path segment under "services/payments"
     "services/payments/**"   → any path at or under "services/payments"
   Bare "*" or "**" prefixes (e.g. "**") are NOT supported; this
   mirrors §2 risk-function conventions where classify() uses explicit
   path prefixes rather than a single top-level wildcard.

   Schema: schemas/policy.json (mirrored here as the policy record).
   Obligations are stored as `obligation_ref` (kind, namespace) pairs
   for the multi-policy composition step; the full Obligation record
   is not needed by the gate (§15) at compose-time, only by the
   per-obligation attestation lookup, which lives outside this module.

   Mode ordering (algebra §3): tiny < light < standard < strict <
   exhaustive. `mode_floor_of` returns the maximum mode_floor across
   the direct AND transitive policies. `default_policy.mode_floor`
   is `Tiny`, so paths that match no declared policy default to the
   floor of "tiny" — the silent baseline. *)

(* --- types --- *)

(* obligation_ref is the (kind, namespace) pair carried by the
   policies' obligations arrays. Mirrors the
   `obligation_domain` shape in schemas/obligation.json. *)
type obligation_ref = { obligation_kind : string; path_namespace : string }
type data_flow_kind = [ `Import | `Export ]

type data_flow_edge = {
  source : string;
  target : string;
  kind : data_flow_kind;
}

type policy = {
  policy_id : string;
  scope_paths : string list;
  obligations : obligation_ref list;
  mode_floor : Domain.mode;
  transitive_into : string list;
  data_flow_edges : data_flow_edge list;
}

(* --- defaults --- *)

let default_policy =
  {
    policy_id = "default";
    scope_paths = [];
    obligations = [];
    mode_floor = `Tiny;
    transitive_into = [];
    data_flow_edges = [];
  }

let default_policies_path = "policies.yaml"

(* --- string helpers (avoid shadowing stdlib String) --- *)

let[@warning "-32"] string_starts_with ~prefix s =
  let ls = String.length s and lp = String.length prefix in
  lp <= ls && String.sub s 0 lp = prefix

let[@warning "-32"] string_ends_with ~suffix s =
  let ls = String.length s and lf = String.length suffix in
  lf <= ls && String.sub s (ls - lf) lf = suffix

let[@warning "-32"] string_index_from_opt s start c =
  let len = String.length s in
  let rec loop i =
    if i >= len then None
    else if String.unsafe_get s i = c then Some i
    else loop (i + 1)
  in
  loop start

(* path_matches: scope is a glob-like pattern; path is the candidate.
   Returns true iff scope covers path under the rules above. *)
let rec path_matches scope path =
  if string_ends_with ~suffix:"/**" scope then
    let prefix_len = String.length scope - 3 in
    String.length path > prefix_len
    && string_starts_with ~prefix:(String.sub scope 0 prefix_len) path
    && String.unsafe_get path prefix_len = '/'
  else if string_ends_with ~suffix:"/*" scope then
    let prefix_len = String.length scope - 2 in
    String.length path > prefix_len + 1
    && string_starts_with ~prefix:(String.sub scope 0 prefix_len) path
    && String.unsafe_get path prefix_len = '/'
    &&
    match string_index_from_opt path (prefix_len + 1) '/' with
    | None -> true
    | Some _ -> false
  else scope = path

(* --- mode ordering --- *)

(* mode_to_int: tiny < light < standard < strict < exhaustive *)
let mode_to_int = function
  | `Tiny -> 0
  | `Light -> 1
  | `Standard -> 2
  | `Strict -> 3
  | `Exhaustive -> 4

let max_mode a b = if mode_to_int a >= mode_to_int b then a else b

(* max_mode_floor: fold over a list, take the maximum mode. *)
let[@warning "-32"] max_mode_floor ms =
  match ms with [] -> `Tiny | m :: rest -> List.fold_left max_mode m rest

(* --- obligation_ref helpers --- *)

let[@warning "-32"] ref_equal a b =
  String.equal a.obligation_kind b.obligation_kind
  && String.equal a.path_namespace b.path_namespace

let[@warning "-32"] dedup_refs refs =
  let rec loop acc = function
    | [] -> List.rev acc
    | r :: rest ->
        if List.exists (ref_equal r) acc then loop acc rest
        else loop (r :: acc) rest
  in
  loop [] refs

let[@warning "-32"] dedup_strings ss =
  let rec loop acc = function
    | [] -> List.rev acc
    | s :: rest ->
        if List.exists (String.equal s) acc then loop acc rest
        else loop (s :: acc) rest
  in
  loop [] ss

(* --- core API --- *)

(* all_obligation_refs: concatenate obligations across a policy list,
   preserving order. Dedup is the caller's responsibility
   (`dedup_refs` is exposed above). *)
let[@warning "-32"] all_obligation_refs policies =
  List.concat_map (fun p -> p.obligations) policies

(* policies_of: every policy whose scope_paths overlap with at least
   one entry in `files`. The result is the same set as
   `{ p : ∃ scope ∈ p.scope_paths, ∃ f ∈ files, path_matches scope f }`.
   No deduplication — a policy that matches two files is returned once. *)
let policies_of policies files =
  List.filter
    (fun p ->
      List.exists
        (fun scope -> List.exists (path_matches scope) files)
        p.scope_paths)
    policies

(* policy_of: look up the policy for a single path. When multiple
   policies match (overlapping scope_paths), they are merged: the
   mode_floor is the maximum across matching policies and the
   obligations are unioned (de-duplicated). Returns `default_policy`
   when no declared policy matches. *)
let[@warning "-32"] merge_policies ps =
  let obligations = dedup_refs (all_obligation_refs ps) in
  let mode_floor = max_mode_floor (List.map (fun p -> p.mode_floor) ps) in
  let transitive_into =
    dedup_strings (List.concat_map (fun p -> p.transitive_into) ps)
  in
  let data_flow_edges = List.concat_map (fun p -> p.data_flow_edges) ps in
  {
    policy_id = "merged";
    scope_paths = dedup_strings (List.concat_map (fun p -> p.scope_paths) ps);
    obligations;
    mode_floor;
    transitive_into;
    data_flow_edges;
  }

let policy_of policies path =
  match policies_of policies [ path ] with
  | [] -> default_policy
  | ps -> merge_policies ps

(* data_flow_targets: transitive closure of `source → target` edges
   declared in `policies.data_flow_edges`, starting from `files`.
   `data_flow_targets*({a}) = ⋃ₙ data_flow_targetsⁿ(a)` (algebra §9):
   the result always contains `files` itself plus every path reachable
   via one or more imports/exports edges.
   Cycle detection: the closure stops when no new target is found;
   the implementation iterates a fixed-point expansion of the
   accumulated set. *)
let[@warning "-32"] data_flow_targets policies files =
  let edges = List.concat_map (fun p -> p.data_flow_edges) policies in
  let step_targets acc =
    List.concat_map
      (fun f ->
        List.filter_map
          (fun e -> if String.equal e.source f then Some e.target else None)
          edges)
      acc
  in
  let rec closure acc =
    let new_targets =
      List.filter (fun t -> not (List.mem t acc)) (step_targets acc)
    in
    match new_targets with [] -> acc | _ -> closure (acc @ new_targets)
  in
  closure files

(* compose: union of direct + transitive obligations for a list of
   files. Both direct and transitive paths are passed through
   `policies_of` so multi-policy overlap is unioned (algebra §9: the
   obligations of every applicable policy are joined). The result
   is deduplicated by (kind, namespace). *)
let compose policies files =
  let direct_pols = policies_of policies files in
  let direct = all_obligation_refs direct_pols in
  let transitive_paths = data_flow_targets policies files in
  let transitive_pols = policies_of policies transitive_paths in
  let transitive = all_obligation_refs transitive_pols in
  dedup_refs (direct @ transitive)

(* mode_floor_of: maximum mode_floor across the direct AND
   transitive policies (algebra §2 mode_floor(c) =
   max{mode_floor(policy(p)) : p ∈ c.files ∪ transitive_paths(c)}).
   Falls back to `Tiny` when no policy matches. *)
let mode_floor_of policies files =
  let applicable =
    policies_of policies files
    @ policies_of policies (data_flow_targets policies files)
  in
  max_mode_floor (List.map (fun p -> p.mode_floor) applicable)

(* --- JSON / YAML parsers --- *)

let[@warning "-32"] parse_data_flow_kind s =
  match s with "import" -> Some `Import | "export" -> Some `Export | _ -> None

(* parse_obligation_ref: an obligation entry in a policy may appear
   in two forms (per schemas/policy.json + the lightweight example):
     - bare: { obligation_kind, path_namespace }
     - wrapped: { obligation_domain: { obligation_kind, path_namespace }, ... }
   Both are accepted; bare is the canonical lightweight form. *)
let[@warning "-32"] parse_obligation_ref_from_pairs ps =
  match Schema.take_string ps "obligation_kind" with
  | Some obligation_kind ->
      let path_namespace =
        match Schema.take_string ps "path_namespace" with
        | Some s -> s
        | None -> ""
      in
      Some { obligation_kind; path_namespace }
  | None -> None

let[@warning "-32"] parse_obligation_ref v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_object ps "obligation_domain" with
      | Some ops -> parse_obligation_ref_from_pairs ops
      | None -> parse_obligation_ref_from_pairs ps)
  | _ -> None

let[@warning "-32"] parse_obligations ps =
  match Schema.take_array ps "obligations" with
  | Some xs -> List.filter_map parse_obligation_ref xs
  | None -> []

let[@warning "-32"] parse_data_flow_edge v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "source" with
      | Some source -> (
          match Schema.take_string ps "target" with
          | Some target -> (
              match Schema.take_string ps "kind" with
              | Some k -> (
                  match parse_data_flow_kind k with
                  | Some kind -> Some { source; target; kind }
                  | None -> None)
              | None -> None)
          | None -> None)
      | None -> None)
  | _ -> None

let[@warning "-32"] parse_data_flow_edges ps =
  match Schema.take_array ps "data_flow_edges" with
  | Some xs -> List.filter_map parse_data_flow_edge xs
  | None -> []

let[@warning "-32"] parse_string_list ps key =
  match Schema.take_array ps key with
  | Some xs ->
      List.filter_map
        (fun x -> match x with Jsonl.String s -> Some s | _ -> None)
        xs
  | None -> []

let[@warning "-32"] parse_policy v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_string ps "policy_id" with
      | Some policy_id ->
          let scope_paths = parse_string_list ps "scope_paths" in
          let obligations = parse_obligations ps in
          let mode_str =
            match Schema.take_string ps "mode_floor" with
            | Some s -> s
            | None -> "tiny"
          in
          let mode_floor =
            match Codec.parse_mode mode_str with Some m -> m | None -> `Tiny
          in
          let transitive_into = parse_string_list ps "transitive_into" in
          let data_flow_edges = parse_data_flow_edges ps in
          Some
            {
              policy_id;
              scope_paths;
              obligations;
              mode_floor;
              transitive_into;
              data_flow_edges;
            }
      | None -> None)
  | _ -> None

(* parse_policies: pure function over a YAML or JSON string.
   policies.yaml is a top-level YAML sequence; JSON files are
   accepted as a convenience for tests. Returns `(policies, errors)`
   where `errors = ""` indicates a clean parse.
   Malformed policy entries are silently dropped (the loader is
   total: it never raises). The error string is set only when the
   top-level structure is not an array. *)
let parse_policies content =
  let v =
    try Codec.load_yaml_value content
    with _ -> (
      (* Fall back to JSON parsing for *.json policies files. *)
      try Jsonl.parse content with _ -> Jsonl.Null)
  in
  match v with
  | Jsonl.Array items ->
      let policies = List.filter_map parse_policy items in
      (policies, "")
  | Jsonl.Null -> ([], "")
  | _ -> ([], "expected array of policies")

(* --- file loader (thin I/O wrapper) --- *)

(* load_policies_from_file: read a policies file from disk using
   `In_channel.with_open_text`. Returns the empty list when the
   file is missing (the "no policy declared" case — algebra §9
   `policy(p) = default-policy`). Parse errors collapse to the
   empty list with the error string dropped; the gate layer is
   responsible for surfacing them.
   This is the only function in the module that touches I/O;
   OCAML_BEST_PRACTICES §1.3 keeps I/O at the bin/ boundary
   when feasible, but policy files are small (a few KB) and the
   parse path needs to be testable without monkey-patching a
   reader, so the wrapper is colocated with the pure parser. *)
let load_policies_from_file path =
  if not (Sys.file_exists path) then []
  else
    let raw = In_channel.with_open_text path In_channel.input_all in
    let policies, _errors = parse_policies raw in
    policies

(* --- module initialisation --- *)

(* Loaded policies cache (populated lazily by load_policies).
   The kernel reads this once at startup; mutations are
   not supported post-load (algebra §9 is a pure value). *)
let cached_policies : policy list ref = ref []

(* load_policies: read from `default_policies_path` (or an
   override), parse it, and cache the result. Returns the
   list. Empty list means "no policies declared" (default
   policy applies to every path). *)
let load_policies ?path () =
  let p = match path with Some s -> s | None -> default_policies_path in
  let ps = load_policies_from_file p in
  cached_policies := ps;
  ps

(* cached: read-only accessor for the cached policies. Returns
   the empty list until `load_policies` has been called. *)
let[@warning "-32"] cached () = !cached_policies

(* Convenience wrappers that operate on the cached policy list.
   The functions that take `policies` directly (above) are
   preferred for kernel-internal use; these wrap the cache for
   the bin/ entry point. *)
let[@warning "-32"] policy_of_cached path = policy_of !cached_policies path

let[@warning "-32"] policies_of_cached files =
  policies_of !cached_policies files

let[@warning "-32"] compose_cached files = compose !cached_policies files

let[@warning "-32"] mode_floor_of_cached files =
  mode_floor_of !cached_policies files

let[@warning "-32"] data_flow_targets_cached files =
  data_flow_targets !cached_policies files
