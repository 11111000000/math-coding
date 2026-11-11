let command_help = function
  | "init" -> "init: create an empty spec.json; refuses to overwrite an existing specification."
  | "goal" -> "goal AIM SCOPE OWNER [--reason WHY]; SCOPE is comma-separated. Replacing an existing goal requires --reason."
  | "add" -> "add ID TEXT SCOPE FALSIFIER REGISTER --requirement verifier:CMD|review:WHO [--control CMD] [--source PATH]; REGISTER is fact, hypothesis, judgment or unknown; SCOPE is comma-separated."
  | "run" -> "run: execute declared verifiers and negative controls, then bind evidence. Exit 0 green, 1 refuted/protected, 3 unknown."
  | "map" -> "map [--json]: show the verdict, claim states, uncovered files and next action. Exit 0 green, 1 red, 3 unknown/vacant."
  | "next" -> "next: print exactly one next action. Exit 0 when an action can be printed."
  | "context" -> "context: print the bounded task context as JSON. Exit 0 on success, 3 when unknown."
  | "waive" -> "waive ID --by WHO --reason WHY --valid-for DAYS --recovery ACTION; DAYS is a positive number of days. A waiver is never a pass and cannot cover a refuted claim."
  | "record" -> "record ID AUTHORITY --by WHO --outcome OUTCOME [--valid-for DAYS]; OUTCOME is pass, fail, inconclusive, infrastructure-error or not-run. The claim must declare review:AUTHORITY."
  | "install" -> "install: update only the math-coding block in this project's AGENTS.md; it does not install binaries."
  | "doctor" -> "doctor: check git, specification, aim, protected policy and the agent page without changing them."
  | "adopt" -> "adopt: detect ADR and specification source directories read-only."
  | "import-adr" -> "import-adr PATH: read a MADR/adr-tools document and print a draft claim; the source and spec.json are not changed."
  | "import-junit" -> "import-junit PATH: parse a JUnit XML report and print exact test and failure counts."
  | "authorize" -> "authorize --by WHO --reason WHY: record authorization for current protected changes when policy.json exists; this is a journal, not authentication."
  | "re-evaluate" -> "re-evaluate: list claims whose source, definition or evidence requires review."
  | "review-source" -> "review-source ID --by OWNER --reason WHY: bind a changed source after human review; records the previous digest, clears waiver and still requires a fresh run."
  | "mcp" -> "mcp: serve the JSON-RPC tool surface over stdio."
  | _ -> ""

let help topic =
  print_endline {|mathc 5 - source-linked, fresh and independent evidence

Usage: mathc [--root DIR] COMMAND [ARGS]

Start a project:
  mathc adopt
  mathc init
  mathc goal "AIM" "SCOPE[,SCOPE]" "OWNER"
  mathc add ID "TEXT" "SCOPE" "FALSIFIER" fact \
    --requirement "verifier:CMD" --control "BREAK_SUBJECT" [--source ADR]
  mathc run
  mathc map | mathc next | mathc context

Sources and evidence:
  mathc import-adr PATH | mathc import-junit PATH
  mathc re-evaluate
  mathc review-source ID --by OWNER --reason "WHY"

Human decisions (record only what a person actually decided):
  mathc record ID AUTHORITY --by WHO --outcome OUTCOME
  mathc waive ID --by WHO --reason WHY --valid-for DAYS --recovery ACTION
  mathc authorize --by WHO --reason WHY

Other commands:
  mathc install              update only the math-coding block in AGENTS.md
  mathc doctor               check setup without changing it
  mathc mcp                  JSON-RPC over stdio
  mathc help [COMMAND] | mathc --help
  mathc --version

Local binary and agent-skill installation: ./install.sh

Exit codes:
  successful actions and next/context  0
  run/map verdict green                0
  run/map verdict red or protected     1
  usage error                          2
  unknown/vacant/uncomputable          3
|};
  match topic with
  | None -> 0
  | Some command ->
      let details = command_help command in
      if details = "" then (
        Printf.eprintf "mathc: no help for command: %s\n" command;
        2)
      else (
        Printf.printf "\n%s\n" details;
        0)
