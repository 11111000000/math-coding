(* lib/packages.ml — kernel aggregator for `mathc packages`.

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
* if a waiver exists in `decisions/waivers/*.yaml` -> "waived".
      The consult step lives in `lib/waiver.ml` and is exercised
      by `lib/gate.ml::gate_v32`; this module surfaces the verdict
      as a string but does not invoke the consult itself.
    * if the attestation's result is Pass -> "pass".

    Waiver support is implemented by `lib/waiver.ml` and adopted
    by `decisions/waiver-infrastructure-2026-10`; the consult
    step is wired into `lib/gate.ml::gate_v32` as `Open_with_waiver`.

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
  (* Raw YAML body of the decision file. The site renderer
     (lib/render.ml::render_decision_page_full) consumes this
     to surface intent / commitment / outcomes / obligations-
     with-claims / counterexample / risk / relations on the
     per-decision page; the verdict-grid alone never did. The body
     is the file contents verbatim (front-matter included) so the
     renderer can reuse the existing yaml-block-scalars-aware
     parser. *)
  yaml_body : string option;
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

(* Extract `verifier: <name>` entries from the YAML body in
   document order. Each obligation may carry multiple acceptance
   items (under `acceptance.all: [...]` or `acceptance.any: [...]`),
   so the returned list is FLAT — one string per accession in the
   order they appear. The companion function
   `Memory.extract_obligation_verifiers` walks the typed Jsonl.value
   tree; this line-based scanner exists because lib/packages.ml
   prefers to be parser-free. The two helpers MUST agree on
   order; tests/cli/packages-verifier.hs pins the contract. *)
let[@warning "-32"] extract_obligation_verifiers_lines lines =
  let in_obls = ref false in
  let in_acceptance_block = ref false in
  let in_acceptance_list = ref false in
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
          in_acceptance_block := false;
          in_acceptance_list := false;
          scan acc rest
        end
        else if !in_obls then begin
          if t = "" then scan acc rest
          else if t = "acceptance:" then begin
            in_acceptance_block := true;
            scan acc rest
          end
          else if !in_acceptance_block then begin
            let head =
              if String.length t >= 4 then String.sub t 0 4 else t
            in
            if head = "all:" || head = "any:" then begin
              in_acceptance_list := true;
              scan acc rest
            end
            else if String.length t > 0 && t.[0] = '-' then begin
              let trimmed = String.trim (String.sub t 1 (String.length t - 1)) in
              if
                String.length trimmed > 10
                && String.sub trimmed 0 10 = "verifier: "
              then begin
                let v =
                  String.trim
                    (String.sub trimmed 10 (String.length trimmed - 10))
                in
                if v <> "" then scan (v :: acc) rest else scan acc rest
              end
              else scan acc rest
            end
            else if
              raw_indent <= 2
              && String.length t > 0
              && t.[String.length t - 1] = ':'
            then begin
              in_acceptance_block := false;
              in_acceptance_list := false;
              scan acc rest
            end
            else scan acc rest
          end
          else if
            raw_indent = 0
            && String.length t > 0
            && t.[String.length t - 1] = ':'
          then begin
            in_obls := false;
            in_acceptance_block := false;
            in_acceptance_list := false;
            scan acc rest
          end
          else scan acc rest
      end
      else scan acc rest
  in
  scan [] lines

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
        let obligation_verifiers = extract_obligation_verifiers_lines lines in
        let decision_revision = None in
        (* Carry the raw YAML body verbatim so the site renderer
           can emit the decision's `intent`, `commitment`, etc.
           The body is small (~6 KB) per decision; we keep the
           full text rather than a hand-rolled subset so a
           future site surface that wants, say, `risk.owner` or
           `outcome.statement` does not need another parser
           pass. *)
        Some
          ( decision_id,
            decision_revision,
            obligation_ids,
            obligation_verifiers,
            Some raw )

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
    string is taken from the decision's
    `obligation_verifiers` list (in document order) which was
    extracted during load_decision via
    `extract_obligation_verifiers_lines`. When the list is empty
    (an obligation without an `acceptance` block, or a parse-failure
    fallback path) we fall back to the obligation id so the
    rendering layer never crashes; the placeholder is documented in
    decisions/kernel-bugs-v3.4-2026-10. *)
let[@warning "-32"] obligation_view ~now_iso ~obligation_id
    ~obligation_verifier ~store ~has_store =
  let verdict = verdict_of ~now_iso ~obligation_id ~store ~has_store in
  let att_opt = latest_attestation ~store ~obligation_id in
  let att = match att_opt with [] -> None | h :: _ -> Some h in
  {
    id = obligation_id;
    verdict;
    verifier =
      (match obligation_verifier with
       | "" -> obligation_id
       | s -> s);
    attestation_id =
      (match att with None -> None | Some a -> Some a.Domain.id);
    attestation_expires =
      (match att with
       | None -> None
       | Some a -> (
           match a.Domain.valid_until with None -> None | Some t -> Some t));
    remedies = remedies_of verdict;
  }

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
| Some
            ( decision_id,
              decision_revision,
              obligation_ids,
              obligation_verifiers,
              yaml_body ) ->
            (* Pair each obligation with its verifier by document
               order. `extract_obligation_verifiers_lines` returns
               a FLAT list of all verifier strings; we assign one
               verifier to each obligation in document order, with
               the obligation-id as fallback when the obligation
               has zero acceptance items. *)
            let n = List.length obligation_ids in
            (* Build a list of n elements: first n verifiers from
               the flat list, padded with empty strings. *)
            let take n xs =
              let rec loop n = function
                | [] -> []
                | _ when n <= 0 -> []
                | x :: rest -> x :: loop (n - 1) rest
              in
              loop n xs
            in
            let padded = take n obligation_verifiers in
            let padded_len = List.length padded in
            let final_verifiers =
              if padded_len = n then padded
              else padded @ List.init (n - padded_len) (fun _ -> "")
            in
            let obs =
              List.map2
                (fun oid ver ->
                  obligation_view ~now_iso ~obligation_id:oid
                    ~obligation_verifier:ver ~store ~has_store)
                obligation_ids final_verifiers
            in
            Some
              {
                decision_id;
                decision_revision;
                obligations = obs;
                yaml_body;
              })
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
      (* `yaml_body` is intentionally absent from the JSON form
         to keep `mathc packages --format=json` payload size
         bounded; the site renderer consumes the body directly
         from the in-memory record. *)
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

(* --- intent preview for the home grid ---
   Walk the YAML body, find the `intent:` key, and return the
   first non-empty content line (one-line summary for the
   home grid). Mirrors the same tolerance as the renderer. *)
let[@warning "-32"] intent_preview yaml_body =
  match yaml_body with
  | None -> ""
  | Some body ->
      let lines = String.split_on_char '\n' body in
      let idx =
        let rec scan i =
          if i >= List.length lines then -1
          else
            let l = List.nth lines i in
            if String.length (String.trim l) > 7
               && String.sub (String.trim l) 0 7 = "intent:"
            then i
            else scan (i + 1)
        in
        scan 0
      in
      if idx < 0 then ""
      else begin
        let raw = List.nth lines idx in
        let prefix_len = 7 in
        let rest =
          String.sub raw prefix_len (String.length raw - prefix_len)
          |> String.trim
        in
        if rest = "|" || rest = "" then begin
          let len = List.length lines in
          let rec first_non_empty i =
            if i >= len then ""
            else
              let l = List.nth lines i in
              let t = String.trim l in
              if t = "" then first_non_empty (i + 1) else t
          in
          let first = first_non_empty (idx + 1) in
          if first = "" then "" else first
        end
        else if rest = "" then ""
        else rest
      end

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
    "<section class=\"mathc-packages\" data-mathc-package-count=\"%d\" \
     data-mathc-pass-count=\"%d\" data-mathc-unknown-count=\"%d\" \
     data-mathc-fail-count=\"%d\" data-mathc-stale-count=\"%d\" \
     data-mathc-missing-count=\"%d\" data-mathc-waived-count=\"%d\" \
     data-mathc-as-of=\"%s\" data-mathc-policy=\"%s\">\n"
    p.counts.total p.counts.pass p.counts.unknown p.counts.fail
    p.counts.stale p.counts.missing p.counts.waived
    (html_escape p.as_of) (html_escape p.policy_id);
  Printf.bprintf buf "<h2>math-coding packages</h2>\n";
  Printf.bprintf buf
    "<p class=\"mathc-counts\">total=%d pass=%d fail=%d unknown=%d stale=%d \
     missing=%d no_store=%d</p>\n"
    p.counts.total p.counts.pass p.counts.fail p.counts.unknown p.counts.stale
    p.counts.missing p.counts.no_store;
  List.iter
    (fun d ->
      Printf.bprintf buf "<article class=\"mathc-decision\">\n";
      (* The decision heading is now a link to the per-decision
         page (already emitted by `render_decision_page_full` in
         lib/render.ml). Without the link, a visitor sees the
         decision id on the home page but has no in-page cue
         that the full YAML body (intent, commitment,
         outcomes, obligations-with-claims, counter-example,
         risk, relations) lives at decisions/<id>.html. *)
      Printf.bprintf buf
        "<h3><a class=\"mathc-decision-link\" \
         href=\"decisions/%s.html\">%s</a></h3>\n"
        (html_escape d.decision_id) (html_escape d.decision_id);
      (* One-line intent preview so the home grid shows what
         each decision is about without opening the per-decision
         page. Truncated to 240 chars to keep the grid scannable. *)
      let preview = intent_preview d.yaml_body in
      let preview_trimmed =
        let len = String.length preview in
        if len > 240 then String.sub preview 0 240 ^ "..." else preview
      in
      if String.length preview_trimmed > 0 then
        Printf.bprintf buf
          "<p class=\"mathc-decision-intent\">%s</p>\n"
          (html_escape preview_trimmed);
      Printf.bprintf buf "<ul class=\"mathc-obligations\">\n";
      List.iter
        (fun o ->
          Printf.bprintf buf
            "  <li class=\"mathc-obligation mathc-verdict-%s\" \
             data-mathc-verdict=\"%s\"><code>%s</code> <span \
             class=\"mathc-verdict-label\">%s</span></li>\n"
            (html_escape o.verdict) (html_escape o.verdict) (html_escape o.id)
            (html_escape o.verdict))
        d.obligations;
      Printf.bprintf buf "</ul>\n</article>\n")
    p.decisions;
  Buffer.add_string buf "</section>\n";
  Buffer.contents buf
