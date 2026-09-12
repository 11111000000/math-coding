(* main.ml — math-coding v1.0 CLI dispatcher. *)

let version = "0.1.0"

let usage = "usage: math-coding <command> [args]

Commands:
  packet create <name> --proposition=\"...\"
  packet edit <name> [--proposition=...] [--antithesis=...]
  packet show <name>
  packet list
  packet substrate <name> <level>

  check                 [--epistemics] [--json]
  drift
  probe
  install
  upgrade
  version
  help"

let packet_create name proposition antithesis synthesis intent =
  Printf.printf "create packet: %s\n" name;
  Printf.printf "  proposition: %s\n" proposition;
  (match antithesis with
   | Some s -> Printf.printf "  antithesis: %s\n" s
   | None -> ());
  (match synthesis with
   | Some s -> Printf.printf "  synthesis: %s\n" s
   | None -> ());
  (match intent with
   | Some s -> Printf.printf "  intent: %s\n" s
   | None -> ());
  let path = Filename.concat "math" name in
  if Sys.file_exists path then begin
    Printf.printf "error: %s exists\n" path;
    exit 1
  end;
  Unix.mkdir path 0o755;
  let oc = open_out (Filename.concat path "packet.md") in
  Printf.fprintf oc "---\n";
  Printf.fprintf oc "proposition: \"%s\"\n" proposition;
  (match antithesis with
   | Some s -> Printf.fprintf oc "antithesis: \"%s\"\n" s
   | None -> ());
  (match synthesis with
   | Some s -> Printf.fprintf oc "synthesis: \"%s\"\n" s
   | None -> ());
  (match intent with
   | Some s -> Printf.fprintf oc "intent: \"%s\"\n" s
   | None -> ());
  Printf.fprintf oc "---\n\n";
  (match antithesis with
   | Some s -> Printf.fprintf oc "## Antithesis\n\n%s\n\n" s
   | None -> ());
  (match synthesis with
   | Some s -> Printf.fprintf oc "## Synthesis\n\n%s\n\n" s
   | None -> ());
  (match intent with
   | Some s -> Printf.fprintf oc "## Intent\n\n%s\n\n" s
   | None -> ());
  close_out oc;
  let oc = open_out (Filename.concat path "witness") in
  close_out oc;
  Printf.printf "created: %s/packet.md\n" path;
  Printf.printf "created: %s/witness\n" path

let load_packet name =
  let path = Filename.concat "math" name in
  let packet_md = Filename.concat path "packet.md" in
  if not (Sys.file_exists packet_md) then begin
    Printf.printf "error: %s not found\n" packet_md;
    exit 1
  end;
  let ic = open_in packet_md in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Math_coding_lib.Parse.parse_packet name path content

let packet_show name =
  let pkt = load_packet name in
  Printf.printf "name: %s\n" pkt.name;
  Printf.printf "path: %s\n" pkt.path;
  Printf.printf "proposition: %s\n" pkt.proposition;
  Printf.printf "substrate: %s\n"
    (Math_coding_lib.Packet.substrate_to_string pkt.substrate);
  Printf.printf "files: [%s]\n"
    (String.concat ", " pkt.files);
  (match pkt.axiom with
   | Some s -> Printf.printf "axiom: %s\n" s
   | None -> ());
  Printf.printf "witness entries: %d\n"
    (List.length pkt.witness)

let packet_list () =
  let dir = "math" in
  if not (Sys.file_exists dir) then begin
    Printf.printf "no math/ directory\n";
    exit 1
  end;
  let entries =
    try Sys.readdir dir
    with Sys_error _ -> [||]
  in
  Array.iter (fun name ->
    let path = Filename.concat dir name in
    if Sys.is_directory path then begin
      let packet_md = Filename.concat path "packet.md" in
      if Sys.file_exists packet_md then
        Printf.printf "  %s\n" name
    end
  ) entries

let run_check epistemic _json =
  let math_dir = "math" in
  if not (Sys.file_exists math_dir) then begin
    Printf.printf "no math/ directory\n";
    exit 1
  end;
  let entries =
    try Sys.readdir math_dir
    with Sys_error _ -> [||]
  in
  let total_pass = ref 0 in
  let total_fail = ref 0 in
  let total_warn = ref 0 in
  let total_skip = ref 0 in
  Array.iter (fun name ->
    let path = Filename.concat math_dir name in
    let packet_md = Filename.concat path "packet.md" in
    if Sys.is_directory path && Sys.file_exists packet_md then begin
      let pkt = load_packet name in
      let verdicts = Math_coding_lib.Check.check pkt in
      let epistemics =
        if epistemic then Math_coding_lib.Check.check_epistemics pkt else []
      in
      let all = verdicts @ epistemics in
      Printf.printf "%s:\n" name;
      List.iter (fun v ->
        match v with
        | Math_coding_lib.Check.Pass s ->
            Printf.printf "  PASS: %s\n" s; incr total_pass
        | Math_coding_lib.Check.Warn s ->
            Printf.printf "  WARN: %s\n" s; incr total_warn
        | Math_coding_lib.Check.Fail s ->
            Printf.printf "  FAIL: %s\n" s; incr total_fail
        | Math_coding_lib.Check.Skip s ->
            Printf.printf "  SKIP: %s\n" s; incr total_skip
      ) all
    end
  ) entries;
  Printf.printf "\nsummary: %d pass, %d warn, %d fail, %d skip\n"
    !total_pass !total_warn !total_fail !total_skip;
  if !total_fail > 0 then exit 1

let run_drift () =
  let math_dir = "math" in
  if not (Sys.file_exists math_dir) then begin
    Printf.printf "no math/ directory\n";
    exit 1
  end;
  let entries =
    try Sys.readdir math_dir
    with Sys_error _ -> [||]
  in
  let drift_count = ref 0 in
  Array.iter (fun name ->
    let path = Filename.concat math_dir name in
    let packet_md = Filename.concat path "packet.md" in
    if Sys.is_directory path && Sys.file_exists packet_md then begin
      let pkt = load_packet name in
      let lifecycle = Math_coding_lib.Lifecycle.compute_lifecycle pkt in
      match lifecycle with
      | Math_coding_lib.Packet.Drift ->
          Printf.printf "drift: %s\n" name;
          incr drift_count
      | _ -> ()
    end
  ) entries;
  Printf.printf "drift count: %d\n" !drift_count;
  if !drift_count > 0 then exit 1

let run_probe () =
  let math_dir = "math" in
  if not (Sys.file_exists math_dir) then begin
    Printf.printf "no math/ directory\n";
    exit 1
  end;
  let verdicts = Math_coding_lib.Probe.probe math_dir in
  let total_pass = ref 0 in
  let total_fail = ref 0 in
  List.iter (fun v ->
    match v with
    | Math_coding_lib.Check.Pass s ->
        Printf.printf "PASS: %s\n" s; incr total_pass
    | Math_coding_lib.Check.Fail s ->
        Printf.printf "FAIL: %s\n" s; incr total_fail
    | _ -> ()
  ) verdicts;
  Printf.printf "\nprobe: %d pass, %d fail\n" !total_pass !total_fail;
  if !total_fail > 0 then exit 1

let run_install () =
  Printf.printf "build with: sh scripts/install.sh\n"

let run_upgrade () =
  Printf.printf "rebuild with: sh scripts/install.sh\n"

let rec parse_proposition = function
  | [] -> ("", None, None, None)
  | "--proposition" :: p :: rest ->
      let antithesis, synthesis, intent = parse_optional rest in
      (p, antithesis, synthesis, intent)
  | _ :: rest -> parse_proposition rest
and parse_optional = function
  | [] -> (None, None, None)
  | "--antithesis" :: s :: rest ->
      let syn, intent = parse_syn_int rest in
      (Some s, syn, intent)
  | "--synthesis" :: s :: rest ->
      let intent = parse_int rest in
      (None, Some s, intent)
  | "--intent" :: s :: _ -> (None, None, Some s)
  | _ :: rest -> parse_optional rest
and parse_syn_int = function
  | [] -> (None, None)
  | "--synthesis" :: s :: rest ->
      let intent = parse_int rest in
      (Some s, intent)
  | "--intent" :: s :: _ -> (None, Some s)
  | _ :: rest -> parse_syn_int rest
and parse_int = function
  | [] -> None
  | "--intent" :: s :: _ -> Some s
  | _ :: rest -> parse_int rest

let () =
  let args = Array.to_list Sys.argv in
  match args with
  | _ :: "version" :: _ -> Printf.printf "math-coding %s\n" version
  | _ :: "help" :: _
  | _ :: "--help" :: _
  | _ :: "-h" :: _ -> Printf.printf "%s\n" usage
  | _ :: "packet" :: "create" :: name :: rest ->
      let prop, ant, syn, intent = parse_proposition rest in
      packet_create name prop ant syn intent
  | _ :: "packet" :: "show" :: name :: _ ->
      packet_show name
  | _ :: "packet" :: "list" :: _ ->
      packet_list ()
  | _ :: "check" :: rest ->
      let epistemic = List.mem "--epistemics" rest in
      let json = List.mem "--json" rest in
      run_check epistemic json
  | _ :: "drift" :: _ -> run_drift ()
  | _ :: "probe" :: _ -> run_probe ()
  | _ :: "install" :: _ -> run_install ()
  | _ :: "upgrade" :: _ -> run_upgrade ()
  | _ -> Printf.printf "%s\n" usage
