(* The page for agents: the block that names the verbs of the method and the
   aim of the project. The install verb writes the block and the doctor checks
   it, so both of them read it from here. *)

let block_begin = "<!-- math-coding:begin -->"
let block_end = "<!-- math-coding:end -->"

let usage_verbs = [ "help"; "init"; "goal"; "add"; "run"; "map"; "next"; "context"; "waive"; "record"; "install"; "doctor"; "adopt"; "import-adr"; "import-junit"; "authorize"; "approve"; "re-evaluate"; "review-source"; "mcp" ]

(* The text of the block: the aim of the project, the number of its claims and
   the verbs of the method. *)
let entry_page (spec : Domain.spec) =
  let claims = List.length spec.claims in
  let goal = match spec.goal with Some goal -> goal.text | None -> "No aim is stated yet." in
  Printf.sprintf
    "## math-coding in this project\n\n%s\n\n%d claim(s).\n\n```sh\nmathc run\n```\n\nEvery verb: %s\n"
    goal claims (String.concat " " (List.map (fun verb -> "mathc " ^ verb) usage_verbs))

let index_of haystack needle =
  let n = String.length haystack and m = String.length needle in
  let found = ref None and index = ref 0 in
  while !found = None && !index + m <= n do
    if String.sub haystack !index m = needle then found := Some !index;
    incr index
  done;
  !found

let contains haystack needle = index_of haystack needle <> None

(* The block of the page is replaced, not appended: a page that was written by
   an earlier version of the method keeps its own text and gets the current
   block. *)
let with_block existing block =
  match index_of existing block_begin with
  | None -> (if existing = "" then block else existing ^ "\n" ^ block)
  | Some first -> (
      match index_of (String.sub existing (first + String.length block_begin)
                         (String.length existing - first - String.length block_begin)) block_end with
      | None -> existing ^ "\n" ^ block
      | Some last ->
          let last = first + String.length block_begin + last in
          let tail = String.sub existing (last + String.length block_end)
              (String.length existing - last - String.length block_end) in
          let tail = if String.length tail > 0 && tail.[0] = '\n' then String.sub tail 1 (String.length tail - 1) else tail in
          String.sub existing 0 first ^ block ^ tail)
