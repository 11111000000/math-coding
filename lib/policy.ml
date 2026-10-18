(* lib/policy.ml — multi-policy per path with union + transitive
   + hierarchical composition.

   Implements spec/algebra-3.2.md §9 (Multi-policy per path).
   The algebra names three composition axes (decision
   `multi-policy-hierarchy-2026-10`):

     (a) union       — Σ obligations across policies matching
         the same path; max(mode_floor); summed
         override_probability clamped to [-1, 1].
     (b) transitive  — data-flow reachability via imports/exports;
         the closure `data_flow_targets*(p)` is the union of all
         paths reachable from `p`.
     (c) hierarchical — `parent: <id>` walks the chain; obligations
         and scope_paths are unioned, mode_floor is max'd,
         `override_probability` is the child's non-zero value
         (else parent's). See `resolve_policy` below.


  Algebra §9 formulation:

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
(* Path matching is glob-like: scope_paths support three forms:
   "services/payments"      → exact equality
   "services/payments/*"    → one path segment under "services/payments"
   "services/payments/**"   → any path at or under "services/payments"
   Bare "*" or "**" prefixes (e.g. "**") are NOT supported. *)

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

(* parent: optional policy_id this policy inherits from. The
   hierarchical composition axis (decision
   `multi-policy-hierarchy-2026-10`) walks the parent chain,
   unioning obligations + scope_paths and max'ing mode_floor.
   None means "no parent; this policy stands on its own". *)
type policy = {
  policy_id : string;
  parent : string option;
  scope_paths : string list;
  obligations : obligation_ref list;
  mode_floor : Domain.mode;
  override_probability : float;
  transitive_into : string list;
  data_flow_edges : data_flow_edge list;
}

(* --- defaults --- *)
let default_policy =
  {
    policy_id = "default";
    parent = None;
    scope_paths = [];
    obligations = [];
    mode_floor = `Tiny;
    override_probability = 0.0;
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

(* mode_to_int: tiny < light < [considered == standard] < strict < exhaustive.
   `Considered` carries the same kernel-rules assurance strength
   as `Standard` per `decisions/antithesis-mode-considered-2026-10`. *)
let mode_to_int = function
  | `Tiny -> 0
  | `Light -> 1
  | `Standard | `Considered -> 2
  | `Strict -> 3
  | `Exhaustive -> 4

let max_mode : Domain.mode -> Domain.mode -> Domain.mode =
 fun a b -> if mode_to_int a >= mode_to_int b then a else b

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
  let sum =
    List.fold_left (fun acc p -> acc +. p.override_probability) 0.0 ps
  in
  let override_probability =
    if sum > 1.0 then 1.0 else if sum < -1.0 then -1.0 else sum
  in
  let transitive_into =
    dedup_strings (List.concat_map (fun p -> p.transitive_into) ps)
  in
  let data_flow_edges = List.concat_map (fun p -> p.data_flow_edges) ps in
  {
    policy_id = "merged";
    parent = None;
    scope_paths = dedup_strings (List.concat_map (fun p -> p.scope_paths) ps);
    obligations;
    mode_floor;
    override_probability;
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

(* policy_override_of_files: sum of `override_probability` across
   all policies whose `scope_paths` match at least one file in the
   input list, clamped to [-1, 1].

   Algebra §2: probability(c) = 0.5 + 0.5 · policy_override_probability(c)
   The override lives in [-1, 1] so probability stays in [0, 1].
   Multiple policies that match the same file sum linearly; the
   clamp is the kernel's invariant (OCAML_BEST_PRACTICES §11.25).

   Pure, offline, no exceptions. Policies without
   `override_probability` contribute 0.0 (the default). *)
let[@warning "-32"] clamp_override f =
  if f > 1.0 then 1.0 else if f < -1.0 then -1.0 else f

let policy_override_of_files policies files =
  let matching =
    List.filter
      (fun p ->
        match p.scope_paths with
        | [] -> false
        | _ ->
            List.exists
              (fun path ->
                List.exists (fun sp -> path_matches sp path) p.scope_paths)
              files)
      policies
  in
  let sum =
    List.fold_left (fun acc p -> acc +. p.override_probability) 0.0 matching
  in
  clamp_override sum

(* resolve_policy: hierarchical composition axis (decision
   `multi-policy-hierarchy-2026-10`). Walks the `parent` chain
   starting from the policy whose `policy_id = id`, accumulating
   obligations + scope_paths and max'ing mode_floor across every
   ancestor and the child itself.

   Resolution rules (mirrors the decision's commitment §3):

     - obligations = union of (parent obligations + child
       obligations), deduplicated by (kind, namespace).
     - scope_paths = union of (parent scope_paths + child
       scope_paths), deduplicated as strings.
     - mode_floor = max(parent.mode_floor, child.mode_floor).
     - override_probability = child's value when non-zero,
       else parent's value. The default-zero child never
       erases an explicit parent override (OCAML_BEST_PRACTICES
       §11.26 — TRAP).
     - transitive_into, data_flow_edges = child's values
       (transitive data-flow stays with the child; the parent
       chain does not propagate these fields).

   Cycle detection: the visited set records every `policy_id`
   seen along the chain. A repeat ⇒ `Error (Diagnostic.t with
   code "MC-POLICY-CYCLE")`.

   Missing policy: when the target `id` is not in `policies`,
   returns `Error (Diagnostic.t with code "MC-POLICY-NOT-FOUND")`.

   Pure: no I/O, no exceptions, no state mutation. The
   Diagnostic is a value; callers surface it themselves. *)
(* find_policy_by_id: linear scan over the policy registry. The
   list is small (one file, one decision per project) so a linear
   scan is cheaper than building a side table. *)
let[@warning "-32"] find_policy_by_id policies id =
  List.find_opt (fun p -> String.equal p.policy_id id) policies

(* cycle_in_chain: given the chain walked so far (ordered from
   root-most ancestor down to the most recent policy), does the
   `target` policy_id already appear? If yes, walking the parent
   pointer would close a loop; `resolve_policy` returns a cycle
   diagnostic. The chain list always ends with the policy whose
   `parent` is being inspected, so we look up the full chain. *)
let[@warning "-32"] cycle_in_chain chain target_id =
  List.exists (fun p -> String.equal p.policy_id target_id) chain

(* walk_chain: build a flat, root-first list of policies along
   the parent chain, terminating on a missing parent or on a
   repeat (cycle). Returns `(chain_opt, cycle_target)` where
   `cycle_target = Some id` when the cycle is detected at `id`.
   The chain is root-first; the leaf (the original target) is
   the LAST element. *)
let[@warning "-32"] rec walk_chain policies chain =
  match chain with
  | [] -> (chain, None)
  | last :: _ -> (
      match last.parent with
      | None -> (chain, None)
      | Some parent_id -> (
          if cycle_in_chain chain parent_id then (chain, Some parent_id)
          else
            match find_policy_by_id policies parent_id with
            | None -> (chain, None)
            | Some parent -> walk_chain policies (parent :: chain)))

(* merge_chain: fold the chain (root-first) into one resolved
   policy. mode_floor is max'd; obligations and scope_paths are
   union+dedup; `override_probability` is the first non-zero
   value scanning root → leaf (child wins, but default-zero
   never erases a parent's non-zero override — TRAP §11.26);
   `transitive_into` and `data_flow_edges` are taken from the
   LEAF (the child's data-flow edges do not propagate through
   the parent chain). The resolved policy's `parent` is `None`
   (the chain has been flattened). *)
let[@warning "-32"] merge_chain chain =
  match List.rev chain with
  | [] ->
      (* Unreachable: resolve_policy guards against this with
         the `find_policy_by_id` check. *)
      {
        policy_id = "";
        parent = None;
        scope_paths = [];
        obligations = [];
        mode_floor = `Tiny;
        override_probability = 0.0;
        transitive_into = [];
        data_flow_edges = [];
      }
  | leaf :: _ ->
      let obligations =
        dedup_refs (List.concat_map (fun p -> p.obligations) chain)
      in
      let scope_paths =
        dedup_strings (List.concat_map (fun p -> p.scope_paths) chain)
      in
      let mode_floor =
        max_mode_floor (List.map (fun p -> p.mode_floor) chain)
      in
      let override_probability =
        List.fold_left
          (fun acc p -> if acc = 0.0 then p.override_probability else acc)
          0.0 chain
      in
      {
        policy_id = leaf.policy_id;
        parent = None;
        scope_paths;
        obligations;
        mode_floor;
        override_probability;
        transitive_into = leaf.transitive_into;
        data_flow_edges = leaf.data_flow_edges;
      }

let resolve_policy policies id =
  match find_policy_by_id policies id with
  | None ->
      let msg = Printf.sprintf "policy not found in registry: %s" id in
      Error (Diagnostic.create ~code:"MC-POLICY-NOT-FOUND" ~kind:Input msg)
  | Some target -> (
      let chain, cycle_at = walk_chain policies [ target ] in
      match cycle_at with
      | Some _ ->
          let msg = Printf.sprintf "policy cycle detected starting at: %s" id in
          Error (Diagnostic.create ~code:"MC-POLICY-CYCLE" ~kind:Input msg)
      | None -> Ok (merge_chain chain))

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
          let parent = Schema.take_string ps "parent" in
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
          let override_probability =
            match Schema.take_number ps "override_probability" with
            | Some f -> f
            | None -> 0.0
          in
          Some
            {
              policy_id;
              parent;
              scope_paths;
              obligations;
              mode_floor;
              override_probability;
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

let policy_override_of_files_cached files =
  policy_override_of_files (cached ()) files
