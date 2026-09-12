(* test/test_properties.ml — QCheck properties for math-coding v1.0. *)

(* Property 1: substrate_of_string is inverse of substrate_to_string. *)
let prop_substrate_inverse () =
  QCheck.(
    test ~count:100
      (oneofl ["none"; "shell"; "tla+"; "coq"; "alloy"; "pbt"; "bpmn"; "pbt-prism"])
      (fun s ->
        Packet.substrate_to_string (Packet.substrate_of_string s) = s))

(* Property 2: marker_of_string is inverse of marker_to_string. *)
let prop_marker_inverse () =
  QCheck.(
    test ~count:100
      (oneofl ["fact"; "hypothesis"; "judgment"; "unknown"; "proven"])
      (fun s ->
        Packet.marker_to_string (Packet.marker_of_string s) = s))

(* Property 3: all 8 substrate values are distinct. *)
let prop_substrate_distinct () =
  let strs = List.map Packet.substrate_to_string
    [Packet.None; Packet.Shell; Packet.Tla; Packet.Coq; Packet.Alloy; Packet.Pbt; Packet.Bpmn; Packet.PbtPrism]
  in
  QCheck.(
    test ~count:1 (always_passes)
      (fun () ->
        List.length (List.sort_uniq String.compare strs) = List.length strs))

(* Property 4: parse preserves proposition. *)
let prop_parse_proposition () =
  QCheck.(
    test ~count:100 (string ~print:Print.first_quote ())
      (fun s ->
        let escaped = String.escaped s in
        let content = Printf.sprintf "---\nproposition: \"%s\"\n---\n" escaped in
        let pkt = Packet.Parse.parse_packet "test" "/tmp/test" content in
        pkt.Packet.proposition = s))

let () =
  QCheck.run [
    QCheck.Test.make ~name:"substrate_inverse" ~count:100 prop_substrate_inverse;
    QCheck.Test.make ~name:"marker_inverse" ~count:100 prop_marker_inverse;
    QCheck.Test.make ~name:"substrate_distinct" ~count:1 prop_substrate_distinct;
    QCheck.Test.make ~name:"parse_proposition" ~count:100 prop_parse_proposition;
  ]
