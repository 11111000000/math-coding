(* lib/check.ml — packet verification for math-coding v1.0. *)

open Packet

type verdict =
  | Pass of string
  | Warn of string
  | Fail of string
  | Skip of string

let check_structure pkt =
  let verdicts = ref [] in
  if pkt.proposition = "" then
    verdicts := Fail "missing proposition" :: !verdicts
  else
    verdicts := Pass "proposition present" :: !verdicts;
  let files_dir = Sys.file_exists pkt.path in
  if files_dir then
    verdicts := Pass "packet directory exists" :: !verdicts
  else
    verdicts := Fail "packet directory missing" :: !verdicts;
  List.rev !verdicts

let check_files_exist pkt =
  let rec check = function
    | [] -> [Pass "all files exist"]
    | f :: rest ->
        if Sys.file_exists (Filename.concat pkt.path f) then
          check rest
        else
          [Fail ("file missing: " ^ f)]
  in
  check pkt.files

let check_lifecycle git pkt =
  let computed = Lifecycle.compute_lifecycle git pkt in
  match pkt.status with
  | Some explicit when explicit <> computed ->
      [Warn (Printf.sprintf "status %s overrides computed %s"
        (lifecycle_to_string explicit) (lifecycle_to_string computed))]
  | Some _ -> [Pass "status matches computation"]
  | None ->
      [Pass (Printf.sprintf "computed lifecycle: %s"
        (lifecycle_to_string computed))]
and lifecycle_to_string = function
  | Draft -> "draft"
  | Applied -> "applied"
  | Drift -> "drift"
  | Stale -> "stale"
  | Retired -> "retired"
  | Abandoned -> "abandoned"

let check_substrate pkt =
  let path = pkt.path in
  match pkt.substrate with
  | None -> [Pass "substrate: none (no executable check)"]
  | Shell ->
      let run_sh = Filename.concat path "run.sh" in
      if Sys.file_exists run_sh then
        [Pass "substrate: shell, run.sh present"]
      else
        [Fail "substrate: shell, but run.sh missing"]
  | Pbt ->
      let props_dir = Filename.concat path "properties" in
      if Sys.file_exists props_dir && Sys.is_directory props_dir then
        [Pass "substrate: pbt, properties/ present"]
      else
        [Fail "substrate: pbt, but properties/ missing"]
  | Tla ->
      let tla_dir = Filename.concat path "tla" in
      if Sys.file_exists tla_dir then
        [Pass "substrate: tla+, tla/ present"]
      else
        [Fail "substrate: tla+, but tla/ missing"]
  | Coq ->
      let coq_dir = Filename.concat path "coq" in
      if Sys.file_exists coq_dir then
        [Pass "substrate: coq, coq/ present"]
      else
        [Fail "substrate: coq, but coq/ missing"]
  | Alloy ->
      let alloy_dir = Filename.concat path "alloy" in
      if Sys.file_exists alloy_dir then
        [Pass "substrate: alloy, alloy/ present"]
      else
        [Fail "substrate: alloy, but alloy/ missing"]
  | Bpmn ->
      let bpmn_dir = Filename.concat path "bpmn" in
      if Sys.file_exists bpmn_dir then
        [Pass "substrate: bpmn, bpmn/ present"]
      else
        [Fail "substrate: bpmn, but bpmn/ missing"]
  | PbtPrism ->
      let props_dir = Filename.concat path "properties" in
      if Sys.file_exists props_dir then
        [Pass "substrate: pbt-prism, properties/ present"]
      else
        [Skip "substrate: pbt-prism, no properties/ yet"]

let check_witness pkt =
  match pkt.witness with
  | [] -> [Warn "no witness; lifecycle is draft"]
  | entries ->
      let all_valid =
        List.for_all (fun e -> Git.sha_exists e.sha) entries
      in
      if all_valid then
        [Pass (Printf.sprintf "witness: %d entries, all valid"
          (List.length entries))]
      else
        [Fail "witness contains invalid SHA"]

let check_epistemics pkt =
  let check_one ep =
    match ep.marker, ep.evidence with
    | Proven, None ->
        Fail (Printf.sprintf "proven marker without evidence: %s" ep.statement)
    | Proven, Some (Command c) ->
        let cmd = Printf.sprintf "sh -c '%s' >/dev/null 2>&1; echo $?" c.command in
        let ic = Unix.open_process_in cmd in
        let line = try input_line ic with End_of_file -> "" in
        close_in ic;
        let rc = try int_of_string (String.trim line) with _ -> -1 in
        if rc = c.recorded_exit then
          Pass (Printf.sprintf "proven reproduced: %s" c.command)
        else
          Fail (Printf.sprintf "proven NOT reproduced (got %d, expected %d): %s"
            rc c.recorded_exit c.command)
    | Proven, Some _ ->
        Warn (Printf.sprintf "proven with non-command evidence: %s" ep.statement)
    | Fact, None ->
      Warn (Printf.sprintf "fact without evidence: %s" ep.statement)
    | Fact, Some _ ->
      Pass (Printf.sprintf "fact with evidence: %s" ep.statement)
    | _ ->
      Pass (Printf.sprintf "%s marker: %s"
        (marker_to_string ep.marker) ep.statement)
  in
  List.map check_one pkt.epistemics

let check git pkt =
  let verdicts = ref [] in
  verdicts := !verdicts @ check_structure pkt;
  verdicts := !verdicts @ check_files_exist pkt;
  verdicts := !verdicts @ check_lifecycle git pkt;
  verdicts := !verdicts @ check_substrate pkt;
  verdicts := !verdicts @ check_witness pkt;
  !verdicts
