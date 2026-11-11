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

let pill_class = function
  | Holds -> "v-holds"
  | Refuted -> "v-refuted"
  | Outdated -> "v-outdated"
  | Waived -> "v-waived"
  | Inconclusive | NotCheckable | NeverChecked -> "v-unknown"

let rec first_verifier = function
  | [] -> None
  | Verifier command :: _ -> Some command
  | _ :: rest -> first_verifier rest

let state_of states id =
  match List.assoc_opt id states with
  | Some state -> state
  | None -> NeverChecked

let claim_fragment labels states claim =
  let state = state_of states claim.id in
  let details =
    (match first_verifier claim.requirements with
    | Some command ->
      [Printf.sprintf "<dt>%s</dt><dd><code>%s</code></dd>"
         (escape labels.verifier) (escape command)]
    | None -> [])
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
    (escape claim.id) (pill_class state) (state_to_string state)
    (escape claim.text) (String.concat "" details)

let count_state states wanted =
  List.length (List.filter (fun (_, state) -> state = wanted) states)

let fragment labels states claims uncovered =
  let verdict =
    Verdict.verdict_of_states (List.map snd states) |> verdict_to_string
  in
  let summary =
    [Printf.sprintf "<span>%s: <span class=\"v-pill v-%s\">%s</span></span>"
       (escape labels.verdict_word) verdict verdict]
    @ List.concat_map
        (fun (state, name) ->
          let count = count_state states state in
          if count = 0 then []
          else
            [Printf.sprintf
               "<span><span class=\"v-pill %s\">%s</span> &times;%d</span>"
               (pill_class state) name count])
        [Holds, "holds"; Outdated, "outdated"; Refuted, "refuted"; Waived, "waived"]
    @ [Printf.sprintf "<span>%d %s &middot; %d %s</span>" (List.length states)
         (escape labels.claims_word)
         (List.length uncovered) (escape labels.uncovered)]
  in
  String.concat "\n"
    ("<div class=\"map-summary\">" :: summary
    @ ["</div>"; "<div class=\"claims-grid\">"]
    @ List.map (claim_fragment labels states) claims
    @ ["</div>"])

let load root =
  match Project.load_spec root with
  | Error message -> failwith message
  | Ok spec -> (
    match Project.states root spec with
    | Error message -> failwith message
    | Ok states -> (
      match Project.uncovered root spec with
      | Error message -> failwith message
      | Ok uncovered -> (spec, states, uncovered)))

let html_files dist =
  Sys.readdir dist |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".html")
  |> List.map (Filename.concat dist)

let build root dist meta =
  let spec, states, uncovered = load root in
  let fragment_en = fragment labels_en states spec.claims uncovered in
  let fragment_ru = fragment labels_ru states spec.claims uncovered in
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

let check root dist =
  let spec, states, _ = load root in
  let failures = ref 0 in
  List.iter
    (fun name ->
      let page = Io.read_file (Filename.concat dist name) in
      List.iter
        (fun claim ->
          let state = state_of states claim.id in
          let needle = Printf.sprintf "<code class=\"claim-id\">%s</code>" claim.id in
          if not (contains needle page) then (
            Printf.eprintf "check: %s missing from %s\n" claim.id name;
            incr failures)
          else
            let pill =
              Printf.sprintf "<span class=\"v-pill %s\">%s</span>"
                (pill_class state) (state_to_string state)
            in
            if not (contains pill page) then (
              Printf.eprintf "check: %s state %s not rendered in %s\n" claim.id
                (state_to_string state) name;
              incr failures))
        spec.claims)
    ["index.html"; "index.ru.html"];
  if !failures > 0 then exit 1;
  Printf.printf "check: site map matches the computed states for %d claims\n"
    (List.length spec.claims)

let () =
  match Array.to_list Sys.argv with
  | [_; "build"; root; dist; meta] -> build root dist meta
  | [_; "check"; root; dist] -> check root dist
  | _ ->
    prerr_endline "usage: render.exe build ROOT DIST META | render.exe check ROOT DIST";
    exit 2
