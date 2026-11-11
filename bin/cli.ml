open Domain

type options = {
  mutable root : string;
  mutable json : bool;
  mutable reason : string;
  mutable by : string;
  mutable outcome : string;
  mutable valid_for : int option;
  mutable recovery : string;
  mutable control : string;
  mutable requirements : string list;
  mutable write : bool;
  mutable version : bool;
  mutable help : bool;
  mutable source : string;
}

let options () =
  { root = "."; json = false; reason = ""; by = ""; outcome = "pass";
    valid_for = None; recovery = ""; control = ""; requirements = []; write = false;
    version = false; help = false; source = "" }

let parse_requirement text =
  match String.index_opt text ':' with
  | None -> Error "expected verifier:CMD or review:WHO"
  | Some index ->
      let kind = String.sub text 0 index in
      let value = String.sub text (index + 1) (String.length text - index - 1) in
      if value = "" then Error "the requirement is empty"
      else if kind = "verifier" then Ok (Verifier value)
      else if kind = "review" then Ok (Review { authority = value; minimum_independence = External })
      else Error ("unknown requirement kind: " ^ kind)

let parse_flags o arguments =
  let rec loop acc = function
    | [] -> List.rev acc
    | "--root" :: value :: rest -> o.root <- value; loop acc rest
    | "--json" :: rest -> o.json <- true; loop acc rest
    | "--reason" :: value :: rest -> o.reason <- value; loop acc rest
    | "--by" :: value :: rest -> o.by <- value; loop acc rest
    | "--outcome" :: value :: rest -> o.outcome <- value; loop acc rest
    | "--valid-for" :: value :: rest -> (
        match int_of_string_opt value with
        | Some days -> o.valid_for <- Some days; loop acc rest
        | None -> failwith "--valid-for expects a number of days")
    | "--recovery" :: value :: rest -> o.recovery <- value; loop acc rest
    | "--control" :: value :: rest -> o.control <- value; loop acc rest
    | "--source" :: value :: rest -> o.source <- value; loop acc rest
    | "--requirement" :: value :: rest -> o.requirements <- o.requirements @ [ value ]; loop acc rest
    | "--write" :: rest -> o.write <- true; loop acc rest
    | "--version" :: rest -> o.version <- true; loop acc rest
    | ("--help" | "-h") :: rest -> o.help <- true; loop acc rest
    | option :: _ when String.length option > 0 && option.[0] = '-' -> failwith ("unknown option: " ^ option)
    | argument :: rest -> loop (argument :: acc) rest
  in
  loop [] arguments

let split_scope text =
  String.split_on_char ',' text |> List.map String.trim |> List.filter (fun part -> part <> "")

let parse_all requirements =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | text :: rest -> (
        match parse_requirement text with
        | Ok requirement -> loop (requirement :: acc) rest
        | Error error -> Error error)
  in
  loop [] requirements

let fail code message = Printf.eprintf "mathc: %s\n" message; code

let main () =
  let arguments = Array.to_list Sys.argv |> List.tl in
  let o = options () in
  let positional =
    match parse_flags o arguments with
    | positional -> positional
    | exception Failure message -> exit (fail 2 message)
  in
  let code =
    let topic = match positional with verb :: _ -> Some verb | [] -> None in
    if o.help then Command_help.help topic
    else if o.version then Commands.version ()
    else
      match positional with
    | [] -> Commands.map o.root false
    | "help" :: topic :: _ -> Command_help.help (Some topic)
    | [ "help" ] -> Command_help.help None
    | [ "init" ] -> Commands.init o.root
    | "goal" :: text :: scope :: by :: _ -> Commands.goal o.root text (split_scope scope) by o.reason
    | "add" :: id :: text :: scope :: falsifier :: register :: _ -> (
        match parse_all o.requirements with
        | Error error -> fail 2 error
        | Ok requirements -> Commands.add o.root id text (split_scope scope) falsifier register requirements o.control o.source)
    | [ "run" ] -> Commands.run o.root
    | [ "map" ] -> Commands.map o.root o.json
    | [ "next" ] -> Commands.next o.root
    | [ "context" ] -> Commands.context o.root
    | "waive" :: id :: _ -> Commands.waive o.root id o.by o.reason (Option.value ~default:0 o.valid_for) o.recovery
    | "record" :: id :: authority :: _ -> Commands.record o.root id authority o.by o.outcome o.valid_for None
    | [ "install" ] -> Commands.install o.root
    | [ "doctor" ] -> Commands.doctor o.root
    | [ "adopt" ] -> Adopt.run o.root
    | [ "authorize" ] -> Commands.authorize o.root o.by o.reason
    | [ "re-evaluate" ] -> Commands.re_evaluate o.root
    | "review-source" :: id :: _ -> Commands.review_source o.root id o.by o.reason
    | "import-adr" :: path :: _ -> Adr.import_file o.root path
    | "import-junit" :: path :: _ -> Junit.import_file path
    | [ "mcp" ] -> Mcp.loop ~root:o.root
    | verb :: _ -> fail 2 ("unknown verb: " ^ verb)
  in
  exit code
