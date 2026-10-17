(* lib/render/render_yaml.ml — hand-rolled YAML subset for decision
   bodies.

   Split from lib/render/render.ml. Deliberately does NOT pull in a
   full YAML library; decisions use a narrow shape. Depends on
   render_md for markdown rendering. *)

open Render_md

(* --- per-decision YAML body rendering (Phase 1 of site-quality-2026-10) --- *)

(* A hand-rolled subset YAML reader used to surface decision body
   sections on per-decision pages. We deliberately do NOT pull in a
   full YAML library: the decisions in this repository use a narrow
   shape (top-level scalars, `key: |` block scalars, and short lists
   of `{id: ..., ...}` objects) and a 200-line parser is auditable.
   The reader is *tolerant*: unknown shapes emit empty sections
   rather than crashing, so a future decision that adds a new field
   does not break the site. *)

type yaml_block =
  | Scalar of string
  | Block of string list
  | List of yaml_block list
  | Map of (string * yaml_block) list

(* Compute the indent (count of leading spaces) of a line, ignoring
   blank lines. *)
let[@warning "-32"] indent_of s =
  let len = String.length s in
  let i = ref 0 in
  while !i < len && s.[!i] = ' ' do
    incr i
  done;
  !i

(* Trim trailing whitespace and trailing newlines for stable
   rendering. *)
let[@warning "-32"] trim_block_lines lines =
  let rec trim_front = function
    | [] -> []
    | "" :: rest -> trim_front rest
    | x :: rest -> x :: rest
  in
  let rec trim_back = function
    | [] -> []
    | xs ->
        let last = List.hd (List.rev xs) in
        if last = "" then trim_back (List.rev (List.tl (List.rev xs)))
        else xs
  in
  trim_back (trim_front lines)

(* Find the line index at which a top-level key `name:` lives.
   Top-level keys are at indent 0 and start with `name:`. Returns
   -1 when the key is absent. *)
let[@warning "-32"] find_top_key lines name =
  let prefix = name ^ ":" in
  let rec scan i =
    if i >= List.length lines then -1
    else
      let l = List.nth lines i in
      let ind = indent_of l in
      let t = String.trim l in
      if ind = 0 && String.length t >= String.length prefix
         && String.sub t 0 (String.length prefix) = prefix
      then i
      else scan (i + 1)
  in
  scan 0

(* Determine where a top-level block ends. The block starts at
   `start_idx` (the line holding `key:`) and ends at the next
   line whose indent is 0 and which is non-empty, or at EOF. *)
let[@warning "-32"] block_end lines start_idx =
  let rec scan i =
    if i >= List.length lines then i
    else
      let l = List.nth lines i in
      let ind = indent_of l in
      let t = String.trim l in
      if i > start_idx && ind = 0 && t <> "" then i
      else scan (i + 1)
  in
  scan (start_idx + 1)

(* Extract a top-level `key: scalar` value (one line, no `|`). *)
let[@warning "-32"] top_scalar lines name =
  let idx = find_top_key lines name in
  if idx < 0 then None
  else
    let raw = List.nth lines idx in
    let prefix_len = String.length name + 1 in
    if String.length raw <= prefix_len then None
    else
      let rest =
        String.sub raw prefix_len (String.length raw - prefix_len)
        |> String.trim
      in
      if rest = "" || rest = "|" then None else Some rest

(* Extract a top-level `key: |` block scalar. Returns the lines of
   the block with common leading indent stripped. *)
let[@warning "-32"] top_block lines name =
  let idx = find_top_key lines name in
  if idx < 0 then None
  else
    let raw = List.nth lines idx in
    let prefix = name ^ ":" in
    let prefix_len = String.length prefix in
    let after_colon =
      String.sub raw prefix_len (String.length raw - prefix_len)
      |> String.trim
    in
    let len = List.length lines in
    let _ = len in
    let end_ = block_end lines idx in
    let body_lines =
      let slice = List.filteri (fun i _ -> i > idx && i < end_) lines in
      slice
    in
    if List.length body_lines = 0 then None
    else
      let indents =
        List.filter_map
          (fun l ->
            let t = String.trim l in
            if t = "" then None else Some (indent_of l))
          body_lines
      in
      let min_ind =
        match indents with
        | [] -> 0
        | h :: rest -> List.fold_left min h rest
      in
      let stripped =
        List.map
          (fun l ->
            if String.length l <= min_ind then ""
            else String.sub l min_ind (String.length l - min_ind))
          body_lines
      in
      let cleaned = trim_block_lines stripped in
      if after_colon = "|" then Some (String.concat "\n" cleaned)
      else if after_colon = "" then
        (* Inline scalar mode: the value is on the next indented
           line(s). *)
        Some (String.concat "\n" cleaned)
      else Some (after_colon)

(* Extract a top-level `key:` list of objects. Each item has an
   `id: NAME` (and optionally other fields). Returns the list of
   (id, body_md) tuples where body_md is the indented YAML body
   (sans the leading `id:`) for that item. *)
let[@warning "-32"] top_object_list lines name =
  let idx = find_top_key lines name in
  if idx < 0 then None
  else
    let len = List.length lines in
    let _ = len in
    let end_ = block_end lines idx in
    let body =
      List.filteri (fun i _ -> i > idx && i < end_) lines
    in
    let items = ref [] in
    let current = ref [] in
    let flush () =
      let rev = List.rev !current in
      items := rev :: !items;
      current := []
    in
    let is_list_marker t =
      String.length t > 2 && String.sub t 0 2 = "- "
    in
    List.iter
      (fun l ->
        let t = String.trim l in
        if is_list_marker t then begin
          flush ();
          current := [ String.sub t 2 (String.length t - 2) ]
        end
        else if t <> "" then current := l :: !current)
      body;
    flush ();
    let raw_items = List.rev !items in
    let extract_id item_lines =
      let rec find = function
        | [] -> None
        | line :: rest ->
            let t = String.trim line in
            if String.length t > 4 && String.sub t 0 4 = "id: " then
              Some
                (String.trim
                   (String.sub t 4 (String.length t - 4)))
            else if String.length t > 3 && String.sub t 0 3 = "id:" then
              Some
                (String.trim
                   (String.sub t 3 (String.length t - 3)))
            else find rest
      in
      find item_lines
    in
    let pairs =
      List.filter_map
        (fun item_lines ->
          match extract_id item_lines with
          | None -> None
          | Some id ->
              let indents =
                List.filter_map
                  (fun l ->
                    let t = String.trim l in
                    if t = "" then None else Some (indent_of l))
                  item_lines
              in
              let min_ind =
                match indents with
                | [] -> 0
                | h :: rest -> List.fold_left min h rest
              in
              let stripped =
                List.map
                  (fun l ->
                    if String.length l <= min_ind then ""
                    else
                      String.sub l min_ind (String.length l - min_ind))
                  item_lines
              in
              let body_md =
                trim_block_lines stripped |> String.concat "\n"
              in
              Some (id, body_md))
        raw_items
    in
    Some pairs

(* Extract a top-level `key:` list of plain strings (each `- value`).
   Used for `axiom_link` and `scope.paths`. *)
let[@warning "-32"] top_string_list lines name =
  match top_object_list lines name with
  | None -> None
  | Some pairs ->
      let strings =
        List.filter_map
          (fun (id, body_md) ->
            let t = String.trim body_md in
            if t = "" then Some id
            else if String.length t > 0 && t.[0] <> '#' then Some id
            else None)
          pairs
      in
      Some strings

(* Render a single section. `md_of` converts the YAML body to
   inline-Markdown text via `md_inline` (handles backticks,
   underscores, links) — used for headings, single-scalar values.
   `block_of` converts via `md_parse` (handles full markdown) — used
   for block scalars and lists of objects. *)
let[@warning "-32"] render_yaml_section ~heading ~body_md =
  if body_md = "" then ""
  else
    Printf.sprintf
      "<h2>%s</h2>\n<div class=\"mathc-decision-section\">%s</div>\n"
      (html_escape heading) (md_parse body_md)

(* Render a `scope.paths`-style list of plain strings as a
   dotted list of `<code>` pills. Used by `render_decision_yaml`
   for the `scope` section. *)
let[@warning "-32"] render_quad paths =
  if paths = [] then ""
  else
    let entries =
      List.map (fun p -> Printf.sprintf "<code>%s</code>" (html_escape p)) paths
    in
    Printf.sprintf "<h2>Scope</h2>\n<p>%s</p>\n"
      (String.concat " &middot; " entries)

let[@warning "-32"] render_yaml_list_section ~heading ~entries =
  if entries = [] then ""
  else
    let buf = Buffer.create 128 in
    Printf.bprintf buf "<h2>%s</h2>\n<ul class=\"mathc-decision-list\">\n"
      (html_escape heading);
    List.iter
      (fun entry ->
        Buffer.add_string buf "  <li>";
        Buffer.add_string buf (md_inline entry);
        Buffer.add_string buf "</li>\n")
      entries;
    Buffer.add_string buf "</ul>\n";
    Buffer.contents buf

let[@warning "-32"] render_yaml_object_list_section ~heading ~pairs =
  if pairs = [] then ""
  else
    let buf = Buffer.create 256 in
    Printf.bprintf buf
      "<h2>%s</h2>\n<ol class=\"mathc-decision-object-list\">\n"
      (html_escape heading);
    List.iter
      (fun (id, body_md) ->
        Printf.bprintf buf
          "  <li><code class=\"mathc-decision-id\">%s</code>\n    <div>%s</div>\n  </li>\n"
          (html_escape id) (md_parse body_md))
      pairs;
    Buffer.add_string buf "</ol>\n";
    Buffer.contents buf

(* Strip the boilerplate lines from an obligation body so the
   rendered `<li><code>id</code>...` pair does not duplicate
   fields that the surrounding HTML already carries (id is in
   the `<code>` pill; outcome belongs to the obligation
   grouping, not the claim text; acceptance is verification
   machinery, not prose). We strip:
     - `id: ...`
     - `outcome: ...` (the obligation→outcome cross-link)
     - `acceptance:` block (the verifier list)
   The `claim:` block is kept verbatim — it is the obligation's
   public prose and belongs on the page. *)
let[@warning "-32"] strip_boilerplate body_md =
  let lines = String.split_on_char '\n' body_md in
  let starts_with prefix t =
    String.length t >= String.length prefix
    && String.sub t 0 (String.length prefix) = prefix
  in
  let rec drop_outcome_and_id acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let t = String.trim line in
        let is_id = starts_with "id:" t || starts_with "id: " t in
        let is_outcome = starts_with "outcome:" t || starts_with "outcome: " t in
        if is_id || is_outcome then drop_outcome_and_id acc rest
        else drop_outcome_and_id (line :: acc) rest
  in
  (* Second pass: drop the `acceptance:` block. Once we see
     `acceptance:`, drop every indented continuation that follows
     until we return to indent 0. *)
  let rec drop_acceptance acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let t = String.trim line in
        if t = "acceptance:" then begin
          let rec consume_indented = function
            | [] -> []
            | l :: r ->
                let tl = String.trim l in
                let ind =
                  let len = String.length l in
                  let i = ref 0 in
                  while !i < len && l.[!i] = ' ' do
                    incr i
                  done;
                  !i
                in
                if tl = "" then consume_indented r
                else if ind > 0 then consume_indented r
                else l :: r
          in
          drop_acceptance acc (consume_indented rest)
        end
        else drop_acceptance (line :: acc) rest
  in
  let stripped1 = drop_outcome_and_id [] lines in
  let stripped2 = drop_acceptance [] stripped1 in
  String.concat "\n" stripped2

let[@warning "-32"] render_yaml_obligations_section ~heading ~pairs ~verdict_by_id
    =
  if pairs = [] then ""
  else
    let buf = Buffer.create 512 in
    Printf.bprintf buf "<h2>%s</h2>\n<ol class=\"mathc-decision-obligations\">\n"
      (html_escape heading);
    List.iter
      (fun (id, body_md) ->
        let verdict =
          match List.assoc_opt id verdict_by_id with
          | Some v -> v
          | None -> "missing"
        in
        Printf.bprintf buf
          "  <li>\n    <div class=\"mathc-decision-obligation-head\">\n      \
           <code class=\"mathc-decision-id\">%s</code>\n      <span \
           class=\"mathc-verdict-label mathc-verdict-%s\">%s</span>\n    \
           </div>\n    <div class=\"mathc-decision-obligation-body\">%s</div>\n  \
           </li>\n"
          (html_escape id) verdict verdict
          (md_parse (strip_boilerplate body_md)))
      pairs;
    Buffer.add_string buf "</ol>\n";
    Buffer.contents buf

(* Top-level YAML section renderer for per-decision pages. Reads
   the body, calls the per-section extractors, and emits HTML.
   Returns "" when the body is absent or yields no recognised
   sections. *)
let[@warning "-32"] render_decision_yaml ~yaml_body ~verdict_by_id =
  match yaml_body with
  | None -> ""
  | Some body ->
      let lines = String.split_on_char '\n' body in
      let buf = Buffer.create 1024 in
      (* 1. intent — block scalar preferred, scalar fallback *)
      let intent_html =
        match top_block lines "intent" with
        | Some s ->
            render_yaml_section ~heading:"Intent" ~body_md:s
        | None -> (
            match top_scalar lines "intent" with
            | Some s ->
                render_yaml_section ~heading:"Intent" ~body_md:s
            | None -> "")
      in
      Buffer.add_string buf intent_html;
      (* 2. commitment — same shape *)
      let commit_html =
        match top_block lines "commitment" with
        | Some s ->
            render_yaml_section ~heading:"Commitment" ~body_md:s
        | None -> (
            match top_scalar lines "commitment" with
            | Some s ->
                render_yaml_section ~heading:"Commitment" ~body_md:s
            | None -> "")
      in
      Buffer.add_string buf commit_html;
      (* 3. scope — list of paths and decisions *)
      let scope_paths =
        top_object_list lines "scope"
        |> Option.map (List.map fst)
      in
      let scope_html =
        Option.value scope_paths ~default:[]
        |> render_quad
      in
      Buffer.add_string buf scope_html;
      (* 4. outcomes — list of {id, statement} *)
      (match top_object_list lines "outcomes" with
       | Some [] | None -> ()
       | Some pairs ->
           Buffer.add_string buf
             (render_yaml_object_list_section ~heading:"Outcomes"
                ~pairs));
      (* 5. obligations — list of {id, claim, ...}; verdict-pill
            cross-link uses the in-memory verdict map. *)
      (match top_object_list lines "obligations" with
       | Some [] | None -> ()
       | Some pairs ->
           Buffer.add_string buf
             (render_yaml_obligations_section ~heading:"Obligations"
                ~pairs ~verdict_by_id));
      (* 6. counterexample — block scalar preferred, scalar fallback *)
      let ce_html =
        match top_block lines "counterexample" with
        | Some s ->
            render_yaml_section ~heading:"Counter-example"
              ~body_md:s
        | None -> (
            match top_scalar lines "counterexample" with
            | Some s ->
                render_yaml_section ~heading:"Counter-example"
                  ~body_md:s
            | None -> "")
      in
      Buffer.add_string buf ce_html;
      (* 7. risk — block scalar preferred; if not block-scalar,
            fall back to the inline value (rare). *)
      let risk_html =
        match top_block lines "risk" with
        | Some s ->
            render_yaml_section ~heading:"Risk" ~body_md:s
        | None -> (
            match top_scalar lines "risk" with
            | Some s ->
                render_yaml_section ~heading:"Risk" ~body_md:s
            | None -> "")
      in
      Buffer.add_string buf risk_html;
      (* 8. relations — list of objects with one field each
            (e.g. `addresses: [..]`, `supersedes: [..]`). We
            produce one bullet per (kind, target) pair. *)
      (match top_object_list lines "relations" with
       | Some [] | None -> ()
| Some pairs ->
            let flat =
              List.concat_map
                (fun (kind, body_md) ->
                  let lines = String.split_on_char '\n' body_md in
                  let target_list =
                    List.filter_map
                      (fun l ->
                        let t = String.trim l in
                        if String.length t > 2
                           && String.sub t 0 2 = "- "
                        then
                          Some
                            (String.sub t 2 (String.length t - 2))
                        else None)
                      lines
                  in
                  List.map (fun t -> (kind, t)) target_list)
                pairs
            in
           if flat <> [] then begin
             let buf2 = Buffer.create 128 in
             Printf.bprintf buf2
               "<h2>Relations</h2>\n<ul class=\"mathc-decision-relations\">\n";
             List.iter
               (fun (kind, target) ->
                 Printf.bprintf buf2
                   "  <li><code>%s</code> &rarr; <code>%s</code></li>\n"
                   (html_escape kind) (html_escape target))
               flat;
             Buffer.add_string buf2 "</ul>\n";
             Buffer.add_string buf (Buffer.contents buf2)
           end);
      (* 9. axiom_link — list of axiom ids, rendered as cross-links *)
      (match top_string_list lines "axiom_link" with
       | Some [] | None -> ()
       | Some ids ->
           let axiom_links =
             List.map
               (fun id ->
                 Printf.sprintf "<a href=\"../axioms/%s.html\">%s</a>"
                   (html_escape id) (html_escape id))
               ids
           in
           let inline = String.concat " &middot; " axiom_links in
           Buffer.add_string buf
             (Printf.sprintf
                "<h2>Axiom links</h2>\n<p class=\"mathc-decision-axiom-link\">%s</p>\n"
                inline));
      Buffer.contents buf

(* Stubs the helpers `render_yaml_section` etc. above already
   defined. The `render_quad` placeholder that lived here was
   promoted to its own top-level binding near the section
   renderers. *)
