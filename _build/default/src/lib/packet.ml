(* lib/packet.ml — packet model and parsing for math-coding v1.0. *)

type substrate =
  | None
  | Shell
  | Tla
  | Coq
  | Alloy
  | Pbt
  | Bpmn
  | PbtPrism

let substrate_of_string = function
  | "none" -> None
  | "shell" -> Shell
  | "tla+" -> Tla
  | "coq" -> Coq
  | "alloy" -> Alloy
  | "pbt" -> Pbt
  | "bpmn" -> Bpmn
  | "pbt-prism" -> PbtPrism
  | s -> failwith ("unknown substrate: " ^ s)

let substrate_to_string = function
  | None -> "none"
  | Shell -> "shell"
  | Tla -> "tla+"
  | Coq -> "coq"
  | Alloy -> "alloy"
  | Pbt -> "pbt"
  | Bpmn -> "bpmn"
  | PbtPrism -> "pbt-prism"

type marker =
  | Fact
  | Hypothesis
  | Judgment
  | Unknown
  | Proven

let marker_of_string = function
  | "fact" -> Fact
  | "hypothesis" -> Hypothesis
  | "judgment" -> Judgment
  | "unknown" -> Unknown
  | "proven" -> Proven
  | s -> failwith ("unknown marker: " ^ s)

let marker_to_string = function
  | Fact -> "fact"
  | Hypothesis -> "hypothesis"
  | Judgment -> "judgment"
  | Unknown -> "unknown"
  | Proven -> "proven"

type evidence =
  | Command of {
      command : string;
      recorded_exit : int;
      recorded_at : string;
    }
  | Git of { sha : string; file : string }
  | File of { path : string }
  | Text of string

type epistemic = {
  statement : string;
  marker : marker;
  evidence : evidence option;
}

type witness_kind =
  | Amendment
  | Supersession

type witness_entry = {
  sha : string;
  date : string;
  kind : witness_kind;
  files : string list;
  superseded_by : string option;
}

type lifecycle =
  | Draft
  | Applied
  | Drift
  | Stale
  | Retired
  | Abandoned

type packet = {
  name : string;
  path : string;
  proposition : string;
  antithesis : string option;
  synthesis : string option;
  intent : string option;
  files : string list;
  substrate : substrate;
  status : lifecycle option;
  witness : witness_entry list;
  epistemics : epistemic list;
  axiom : string option;
  superseded_by : string option;
  body : string;
}

let empty_packet name path = {
  name;
  path;
  proposition = "";
  antithesis = None;
  synthesis = None;
  intent = None;
  files = [];
  substrate = None;
  status = None;
  witness = [];
  epistemics = [];
  axiom = None;
  superseded_by = None;
  body = "";
}
