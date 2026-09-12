(* lib/probe.ml — axiom Self-Application probe. *)

open Packet
open Check

let axiom_packets dir =
  let rec loop acc = function
    | [] -> List.rev acc
    | entry :: rest ->
        let name = Filename.basename entry in
        let path = Filename.concat entry "packet.md" in
        let full_path = Filename.concat dir name in
        if Sys.is_directory full_path && Sys.file_exists path then
          loop (name :: acc) rest
        else
          loop acc rest
  in
  let entries =
    try Sys.readdir dir with Sys_error _ -> []
  in
  loop [] (Array.to_list entries)

let load_axiom_packet name path =
  let packet_md = Filename.concat path "packet.md" in
  let ic = open_in packet_md in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  let pkt = Parse.parse_packet name path content in
  { pkt with axiom = Some ("A" ^ String.sub name 0 1) }

let probe math_dir git =
  let axioms = axiom_packets math_dir in
  let verdicts = ref [] in
  List.iter (fun name ->
    let path = Filename.concat math_dir name in
    let pkt = load_axiom_packet name path in
    let pkt_verdicts = check git pkt in
    verdicts := !verdicts @ pkt_verdicts
  ) axioms;
  !verdicts
