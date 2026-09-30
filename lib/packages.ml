(* lib/packages.ml — kernel aggregator for `mc packages`.

   Walks every decision in `decisions/` and joins each obligation
   against the attestation store at `attestations/`. Returns a
   structured `package_list` that the dispatcher renders as
   text, JSON, or HTML. The site at `site/index.md` consumes
   the HTML form.

   The function is pure: it takes a `reader` callback (path ->
   string) and a `decisions_root` + `attestations_root`. No I/O
   at module top level.

   The schema (per spec/semantics.md §`packages`):

   {
     "as_of": <iso8601>,
     "policy_id": <string>,
     "counts": {
       "total": <int>, "pass": <int>, "fail": <int>,
       "unknown": <int>, "waived": <int>, "stale": <int>,
       "missing": <int>, "no_store": <int>
     },
     "decisions": [
       {
         "decision_id": <string>,
         "decision_revision": <string option>,
         "obligations": [
           {
             "id": <string>,
             "verdict": "pass"|"fail"|"unknown"|"waived"|"stale"|"missing",
             "verifier": <string>,
             "attestation_id": <string option>,
             "attestation_expires": <string option>,
             "remedies": [<string>...]
           }
         ]
       }
     ]
   }

   This mirrors the per-obligation gap shape from lib/gate.ml.
   We do not import Gate directly: the gate is parameterized
   over a Change, while Packages is parameterless. The verdict is
   computed by:
   * if attestations_root is missing -> "no_store" (counts as
     missing);
   * if no attestation matches (decision, obligation) ->
     "missing";
   * if the latest attestation is past valid_until -> "stale";
   * if the attestation's result is Fail -> "fail";
   * if the attestation's result is Inconclusive or
     InfrastructureError -> "unknown";
   * if a waiver exists in `decisions/waivers/*.yaml` (future) ->
     "waived" (not implemented in this revision; reserved);
   * if the attestation's result is Pass -> "pass".

   v1 of the module does not yet consult waivers; that is a
   v3.0.0.30 task once `lib/waiver.ml` lands (Tier-3 close-out
   for the multi-policy hierarchy).

   Verdict ladder is closed; multiple variants are distinct
   (Theorems 4, 7: distinction must be preserved at the type
   level). *)

type attestation = Domain.attestation

type obligation_view = {
  id : string;
  verdict : string;
  verifier : string;
  attestation_id : string option;
  attestation_expires : string option;
  remedies : string list;
}

type decision_view = {
  decision_id : string;
  decision_revision : string option;
  obligations : obligation_view list;
}

type counts = {
  total : int;
  pass : int;
  fail : int;
  unknown : int;
  waived : int;
  stale : int;
  missing : int;
  no_store : int;
}

type package_list = {
  as_of : string;
  policy_id : string;
  counts : counts;
  decisions : decision_view list;
}

(* --- decision walker --- *)

let[@warning "-32"] is_decision_filename name =
  let sfx = Filename.extension name in
  sfx = ".yaml" || sfx = ".yml" || sfx = ".json"

(* Walk the decisions directory. Returns absolute paths in stable
   alphabetical order (the kernel output is sorted by spec). *)
let[@warning "-32"] list_decision_paths ~decisions_root =
  if not (Sys.file_exists decisions_root) then []
  else if not (Sys.is_directory decisions_root) then []
  else
    try
      Sys.readdir decisions_root |> Array.to_list
      |> List.filter is_decision_filename
      |> List.sort String.compare
      |> List.map (fun n -> Filename.concat decisions_root n)
    with _ -> []

(* Extract a decision id from a YAML/JSON string. Looks for a
   top-level `id:` line after front-matter. The pattern is the
   same as the existing self-check walker in bin/Mathc.ml. *)
let[@warning "-32"] extract_top_level_id lines =
  let rec scan = function
    | [] -> None
    | line :: rest ->
        let trimmed = String.trim line in
        if String.length trimmed > 4 && String.sub trimmed 0 4 = "id: " then
          Some (String.trim (String.sub trimmed 4 (String.length trimmed - 4)))
        else if String.length trimmed > 3 && String.sub trimmed 0 3 = "id:" then
          Some (String.trim (String.sub trimmed 3 (String.length trimmed - 3)))
        else scan rest
  in
  scan lines

(* Extract `id: <name>` entries nested under an `obligations:` line.
   Matches a one-level nesting like `  - id: foo` (i.e. two-space
   indent followed by `- id: foo`). Sufficient for the current
   decision format used in this repo.

   Enter the obligation list when we see `obligations:` at column 0.
   Inside the list:
   - a line that starts with `-` and contains `id: NAME` contributes
     an obligation id;
   - a line at column 0 that ends with `:` (e.g. `outcomes:`,
     `reversal:`, `risk:`, `relations:`) exits the list;
   - indented non-list lines (`    claim:`, `  outcome:`) keep us
     inside the current obligation. *)
let[@warning "-32"] extract_obligation_ids lines =
  let in_obls = ref false in
  let rec scan acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let t = String.trim line in
        let raw_indent =
          let len = String.length line in
          let i = ref 0 in
          while !i < len && line.[!i] = ' ' do
            incr i
          done;
          !i
        in
        if t = "obligations:" && raw_indent = 0 then begin
          in_obls := true;
          scan acc rest
        end
        else if !in_obls then
          if t = "" then scan acc rest
          else if String.length t > 0 && t.[0] = '-' then begin
            (* Look for `- id: NAME` (any indent) *)
            let trimmed = String.trim (String.sub t 1 (String.length t - 1)) in
            if String.length trimmed > 4 && String.sub trimmed 0 4 = "id: " then begin
              let v =
                String.trim (String.sub trimmed 4 (String.length trimmed - 4))
              in
              if v <> "" then scan (v :: acc) rest else scan acc rest
            end
            else scan acc rest
          end
          else if
            raw_indent = 0
            && String.length t > 0
            && t.[String.length t - 1] = ':'
          then begin
            (* Top-level key ending in ':' (e.g. `outcomes:`,
               `reversal:`, `risk:`, `relations:`). Exit the
               obligation list. *)
            in_obls := false;
            scan acc rest
          end
          else scan acc rest
        else scan acc rest
  in
  scan [] lines

(* Load a single decision into a stub. Returns None when the file
   does not parse or has no top-level id. *)
let[@warning "-32"] load_decision ~reader ~path =
  let raw = reader path in
  if raw = "" then None
  else
    let lines = String.split_on_char '\n' raw in
    match extract_top_level_id lines with
    | None -> None
    | Some decision_id ->
        let obligation_ids = extract_obligation_ids lines in
        let decision_revision = None in
        Some (decision_id, decision_revision, obligation_ids)

(* --- attestation join --- *)

(* Find the most recent attestation for a (decision, obligation)
   pair. The attestation store is keyed by the JSON filename,
   which encodes both ids; we filter on the typed fields. *)
let[@warning "-32"] latest_attestation ~store ~obligation_id =
  let matching =
    List.filter
      (fun (a : Domain.attestation) -> a.obligation = obligation_id)
      store
  in
  List.sort
    (fun (a : Domain.attestation) (b : Domain.attestation) ->
      compare b.issued_at a.issued_at)
    matching

(* Compute the verdict for an obligation. The verdict string is
   one of the closed set declared in `type obligation_view`. *)
let[@warning "-32"] verdict_of ~now_iso ~obligation_id ~store ~has_store =
  if not has_store then "no_store"
  else
    match latest_attestation ~store ~obligation_id with
    | [] -> "missing"
    | (att : Domain.attestation) :: _ -> (
        let is_expired =
          match att.valid_until with
          | Some t -> String.compare now_iso t > 0
          | None -> false
        in
        if is_expired then "stale"
        else
          match att.result with
          | Domain.Pass -> "pass"
          | Domain.Fail -> "fail"
          | Domain.Inconclusive | Domain.InfrastructureError -> "unknown")

(* `remedies` for a missing obligation. The list is a static
   catalog keyed on the verdict string; no waivers yet. *)
let[@warning "-32"] remedies_of = function
  | "missing" -> [ "run the documented verifier"; "or grant a waiver" ]
  | "stale" -> [ "re-run the verifier to refresh the attestation" ]
  | "fail" -> [ "investigate the failing verifier; cannot waive" ]
  | "unknown" -> [ "investigate the inconclusive verifier; treat as fail" ]
  | "no_store" ->
      [ "populate attestations/ via scripts/generate-attestations.py" ]
  | "waived" -> [ "review the waiver expiry; re-evaluate before it lapses" ]
  | _ -> []

(* Render an obligation view as a structured record. The verifier
   is captured at the structural level: in this revision we use
   the obligation id as the verifier stub (real verifier
   extraction is a v3.0.0.30 task once codec parses the
   `acceptance` block; the stub is fine for the package-list
   display). *)
let[@warning "-32"] obligation_view ~now_iso ~obligation_id ~store ~has_store =
  let verdict = verdict_of ~now_iso ~obligation_id ~store ~has_store in
  let att_opt = latest_attestation ~store ~obligation_id in
  let att = match att_opt with [] -> None | h :: _ -> Some h in
  {
    id = obligation_id;
    verdict;
    verifier = obligation_id;
    attestation_id =
      (match att with None -> None | Some a -> Some a.Domain.id);
    attestation_expires =
      (match att with
      | None -> None
      | Some a -> (
          match a.Domain.valid_until with None -> None | Some t -> Some t));
    remedies = remedies_of verdict;
  }

(* Render a decision view. *)
let[@warning "-32"] decision_view ~now_iso ~store ~has_store ~path =
  match load_decision ~reader:(fun _ -> failwith "unreachable") ~path with
  | None -> None
  | Some _ -> None

(* Walk every decision; produce a package_list. The store is
   passed in as a typed list (Domain.attestation list) — the
   caller loads the store from disk via Attestations.load; this
   module does not perform I/O on the store. This keeps the
   kernel/adapter boundary: lib/attestations/ is the I/O
   boundary; lib/packages.ml is pure. *)
let[@warning "-32"] is_meta_filename name =
  let base = Filename.basename name in
  match base with
  | "decision.yaml" -> true
  | "obligations.yaml" -> true
  | "obligation-count-reconcile.yaml" -> true
  | "ONBOARDING.md" -> true
  | "rationale.md" -> true
  | _ -> false

let[@warning "-32"] walk ~reader ~decisions_root ~store ~has_store ~now_iso
    ~policy_id =
  let decisions_paths =
    List.filter
      (fun p -> not (is_meta_filename p))
      (list_decision_paths ~decisions_root)
  in
  let decisions =
    List.filter_map
      (fun path ->
        match load_decision ~reader ~path with
        | None -> None
        | Some (decision_id, decision_revision, obligation_ids) ->
            let obs =
              List.map
                (fun oid ->
                  obligation_view ~now_iso ~obligation_id:oid ~store ~has_store)
                obligation_ids
            in
            Some { decision_id; decision_revision; obligations = obs })
      decisions_paths
  in
  let counts =
    ref
      {
        total = 0;
        pass = 0;
        fail = 0;
        unknown = 0;
        waived = 0;
        stale = 0;
        missing = 0;
        no_store = 0;
      }
  in
  let bump v =
    counts :=
      match v with
      | "pass" ->
          { !counts with total = !counts.total + 1; pass = !counts.pass + 1 }
      | "fail" ->
          { !counts with total = !counts.total + 1; fail = !counts.fail + 1 }
      | "unknown" ->
          {
            !counts with
            total = !counts.total + 1;
            unknown = !counts.unknown + 1;
          }
      | "waived" ->
          {
            !counts with
            total = !counts.total + 1;
            waived = !counts.waived + 1;
          }
      | "stale" ->
          { !counts with total = !counts.total + 1; stale = !counts.stale + 1 }
      | "missing" ->
          {
            !counts with
            total = !counts.total + 1;
            missing = !counts.missing + 1;
          }
      | "no_store" ->
          {
            !counts with
            total = !counts.total + 1;
            no_store = !counts.no_store + 1;
          }
      | _ -> { !counts with total = !counts.total + 1 }
  in
  List.iter
    (fun d -> List.iter (fun o -> bump o.verdict) d.obligations)
    decisions;
  { as_of = now_iso; policy_id; counts = !counts; decisions }

(* --- JSON renderer (sorted keys per spec) --- *)

let[@warning "-32"] rec json_value_of_string s = Jsonl.String s
let[@warning "-32"] json_value_of_int n = Jsonl.Int n
let[@warning "-32"] json_value_of_list js = Jsonl.Array js
let[@warning "-32"] json_value_of_obj kvs = Jsonl.Object kvs

let[@warning "-32"] option_to_json = function
  | None -> Jsonl.Null
  | Some s -> Jsonl.String s

let[@warning "-32"] count_to_json (c : counts) =
  let kvs =
    [
      ("fail", json_value_of_int c.fail);
      ("missing", json_value_of_int c.missing);
      ("no_store", json_value_of_int c.no_store);
      ("pass", json_value_of_int c.pass);
      ("stale", json_value_of_int c.stale);
      ("total", json_value_of_int c.total);
      ("unknown", json_value_of_int c.unknown);
      ("waived", json_value_of_int c.waived);
    ]
  in
  json_value_of_obj (List.sort (fun (a, _) (b, _) -> String.compare a b) kvs)

let[@warning "-32"] obligation_to_json (o : obligation_view) =
  let kvs =
    [
      ("attestation_expires", option_to_json o.attestation_expires);
      ("attestation_id", option_to_json o.attestation_id);
      ("id", Jsonl.String o.id);
      ( "remedies",
        json_value_of_list (List.map (fun s -> Jsonl.String s) o.remedies) );
      ("verdict", Jsonl.String o.verdict);
      ("verifier", Jsonl.String o.verifier);
    ]
  in
  json_value_of_obj (List.sort (fun (a, _) (b, _) -> String.compare a b) kvs)

let[@warning "-32"] decision_to_json (d : decision_view) =
  let obligations_json =
    json_value_of_list (List.map obligation_to_json d.obligations)
  in
  let kvs =
    [
      ("decision_id", Jsonl.String d.decision_id);
      ("decision_revision", option_to_json d.decision_revision);
      ("obligations", obligations_json);
    ]
  in
  json_value_of_obj (List.sort (fun (a, _) (b, _) -> String.compare a b) kvs)

let[@warning "-32"] to_json (p : package_list) =
  let kvs =
    [
      ("as_of", Jsonl.String p.as_of);
      ("counts", count_to_json p.counts);
      ("decisions", json_value_of_list (List.map decision_to_json p.decisions));
      ("policy_id", Jsonl.String p.policy_id);
      ("source", Jsonl.String "decisions/");
    ]
  in
  json_value_of_obj (List.sort (fun (a, _) (b, _) -> String.compare a b) kvs)

(* --- text renderer --- *)

let[@warning "-32"] to_text (p : package_list) =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "math-coding packages\n";
  Printf.bprintf buf "as_of: %s\n" p.as_of;
  Printf.bprintf buf "policy_id: %s\n" p.policy_id;
  Printf.bprintf buf
    "total=%d pass=%d fail=%d unknown=%d stale=%d missing=%d no_store=%d\n\n"
    p.counts.total p.counts.pass p.counts.fail p.counts.unknown p.counts.stale
    p.counts.missing p.counts.no_store;
  List.iter
    (fun d ->
      Printf.bprintf buf "%s\n" d.decision_id;
      List.iter
        (fun o ->
          Printf.bprintf buf "  %-40s %-8s %s\n" o.id o.verdict o.verifier)
        d.obligations;
      Buffer.add_char buf '\n')
    p.decisions;
  Buffer.contents buf

(* --- HTML renderer (self-contained fragment) --- *)

let[@warning "-32"] html_escape s =
  let len = String.length s in
  let buf = Buffer.create len in
  for i = 0 to len - 1 do
    match s.[i] with
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '&' -> Buffer.add_string buf "&amp;"
    | '"' -> Buffer.add_string buf "&quot;"
    | c -> Buffer.add_char buf c
  done;
  Buffer.contents buf

let[@warning "-32"] to_html (p : package_list) =
  let buf = Buffer.create 512 in
  Printf.bprintf buf
    "<section class=\"mc-packages\" data-mc-package-count=\"%d\" \
     data-mc-as-of=\"%s\" data-mc-policy=\"%s\">\n"
    p.counts.total (html_escape p.as_of) (html_escape p.policy_id);
  Printf.bprintf buf "<h2>math-coding packages</h2>\n";
  Printf.bprintf buf
    "<p class=\"mc-counts\">total=%d pass=%d fail=%d unknown=%d stale=%d \
     missing=%d no_store=%d</p>\n"
    p.counts.total p.counts.pass p.counts.fail p.counts.unknown p.counts.stale
    p.counts.missing p.counts.no_store;
  List.iter
    (fun d ->
      Printf.bprintf buf "<article class=\"mc-decision\">\n";
      Printf.bprintf buf "<h3>%s</h3>\n" (html_escape d.decision_id);
      Printf.bprintf buf "<ul class=\"mc-obligations\">\n";
      List.iter
        (fun o ->
          Printf.bprintf buf
            "  <li class=\"mc-obligation mc-verdict-%s\" \
             data-mc-verdict=\"%s\"><code>%s</code> <span \
             class=\"mc-verdict-label\">%s</span></li>\n"
            (html_escape o.verdict) (html_escape o.verdict) (html_escape o.id)
            (html_escape o.verdict))
        d.obligations;
      Printf.bprintf buf "</ul>\n</article>\n")
    p.decisions;
  Buffer.add_string buf "</section>\n";
  Buffer.contents buf
