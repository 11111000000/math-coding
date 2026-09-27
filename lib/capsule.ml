(* lib/capsule.ml — pure builder for the LLM context capsule.
 *
 * A `Capsule.t` is a priority-ordered list of items plus the
 * total bytes used and a list of omitted references. Priorities
 * follow spec/semantics.md "context-prioritisation" and
 * OCAML_BEST_PRACTICES.md §10.4:
 *
 *   RequiredForGate > Changed > HighRisk > Unresolved > Supporting > Historical
 *
 * Pure module (OCAML_BEST_PRACTICES §1.3). `build_capsule` reads
 * the Memory.t snapshot and applies the priority budget. It does
 * NOT read files directly; everything it needs is already in
 * Memory.t (populated by bin/ via Memory.load_memory). *)

type priority =
  | RequiredForGate
  | Changed
  | HighRisk
  | Unresolved
  | Supporting
  | Historical

let[@warning "-32"] priority_rank = function
  | RequiredForGate -> 0
  | Changed -> 1
  | HighRisk -> 2
  | Unresolved -> 3
  | Supporting -> 4
  | Historical -> 5

let[@warning "-32"] priority_name = function
  | RequiredForGate -> "RequiredForGate"
  | Changed -> "Changed"
  | HighRisk -> "HighRisk"
  | Unresolved -> "Unresolved"
  | Supporting -> "Supporting"
  | Historical -> "Historical"

type item = {
  kind : priority;
  summary : string;
  detail_ref : string;
  freshness : string option;
}

type reference = {
  kind : priority;
  summary : string;
  detail_ref : string;
  expansion : string;
}

type t = {
  items : item list;
  total_bytes : int;
  truncated : bool;
  omitted : reference list;
  now : string;
  base : string;
  head : string;
}

(* --- helpers --- *)

let[@warning "-32"] truncate s n =
  let len = String.length s in
  if len <= n then s
  else
    let half = n / 2 in
    let prefix = String.sub s 0 half in
    let suffix = String.sub s (len - (n - half)) (n - half) in
    prefix ^ " ... [truncated] ... " ^ suffix

(* `make_item` is the only place where an item's byte cost is
   shaped. Each item's byte cost is the byte-length of its summary
   plus a fixed framing overhead. The framing overhead is
   intentionally generous (96 bytes) so the JSON object containing
   the item (priority, summary, detail_ref, freshness, comma,
   whitespace, indentation) does not blow the budget silently. *)
let framing_overhead = 96

let[@warning "-32"] item_bytes (it : item) : int =
  String.length it.summary + framing_overhead

let[@warning "-32"] make_item ?freshness kind summary detail_ref =
  { kind; summary; detail_ref; freshness }

let[@warning "-32"] expansion_command detail_ref = "mc explain " ^ detail_ref

(* --- change / commit summarisation --- *)

(* Pick the first non-blank line of `s` to use as a summary. *)
let[@warning "-32"] first_line s =
  let len = String.length s in
  let rec find_eol i =
    if i >= len || String.unsafe_get s i = '\n' then i else find_eol (i + 1)
  in
  let j = find_eol 0 in
  let line = String.sub s 0 j in
  let line =
    let rec rtrim i =
      if i <= 0 then i
      else
        let c = String.unsafe_get line (i - 1) in
        if c = ' ' || c = '\t' || c = '\r' then rtrim (i - 1) else i
    in
    String.sub line 0 (rtrim (String.length line))
  in
  line

(* Truncate the head + tail of a long document so the summary is
   bounded but still informative. *)
let[@warning "-32"] doc_excerpt s = truncate s 800

(* --- priority classification --- *)

(* A path is "Changed" priority iff it appears in the changed-paths
   list. The list comes from `git diff BASE..HEAD --name-only`, so
   for a typical main..HEAD range it is small. *)
let[@warning "-32"] path_is_changed mem p = List.mem p mem.Memory.changed_paths

(* The active policy id. Per spec/semantics.md "context-prioritisation"
   the active policy MUST always be classified as RequiredForGate.
   The kernel currently has no first-class concept of "active
   policy"; by convention the active policy is the bootstrap
   decision (`bootstrap-v3`). Callers may override via the
   `~active_policy_id` argument to `build_capsule`. The default
   preserves the existing behaviour for callers that do not care. *)
let[@warning "-32"] default_active_policy_id = "bootstrap-v3"

(* Decisions: the active policy is RequiredForGate; a Changed
   decision file (modified between BASE and HEAD) is Changed; a
   decision with declared_triggers is HighRisk; otherwise
   Supporting. *)
let[@warning "-32"] classify_decision ~active_policy_id mem entry source_path =
  if entry.Memory.decision_id = active_policy_id then RequiredForGate
  else if path_is_changed mem source_path then Changed
  else if entry.Memory.risk_triggers <> [] then HighRisk
  else Supporting

let[@warning "-32"] classify_spec mem path =
  if path_is_changed mem path then Changed else Supporting

(* Axioms are usually stable across releases; classify them as
   Historical unless they actually changed in this revision. *)
let[@warning "-32"] classify_axiom mem path =
  if path_is_changed mem path then Changed else Historical

(* --- build --- *)

(* Helper: classify the changes between BASE and HEAD. We surface
   the commit log as a single Changed item, then mark the path-level
   Changed items for any decision file in the diff. *)
let[@warning "-32"] build_change_items mem =
  let commit_item =
    let commits = mem.Memory.recent_commits in
    let summary =
      let subjects =
        List.map (fun c -> c.Memory.sha ^ " " ^ c.Memory.subject) commits
      in
      let text = String.concat "\n  " subjects in
      truncate text 1500
    in
    make_item Changed summary
      ("commits:" ^ match commits with c :: _ -> c.Memory.sha | [] -> "none")
  in
  let path_items =
    List.map
      (fun p -> make_item Changed ("changed path: " ^ p) ("path:" ^ p))
      mem.Memory.changed_paths
  in
  commit_item :: path_items

let[@warning "-32"] build_decision_items ~active_policy_id mem =
  List.map
    (fun entry ->
      let source_path =
        match entry.Memory.decision_id with
        | "bootstrap-v3" -> "bootstrap/decision.yaml"
        | "infrastructure-honesty" -> "bootstrap/infrastructure-honesty.yaml"
        | "kernel-conformance-runner" ->
            "bootstrap/kernel-conformance-runner.yaml"
        | "validate-and-context" -> "bootstrap/validate-and-context.yaml"
        | _ -> "bootstrap/" ^ entry.Memory.decision_id ^ ".yaml"
      in
      let kind = classify_decision ~active_policy_id mem entry source_path in
      let summary =
        Printf.sprintf "%s@%s: %d obligations, %d assumptions, %d triggers"
          entry.Memory.decision_id
          (match entry.Memory.revision with Some r -> r | None -> "?")
          entry.Memory.obligations entry.Memory.assumptions
          (List.length entry.Memory.risk_triggers)
      in
      make_item kind summary ("decision:" ^ entry.Memory.decision_id))
    mem.Memory.decisions

let[@warning "-32"] build_spec_items (mem : Memory.t) =
  let spec : Memory.spec_doc list = mem.Memory.spec in
  List.map
    (fun (s : Memory.spec_doc) ->
      let base = Filename.basename s.Memory.path in
      make_item
        (classify_spec mem s.Memory.path)
        (base ^ ": " ^ first_line s.Memory.body)
        ("spec:" ^ base))
    spec

let[@warning "-32"] build_axiom_items (mem : Memory.t) =
  let axioms : Memory.axiom_doc list = mem.Memory.axioms in
  List.map
    (fun (a : Memory.axiom_doc) ->
      let base = Filename.basename a.Memory.path in
      make_item
        (classify_axiom mem a.Memory.path)
        (base ^ ": " ^ first_line a.Memory.body)
        ("axiom:" ^ base))
    axioms

let[@warning "-32"] build_best_practices_item mem =
  match mem.Memory.best_practices with
  | None -> []
  | Some body ->
      [
        make_item Supporting
          ("OCAML_BEST_PRACTICES.md: " ^ first_line body)
          "doc:OCAML_BEST_PRACTICES";
      ]

(* Sort by priority rank, stable on input order. *)
let[@warning "-32"] sort_items (items : item list) : item list =
  let cmp (a : item) (b : item) =
    compare (priority_rank a.kind) (priority_rank b.kind)
  in
  List.stable_sort cmp items

(* Top-level builder. *)
let[@warning "-32"] build_capsule ~now ~base ~head ~memory ~budget_bytes
    ~active_policy_id =
  let raw_items =
    build_change_items memory
    @ build_decision_items ~active_policy_id memory
    @ build_spec_items memory @ build_axiom_items memory
    @ build_best_practices_item memory
  in
  let sorted = sort_items raw_items in
  let rec pack (acc : item list) budget (xs : item list) :
      item list * item list * int =
    match xs with
    | [] -> (List.rev acc, [], budget)
    | (it : item) :: rest ->
        let cost = item_bytes it in
        if cost <= budget then pack (it :: acc) (budget - cost) rest
        else (List.rev acc, it :: rest, budget)
  in
  let kept, dropped, leftover = pack [] budget_bytes sorted in
  let omitted : reference list =
    List.map
      (fun (it : item) ->
        {
          kind = it.kind;
          summary = it.summary;
          detail_ref = it.detail_ref;
          expansion = expansion_command it.detail_ref;
        })
      dropped
  in
  {
    items = kept;
    total_bytes = budget_bytes - leftover;
    truncated = dropped <> [];
    omitted;
    now;
    base;
    head;
  }
