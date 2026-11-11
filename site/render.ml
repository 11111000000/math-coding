open Domain

type labels = {
  verifier : string;
  falsifier : string;
  control : string;
  register : string;
  claims_word : string;
  uncovered : string;
  verdict_word : string;
}

let labels_en = {
  verifier = "verifier";
  falsifier = "falsifier";
  control = "control";
  register = "register";
  claims_word = "claims";
  uncovered = "uncovered files";
  verdict_word = "verdict";
}

let labels_ru = {
  verifier = "проверка";
  falsifier = "опровержитель";
  control = "контроль";
  register = "регистр";
  claims_word = "обязательств";
  uncovered = "непокрытых файлов";
  verdict_word = "вердикт";
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

let claim_fragment labels states claim =
  let state = state_of states claim.id in
  let details =
    [Printf.sprintf "<dt>%s</dt><dd><code>%s</code></dd>"
       (escape labels.verifier) (escape (verifier_command claim.requirements))]
    @ [Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape labels.falsifier)
         (escape claim.falsifier)]
    @ (match claim.control with
      | Some control ->
          [Printf.sprintf "<dt>%s</dt><dd><code>%s</code></dd>"
             (escape labels.control) (escape control)]
      | None -> [])
    @ [Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (escape labels.register)
         (escape (register_to_string claim.register))]
  in
  Printf.sprintf
    "<article class=\"claim\">\n\
     <header><code class=\"claim-id\">%s</code>\n\
     <span class=\"v-pill %s\">%s</span></header>\n\
     <p class=\"claim-text\">%s</p>\n\
     <dl>%s</dl>\n\
     </article>"
    (escape claim.id) (pill_class state) (escape state)
    (escape claim.text) (String.concat "" details)

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
    (html_files dist)

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
