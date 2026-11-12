open Domain

type labels = {
  lang : string;
  verifier : string;
  falsifier_word : string;
  control_word : string;
  register_word : string;
  claims_word : string;
  uncovered : string;
  verdict_word : string;
  scope_word : string;
  source_word : string;
  evidence_word : string;
  history : string;
  no_evidence : string;
  observations : string;
  candidate_tree_word : string;
  materials_word : string;
  definition_word : string;
  verifier_digest_word : string;
  environment_word : string;
  producer_word : string;
  independence_word : string;
  outcome_word : string;
  issued_at_word : string;
  valid_until_word : string;
  control_reach_word : string;
  requirement_word : string;
}

let labels_en = {
  lang = "en";
  verifier = "verifier";
  falsifier_word = "falsifier";
  control_word = "control";
  register_word = "register";
  claims_word = "claims";
  uncovered = "uncovered files";
  verdict_word = "verdict";
  scope_word = "scope";
  source_word = "source";
  evidence_word = "evidence";
  history = "history";
  no_evidence = "no evidence has been recorded for this claim yet";
  observations = "observations";
  candidate_tree_word = "candidate tree";
  materials_word = "materials digest";
  definition_word = "definition digest";
  verifier_digest_word = "verifier digest";
  environment_word = "environment";
  producer_word = "producer";
  independence_word = "independence";
  outcome_word = "outcome";
  issued_at_word = "issued at";
  valid_until_word = "valid until";
  control_reach_word = "control reach";
  requirement_word = "requirement";
}

let labels_ru = {
  lang = "ru";
  verifier = "проверка";
  falsifier_word = "опровержитель";
  control_word = "контроль";
  register_word = "регистр";
  claims_word = "обязательств";
  uncovered = "непокрытых файлов";
  verdict_word = "вердикт";
  scope_word = "область";
  source_word = "источник";
  evidence_word = "доказательство";
  history = "история";
  no_evidence = "доказательств для этого обязательства ещё нет";
  observations = "наблюдений";
  candidate_tree_word = "ревизия-кандидат";
  materials_word = "digest материалов";
  definition_word = "digest определения";
  verifier_digest_word = "digest проверки";
  environment_word = "среда";
  producer_word = "производитель";
  independence_word = "независимость";
  outcome_word = "исход";
  issued_at_word = "выдано";
  valid_until_word = "действует до";
  control_reach_word = "контроль достиг";
  requirement_word = "условие подтверждения";
}

let escape text =
  let buffer = Buffer.create (String.length text) in
  String.iter
    (fun ch ->
      match ch with
      | '&' -> Buffer.add_string buffer "&amp;"
      | '<' -> Buffer.add_string buffer "&lt;"
      | '>' -> Buffer.add_string buffer "&gt;"
      | '"' -> Buffer.add_string buffer "&quot;"
      | '\'' -> Buffer.add_string buffer "&#39;"
      | _ -> Buffer.add_char buffer ch)
    text;
  Buffer.contents buffer

let index_of_sub needle text =
  let limit = String.length text - String.length needle in
  let rec scan i =
    if i > limit then None
    else if String.sub text i (String.length needle) = needle then Some i
    else scan (i + 1)
  in
  scan 0

let contains needle text =
  match index_of_sub needle text with
  | Some _ -> true
  | None -> false

let replace_marker marker replacement text =
  match index_of_sub marker text with
  | None -> text
  | Some at ->
      String.sub text 0 at ^ replacement
      ^ String.sub text (at + String.length marker)
          (String.length text - at - String.length marker)

let rec replace_all marker replacement text =
  match index_of_sub marker text with
  | None -> text
  | Some at ->
      replace_all marker replacement
        (String.sub text 0 at ^ replacement
        ^ String.sub text (at + String.length marker)
            (String.length text - at - String.length marker))

(* The map is produced by the command line tool. The site renders that
   document and never computes a state of its own, so the published page
   cannot disagree with the tool. *)
type map = {
  verdict : string;
  states : (string * string) list;
  uncovered : int;
}

let pill_class = function
  | "holds" -> "v-holds"
  | "refuted" -> "v-refuted"
  | "outdated" -> "v-outdated"
  | "waived" -> "v-waived"
  | "inconclusive" -> "v-inconclusive"
  | "not-checkable" -> "v-not-checkable"
  | "never-checked" -> "v-never-checked"
  | "vacant" -> "v-vacant"
  | _ -> "v-unknown"

let read_map path =
  match Yojson.Safe.from_file path with
  | exception Yojson.Json_error message ->
      failwith ("the map is not readable JSON: " ^ message)
  | json -> (
      match json with
      | `Assoc fields -> (
          let text name =
            match List.assoc_opt name fields with Some (`String value) -> value | _ -> ""
          in
          let states =
            match List.assoc_opt "states" fields with
            | Some (`List items) ->
                List.filter_map
                  (fun item ->
                    match item with
                    | `Assoc pairs -> (
                        match
                          List.assoc_opt "id" pairs,
                          List.assoc_opt "state" pairs
                        with
                        | Some (`String id), Some (`String state) -> Some (id, state)
                        | _ -> None)
                    | _ -> None)
                  items
            | _ -> []
          in
          let uncovered =
            match List.assoc_opt "uncovered" fields with
            | Some (`List items) -> List.length items
            | _ -> 0
          in
          { verdict = text "verdict"; states; uncovered })
      | _ -> failwith "the map is not a JSON object")

let state_of states id =
  match List.assoc_opt id states with
  | Some state -> state
  | None -> "unknown"

let rec verifier_command = function
  | [] -> ""
  | Verifier command :: _ -> command
  | All requirements :: rest ->
      let found = verifier_command requirements in
      if found = "" then verifier_command rest else found
  | Any requirements :: rest ->
      let found = verifier_command requirements in
      if found = "" then verifier_command rest else found
  | _ :: rest -> verifier_command rest

let claim_path labels id =
  if labels.lang = "ru" then Printf.sprintf "claims/%s.ru.html" id
  else Printf.sprintf "claims/%s.html" id

let claim_fragment labels states claim =
  let state = state_of states claim.id in
  let details =
    [Printf.sprintf "<dt>%s</dt><dd><code>%s</code></dd>"
       (escape labels.verifier) (escape (verifier_command claim.requirements))]
    @ [Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape labels.falsifier_word)
         (escape claim.falsifier)]
    @ (match claim.control with
      | Some control ->
          [Printf.sprintf "<dt>%s</dt><dd><code>%s</code></dd>"
             (escape labels.control_word) (escape control)]
      | None -> [])
    @ [Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape labels.register_word)
         (escape (register_to_string claim.register))]
  in
  Printf.sprintf
    "<article class=\"claim\" id=\"%s\">\n\
     <header><a class=\"claim-link\" href=\"%s\"><code class=\"claim-id\">%s</code></a>\n\
     <span class=\"v-pill %s\">%s</span></header>\n\
     <p class=\"claim-text\">%s</p>\n\
     <dl>%s</dl>\n\
     </article>"
    (escape claim.id) (escape (claim_path labels claim.id)) (escape claim.id)
    (pill_class state) (escape state) (escape claim.text)
    (String.concat "" details)

let count_state states wanted =
  List.length (List.filter (fun (_, state) -> state = wanted) states)

let fragment labels map claims =
  let summary =
    [Printf.sprintf "<span>%s: <span class=\"v-pill v-%s\">%s</span></span>"
       (escape labels.verdict_word) (pill_class map.verdict) (escape map.verdict)]
    @ List.concat_map
        (fun state ->
          let count = count_state map.states state in
          if count = 0 then []
          else
            [Printf.sprintf
               "<span><span class=\"v-pill %s\">%s</span> &times;%d</span>"
               (pill_class state) (escape state) count])
        [ "holds"; "refuted"; "inconclusive"; "not-checkable"; "outdated";
          "never-checked"; "waived" ]
    @ [Printf.sprintf "<span>%d %s &middot; %d %s</span>" (List.length claims)
         (escape labels.claims_word) map.uncovered (escape labels.uncovered)]
  in
  String.concat "\n"
    ("<div class=\"map-summary\">" :: summary
    @ ["</div>"; "<div class=\"claims-grid\">"]
    @ List.map (claim_fragment labels map.states) claims
    @ ["</div>"])

let timestamp seconds =
  let tm = Unix.gmtime (float_of_int seconds) in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d UTC" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min

let outcome_color = function
  | Pass -> "#2f7a3a"
  | Fail -> "#9a2929"
  | Inconclusive -> "#b07a1a"
  | Infrastructure_error -> "#6f4a9e"
  | Not_run -> "#8a8a8a"

let read_trail root =
  match Trail.read root with
  | Ok evidence -> evidence
  | Error message -> failwith message

let evidence_of id trail =
  trail
  |> List.filter (fun (record : evidence) -> record.claim_id = id)
  |> List.sort (fun (a : evidence) (b : evidence) -> compare a.issued_at b.issued_at)

let history_svg records =
  let shown = if List.length records > 40 then
      List.filteri (fun index _ -> index >= List.length records - 40) records
    else records in
  let count = List.length shown in
  if count = 0 then ""
  else
    let width = 20 + count * 16 in
    let segments =
      shown
      |> List.mapi (fun index (record : evidence) ->
             let x = 10 + index * 16 in
             Printf.sprintf
               "<rect x=\"%d\" y=\"18\" width=\"12\" height=\"24\" fill=\"%s\"/>"
               x (outcome_color record.outcome))
      |> String.concat ""
    in
    let first = List.hd shown in
    let last = List.hd (List.rev shown) in
    Printf.sprintf
      "<svg viewBox=\"0 0 %d 74\" role=\"img\" aria-label=\"history of observations\">\
       %s<line x1=\"10\" y1=\"50\" x2=\"%d\" y2=\"50\" stroke=\"#d4d0c8\"/>\
       <text x=\"10\" y=\"66\" font-family=\"SF Mono, Menlo, monospace\" font-size=\"9\" fill=\"#8a8a8a\">%s</text>\
       <text x=\"%d\" y=\"66\" text-anchor=\"end\" font-family=\"SF Mono, Menlo, monospace\" font-size=\"9\" fill=\"#8a8a8a\">%s</text>\
       </svg>"
      width segments (width - 10) (escape (timestamp first.issued_at))
      (width - 10) (escape (timestamp last.issued_at))

let history_block labels records =
  let count = List.length records in
  if count = 0 then
    Printf.sprintf "<p class=\"muted\">%s</p>" (escape labels.no_evidence)
  else
    let strip = history_svg records in
    let recent =
      records
      |> List.rev
      |> List.filteri (fun index _ -> index < 12)
      |> List.map (fun (record : evidence) ->
             Printf.sprintf
               "<tr><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>"
               (escape (timestamp record.issued_at))
               (escape (outcome_to_string record.outcome))
               (escape (independence_to_string record.independence))
               (escape (match record.control_reach with
                   | Some reach -> reach
                   | None -> "-")))
      |> String.concat ""
    in
    Printf.sprintf
      "<figure class=\"figure\">%s<figcaption>%d %s</figcaption></figure>\
       <table><thead><tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead>\
       <tbody>%s</tbody></table>"
      strip count (escape labels.observations)
      (escape labels.issued_at_word) (escape labels.outcome_word)
      (escape labels.independence_word) (escape labels.control_reach_word) recent

let evidence_block labels records =
  match List.rev records with
  | [] -> Printf.sprintf "<p class=\"muted\">%s</p>" (escape labels.no_evidence)
  | latest :: _ ->
      let field name value =
        Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape name) value
      in
      let requirement =
        match latest.requirement with
        | Verifier command -> Printf.sprintf "<code>%s</code>" (escape command)
        | Review { authority; _ } -> escape authority
        | All _ | Any _ -> "all / any"
      in
      let producer_run =
        match latest.producer.run with
        | Some run -> Printf.sprintf "%s &middot; <code>%s</code>" (escape latest.producer.class_) (escape run)
        | None -> escape latest.producer.class_
      in
      let valid_until =
        match latest.valid_until with
        | Some moment -> escape (timestamp moment)
        | None -> "&mdash;"
      in
      let control_reach =
        match latest.control_reach with
        | Some reach -> escape reach
        | None -> "&mdash;"
      in
      Printf.sprintf "<dl class=\"evidence\">%s</dl>"
        (String.concat ""
           [ field labels.requirement_word requirement;
             field labels.candidate_tree_word
               (Printf.sprintf "<code>%s</code>" (escape latest.candidate_tree));
             field labels.materials_word
               (Printf.sprintf "<code>%s</code>" (escape latest.materials_digest));
             field labels.definition_word
               (Printf.sprintf "<code>%s</code>" (escape latest.definition_digest));
             field labels.verifier_digest_word
               (Printf.sprintf "<code>%s</code>" (escape latest.verifier_digest));
             field labels.environment_word
               (Printf.sprintf "%s &middot; <code>%s</code>"
                  (escape latest.environment.class_)
                  (escape latest.environment.fingerprint));
             field labels.producer_word producer_run;
             field labels.independence_word
               (escape (independence_to_string latest.independence));
             field labels.outcome_word (escape (outcome_to_string latest.outcome));
             field labels.issued_at_word (escape (timestamp latest.issued_at));
             field labels.valid_until_word valid_until;
             field labels.control_reach_word control_reach ])

let claim_fields labels (claim : claim) =
  let field name value =
    Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape name) value
  in
  let scope =
    escape (String.concat ", " claim.scope)
  in
  let source =
    match claim.source with
    | None -> "&mdash;"
    | Some source ->
      Printf.sprintf "%s &middot; <code>%s</code>"
        (escape (source_kind_to_string source.kind))
        (escape source.path)
  in
  String.concat ""
    [ field labels.verifier
        (Printf.sprintf "<code>%s</code>"
           (escape (verifier_command claim.requirements)));
      field labels.falsifier_word (escape claim.falsifier);
      (match claim.control with
      | Some control ->
          field labels.control_word (Printf.sprintf "<code>%s</code>" (escape control))
      | None -> "");
      field labels.register_word (escape (register_to_string claim.register));
      field labels.scope_word scope;
      field labels.source_word source ]

let claim_page labels template (claim : claim) state records meta =
  template
  |> replace_all "CLAIM_ID" (escape claim.id)
  |> replace_marker "CLAIM_STATE"
      (Printf.sprintf "<span class=\"v-pill %s\">%s</span>" (pill_class state)
         (escape state))
  |> replace_marker "CLAIM_TEXT" (escape claim.text)
  |> replace_marker "CLAIM_FIELDS" (claim_fields labels claim)
  |> replace_marker "CLAIM_EVIDENCE" (evidence_block labels records)
  |> replace_marker "CLAIM_HISTORY" (history_block labels records)
  |> replace_marker "<!-- @META@ -->" (escape meta)

let load_spec root =
  match Project.load_spec root with
  | Error message -> failwith message
  | Ok spec -> spec

let html_files dist =
  Sys.readdir dist |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".html")
  |> List.map (Filename.concat dist)

let build root dist meta map_path =
  let spec = load_spec root in
  let map = read_map map_path in
  let fragment_en = fragment labels_en map spec.claims in
  let fragment_ru = fragment labels_ru map spec.claims in
  List.iter
    (fun path ->
      let page =
        Io.read_file path
        |> replace_marker "<!-- @CLAIMS:en@ -->" fragment_en
        |> replace_marker "<!-- @CLAIMS:ru@ -->" fragment_ru
        |> replace_marker "<!-- @META@ -->" (escape meta)
      in
      Io.write_atomic path page)
    (html_files dist);
  let templates = Filename.concat root "site/templates" in
  let template_en = Io.read_file (Filename.concat templates "claim.html") in
  let template_ru = Io.read_file (Filename.concat templates "claim.ru.html") in
  let trail = read_trail root in
  let claims_dir = Filename.concat dist "claims" in
  Io.mkdir_p claims_dir;
  List.iter
    (fun (claim : claim) ->
      let state = state_of map.states claim.id in
      let records = evidence_of claim.id trail in
      let page_en = claim_page labels_en template_en claim state records meta in
      let page_ru = claim_page labels_ru template_ru claim state records meta in
      Io.write_atomic
        (Filename.concat claims_dir (Printf.sprintf "%s.html" claim.id))
        page_en;
      Io.write_atomic
        (Filename.concat claims_dir (Printf.sprintf "%s.ru.html" claim.id))
        page_ru)
    spec.claims

let check root dist map_path =
  let spec = load_spec root in
  let map = read_map map_path in
  let failures = ref 0 in
  let fail message =
    Printf.eprintf "check: %s\n" message;
    incr failures
  in
  List.iter
    (fun name ->
      let page = Io.read_file (Filename.concat dist name) in
      List.iter
        (fun claim ->
          let state = state_of map.states claim.id in
          let needle = Printf.sprintf "<code class=\"claim-id\">%s</code>" claim.id in
          if not (contains needle page) then (
            Printf.eprintf "check: %s missing from %s\n" claim.id name;
            incr failures)
          else
            let pill =
              Printf.sprintf "<span class=\"v-pill %s\">%s</span>"
                (pill_class state) state
            in
            if not (contains pill page) then (
              Printf.eprintf "check: %s state %s not rendered in %s\n" claim.id state
                name;
              incr failures))
        spec.claims)
    ["index.html"; "index.ru.html"];
  List.iter
    (fun (id, state) ->
      if not (List.exists (fun (claim : claim) -> claim.id = id) spec.claims) then
        fail (Printf.sprintf "the map reports an unknown claim %s" id))
    map.states;
  List.iter
    (fun (claim : claim) ->
      if not (List.mem_assoc claim.id map.states) then
        fail (Printf.sprintf "the map has no state for %s" claim.id))
    spec.claims;
  let canonical = Filename.concat dist "METHODOLOGY.md" in
  if not (Sys.file_exists canonical) then
    fail "the canonical methodology was not copied into the site"
  else if not (contains "# Math Coding:" (Io.read_file canonical)) then
    fail "the copied canonical methodology is not the methodology document";
  List.iter
    (fun name ->
      let page = Io.read_file (Filename.concat dist name) in
      if not (contains "href=\"METHODOLOGY.md\"" page) then
        fail (Printf.sprintf "the canonical methodology is not linked from %s" name))
    ["methodology.html"; "methodology.ru.html"];
  List.iter
    (fun (claim : claim) ->
      List.iter
        (fun name ->
          let path = Filename.concat (Filename.concat dist "claims") name in
          if not (Sys.file_exists path) then
            fail (Printf.sprintf "the claim page %s is missing" name))
        [ Printf.sprintf "%s.html" claim.id; Printf.sprintf "%s.ru.html" claim.id ])
    spec.claims;
  List.iter
    (fun name ->
      if Filename.check_suffix name ".html" then (
        let page = Io.read_file (Filename.concat dist name) in
        List.iter
          (fun href ->
            match Links.local_target href with
            | None -> ()
            | Some target ->
              if not (Sys.file_exists (Filename.concat dist target)) then
                fail (Printf.sprintf "broken local link in %s: %s" name href))
          (Links.hrefs page)))
    (Sys.readdir dist |> Array.to_list);
  List.iter
    (fun name ->
      let path = Filename.concat dist name in
      if not (Sys.file_exists path) then
        fail (Printf.sprintf "the page %s is missing" name)
      else
        let page = Io.read_file path in
        if contains "@CLAIMS" page || contains "@META@" page then
          fail (Printf.sprintf "the page %s still carries a placeholder" name))
    [ "index.html"; "index.ru.html"; "methodology.html"; "methodology.ru.html";
      "workflow.html"; "workflow.ru.html"; "measurements.html";
      "measurements.ru.html"; "404.html" ];
  List.iter
    (fun (claim : claim) ->
      List.iter
        (fun (name, suffix) ->
          let page = Io.read_file (Filename.concat dist name) in
          let href = Printf.sprintf "claims/%s%s" claim.id suffix in
          if not (contains (Printf.sprintf "href=\"%s\"" href) page) then
            fail (Printf.sprintf "%s does not link to %s" name href);
          if not (contains (Printf.sprintf "id=\"%s\"" claim.id) page) then
            fail (Printf.sprintf "%s has no anchor for %s" name claim.id))
        [ ("index.html", ".html"); ("index.ru.html", ".ru.html") ])
    spec.claims;
  if !failures > 0 then exit 1;
  Printf.printf "check: the site renders the map of the tool for %d claims\n"
    (List.length spec.claims);
  Printf.printf "check: canonical methodology and local links are in place\n"

let () =
  match Array.to_list Sys.argv with
  | [_; "build"; root; dist; meta; map_path] -> build root dist meta map_path
  | [_; "check"; root; dist; map_path] -> check root dist map_path
  | _ ->
      prerr_endline
        "usage: render.exe build ROOT DIST META MAP | render.exe check ROOT DIST MAP";
      exit 2
