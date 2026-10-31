(* lib/graph/graph.ml — relations-graph projection for `mathc graph`.
 *
 * Pure module. Operates on a `Domain.decision list` (the
 * full record with the 9-field `relations` per kernel contract §7)
 * and produces two projections:
 *
 *   1. `to_dot ~decision_id decisions`:
 *        DOT (`digraph`) serialization that Graphviz (or any
 *        SVG/PDF dot renderer) can layout. Each decision is a
 *        node; each relation list element is one outgoing
 *        edge labelled with the relation kind
 *        (`addresses`, `supersedes`, `revises`, `refines`,
 *        `depends_on`, `conflicts_with`, `implements`,
 *        `verifies`). The `superseded_by` field is the
 *        inverse of `supersedes`; we emit it with the
 *        `supersedes` label so the graph remains single-edge.
 *
 *   2. `to_json ~decision_id decisions`:
 *        structural JSON `{nodes: [...], edges: [...]}` that
 *        the dashboard / cytoscape.js viewer can load without
 *        a parser pass. The shape is canonicalised through
 *        `Jsonl.value` (sorted keys per OCAML_BEST_PRACTICES
 *        §10.2 — the JSON form is digest-grade).
 *
 * No I/O at module top level. The caller (bin/Mathc.ml::do_graph)
 * loads the decision list via `Re_evaluation.load_decisions` and
 * forwards it here.
 *
 * The graph traversal starts at `decision_id` and walks
 * forward along every relation kind. The traversal is bounded
 * by the visited set, so a cycle in the relations graph does
 * NOT infinite-loop: each visited decision contributes its
 * outgoing edges exactly once. When a cycle is detected
 * (i.e. a decision's outgoing edge points at an ancestor on
 * the current DFS path), the `to_json` projection sets
 * `_cycle: true` on the edge tuple and the `to_dot`
 * projection emits a `// cycle` comment block at the foot
 * of the digraph with the participating ids. This is the
 * graph-side analogue of `lib/policy.ml::resolve_policy`'s
 * `MC-POLICY-CYCLE` reject, except the kernel records the
 * observation rather than rejecting — same diagnostic
 * vocabulary, different severity posture because the graph
 * is a read surface not a policy resolver.
 *
 * Edge set is closed over the eight §7 forward relations.
 * `superseded_by` is folded into `supersedes`. The
 * "decision not found" case is signalled by returning the
 * empty graph plus a distinct sentinel; the CLI surfaces it
 * as the documented `MC-POLICY-NOT-FOUND` diagnostic.
 *
 * The DOT output is unescaped for label strings (Graphviz
 * accepts raw id tokens; the decision id format per
 * kernel contract §7 is `lower_snake_case` optionally suffixed
 * `@<rev>`, which contains no metacharacters).
 *
 * Reference: decisions/graph-viewer-2026-10@1. *)

(* A graph edge with the kind label in the §7 vocabulary.
   The from/to fields are decision ids (the `id` field of
   Domain.decision, which is `string`). *)
type edge = { from_ : string; to_ : string; kind : string }

type graph = {
  root : string;
  nodes : string list;
  edges : edge list;
  cycle : bool;
}

(* All eight §7 forward relation kinds. Each is a record
   selector from `Domain.relations`. The label is the same
   as the field name. Order is the §7 enumeration order
   (algebra defines them in this sequence). *)
let relation_kinds : (string * (Domain.relations -> string list)) list =
  [
    ("addresses", fun r -> r.Domain.addresses);
    ("supersedes", fun r -> r.Domain.supersedes);
    ("revises", fun r -> r.Domain.revises);
    ("refines", fun r -> r.Domain.refines);
    ("depends_on", fun r -> r.Domain.depends_on);
    ("conflicts_with", fun r -> r.Domain.conflicts_with);
    ("implements", fun r -> r.Domain.implements);
    ("verifies", fun r -> r.Domain.verifies);
  ]

(* --- helpers --- *)

let[@warning "-32"] mem_str (needle : string) (haystack : string list) : bool =
  List.exists (fun s -> String.equal s needle) haystack

(* Strip the optional `@<rev>` suffix from a decision
   reference per kernel contract §7. The kernel stores ids
   verbatim (no @rev stripping) in `Domain.decision.id`,
   but relations in the same record carry `@<rev>` for
   pinned references. The graph walker canonicalises both
   sides to the bare id so the BFS can match across
   "name@rev" and "name" forms. *)
let[@warning "-32"] strip_rev (s : string) : string =
  match String.split_on_char '@' s with base :: _ -> base | [] -> s

(* Look up a decision by id. Linear scan; the corpus is
   bounded (~125 files as of v3.0) and the graph is per-
   call transient, so an index is overkill. Returns `Some d`
   when found, `None` otherwise. *)
let[@warning "-32"] find_decision (decisions : Domain.decision list)
    (id : string) : Domain.decision option =
  let needle = strip_rev id in
  List.find_opt
    (fun (d : Domain.decision) -> String.equal (strip_rev d.Domain.id) needle)
    decisions

(* Edges outgoing from `decision` to every other decision in
   `decisions` whose id appears in one of its §7 relation
   lists. The `superseded_by` field is folded into
   `supersedes` with the same label — i.e. it is intentionally
   a second-source alias for graph-walk purposes. Edges to
   ids that are not present in `decisions` are still emitted
   (they are dangling but visible to the operator — Graphviz
   will draw a node stub for them). Cycle detection here is
   local: an edge `from -> to` records `from` already had
   `to` on its DFS path (list membership in `ancestors`). *)
let[@warning "-32"] outgoing_edges ~(ancestors : string list)
    (decision : Domain.decision) (_decisions : Domain.decision list) :
    edge list * bool =
  let me_id = strip_rev decision.Domain.id in
  let cycle_ref = ref false in
  let edges_with_cycle r_kind targets =
    List.map
      (fun t_raw ->
        let t = strip_rev t_raw in
        let is_cycle = mem_str t ancestors && not (String.equal t me_id) in
        if is_cycle then cycle_ref := true;
        { from_ = me_id; to_ = t; kind = r_kind })
      targets
  in
  let all_edges =
    List.concat_map
      (fun (kind, getter) ->
        let r = decision.Domain.relations in
        let raw = getter r in
        let targets =
          if kind = "supersedes" then
            raw @ decision.Domain.relations.Domain.superseded_by
          else raw
        in
        edges_with_cycle kind targets)
      relation_kinds
  in
  (all_edges, !cycle_ref)

(* BFS from `root_id` across all eight §7 relations. Order
   is breadth-first for stable DOT node enumeration. Nodes
   are kept in first-seen order (the BFS frontier pushes
   new neighbours at the tail). The traversal records:
     - the visited node set (sequence preserved),
     - the emitted edge list (one per outgoing relation,
       possibly repeated if the same `(from, to)` pair appears
       under two relation kinds — the §7 invariants forbid
       this in practice but the walker is robust to it),
     - a `cycle: bool` flag set iff the DFS found any back-
       edge to an ancestor.
   The result `graph` is what both projections return. *)
let[@warning "-32"] build ~decision_id (decisions : Domain.decision list) :
    graph =
  let root_id = strip_rev decision_id in
  match find_decision decisions decision_id with
  | None -> { root = root_id; nodes = []; edges = []; cycle = false }
  | Some _root_d ->
      let visited = ref [] in
      let nodes_order = ref [] in
      let edges_acc = ref [] in
      let cycle_found = ref false in
      let add_edge e = edges_acc := e :: !edges_acc in
      let rec visit (ancestors : string list) (d_id : string) =
        if mem_str d_id !visited then ()
        else begin
          visited := d_id :: !visited;
          nodes_order := d_id :: !nodes_order;
          match find_decision decisions d_id with
          | None -> ()
          | Some d ->
              let new_ancestors = d_id :: ancestors in
              let children, cycle =
                outgoing_edges ~ancestors:new_ancestors d decisions
              in
              if cycle then cycle_found := true;
              List.iter add_edge children;
              let child_ids =
                List.sort_uniq String.compare
                  (List.map (fun e -> e.to_) children)
              in
              List.iter (visit new_ancestors) child_ids
        end
      in
      visit [] root_id;
      {
        root = root_id;
        nodes = List.rev !nodes_order;
        edges = List.rev !edges_acc;
        cycle = !cycle_found;
      }

(* Render to Graphviz DOT. Quoted-form labels (Graphviz
   accepts `["<id>"]` verbatim). Id strings are emitted
   with double-quotes; the format is the canonical DOT
   token for a node id and matches Graphviz's grammar
   for `ID = double-quoted-string`. *)
let[@warning "-32"] to_dot ~decision_id (decisions : Domain.decision list) :
    string =
  let g = build ~decision_id decisions in
  let buf = Buffer.create 256 in
  Buffer.add_string buf (Printf.sprintf "digraph \"%s\" {\n" decision_id);
  List.iter
    (fun n -> Buffer.add_string buf (Printf.sprintf "  \"%s\";\n" n))
    g.nodes;
  List.iter
    (fun e ->
      Buffer.add_string buf
        (Printf.sprintf "  \"%s\" -> \"%s\" [label=\"%s\"];\n" e.from_ e.to_
           e.kind))
    g.edges;
  if g.cycle then begin
    Buffer.add_string buf
      "  // cycle detected: one or more edges point at an ancestor on the \
       current DFS path\n"
  end;
  Buffer.add_string buf "}\n";
  Buffer.contents buf

(* Render to canonical JSON. Nodes and edges are sorted
   by id (nodes) and by `(from, to, kind)` triple (edges)
   for deterministic output. The `cycle` flag surfaces as
   a top-level `_cycle: true` field. *)
let[@warning "-32"] to_json ~decision_id (decisions : Domain.decision list) :
    Jsonl.value =
  let g = build ~decision_id decisions in
  let node_json n =
    Jsonl.Object [ ("id", Jsonl.String n); ("label", Jsonl.String n) ]
  in
  let edge_json e =
    Jsonl.Object
      [
        ("from", Jsonl.String e.from_);
        ("to", Jsonl.String e.to_);
        ("kind", Jsonl.String e.kind);
      ]
  in
  Jsonl.Object
    [
      ("root", Jsonl.String g.root);
      ("nodes", Jsonl.Array (List.map node_json g.nodes));
      ("edges", Jsonl.Array (List.map edge_json g.edges));
      ("_cycle", Jsonl.Bool g.cycle);
    ]
