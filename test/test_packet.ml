(* test/test_packet.ml — tests for packet types and lifecycle. *)

let test_substrate_of_string () =
  let open Packet in
  Alcotest.(check string) "None" "none" (substrate_to_string (substrate_of_string "none"));
  Alcotest.(check string) "Shell" "shell" (substrate_to_string (substrate_of_string "shell"));
  Alcotest.(check string) "Tla" "tla+" (substrate_to_string (substrate_of_string "tla+"));
  Alcotest.(check string) "Coq" "coq" (substrate_to_string (substrate_of_string "coq"));
  Alcotest.(check string) "Alloy" "alloy" (substrate_to_string (substrate_of_string "alloy"));
  Alcotest.(check string) "Pbt" "pbt" (substrate_to_string (substrate_of_string "pbt"));
  Alcotest.(check string) "Bpmn" "bpmn" (substrate_to_string (substrate_of_string "bpmn"));
  Alcotest.(check string) "PbtPrism" "pbt-prism"
    (substrate_to_string (substrate_of_string "pbt-prism"))

let test_marker_of_string () =
  let open Packet in
  Alcotest.(check string) "Fact" "fact" (marker_to_string (marker_of_string "fact"));
  Alcotest.(check string) "Proven" "proven" (marker_to_string (marker_of_string "proven"))

let test_parse_packet_frontmatter () =
  let content = "---\nproposition: \"test\"\nantithesis: \"alt\"\n---\n\n## Antithesis\n\nalt\n" in
  let pkt = Packet.Parse.parse_packet "test" "/tmp/test" content in
  Alcotest.(check string) "name" "test" pkt.Packet.name;
  Alcotest.(check string) "proposition" "test" pkt.Packet.proposition;
  Alcotest.(check (option string)) "antithesis" (Some "alt") pkt.Packet.antithesis

let test_lifecycle_no_witness () =
  let pkt = Packet.empty_packet "test" "/tmp/test" in
  let lifecycle = Packet.Lifecycle.compute_lifecycle () pkt in
  Alcotest.(check (option Packet.lifecycle)) "no witness" None lifecycle

let () =
  Alcotest.run "math-coding v1.0" [
    "substrate", [
      Alcotest.test_case "of_string" `Quick test_substrate_of_string;
    ];
    "marker", [
      Alcotest.test_case "of_string" `Quick test_marker_of_string;
    ];
    "parse", [
      Alcotest.test_case "frontmatter" `Quick test_parse_packet_frontmatter;
    ];
    "lifecycle", [
      Alcotest.test_case "no_witness" `Quick test_lifecycle_no_witness;
    ];
  ]
