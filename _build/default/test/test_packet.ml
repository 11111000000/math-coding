(* test/test_packet.ml — tests for packet types and lifecycle. *)

module P = Math_coding_lib.Packet

let test_substrate_of_string () =
  Alcotest.(check string) "None" "none"
    (P.substrate_to_string (P.substrate_of_string "none"));
  Alcotest.(check string) "Shell" "shell"
    (P.substrate_to_string (P.substrate_of_string "shell"));
  Alcotest.(check string) "Tla" "tla+"
    (P.substrate_to_string (P.substrate_of_string "tla+"));
  Alcotest.(check string) "Coq" "coq"
    (P.substrate_to_string (P.substrate_of_string "coq"));
  Alcotest.(check string) "Alloy" "alloy"
    (P.substrate_to_string (P.substrate_of_string "alloy"));
  Alcotest.(check string) "Pbt" "pbt"
    (P.substrate_to_string (P.substrate_of_string "pbt"));
  Alcotest.(check string) "Bpmn" "bpmn"
    (P.substrate_to_string (P.substrate_of_string "bpmn"));
  Alcotest.(check string) "PbtPrism" "pbt-prism"
    (P.substrate_to_string (P.substrate_of_string "pbt-prism"))

let test_marker_of_string () =
  Alcotest.(check string) "Fact" "fact"
    (P.marker_to_string (P.marker_of_string "fact"));
  Alcotest.(check string) "Proven" "proven"
    (P.marker_to_string (P.marker_of_string "proven"))

let test_parse_packet_frontmatter () =
  let content = "---\nproposition: \"test\"\nantithesis: \"alt\"\n---\n\n## Antithesis\n\nalt\n" in
  let pkt = Math_coding_lib.Parse.parse_packet "test" "/tmp/test" content in
  Alcotest.(check string) "name" "test" pkt.P.name;
  Alcotest.(check string) "proposition" "test" pkt.P.proposition;
  Alcotest.(check (option string)) "antithesis" (Some "alt") pkt.P.antithesis

let test_parse_inline_list () =
  let content = "---\nproposition: \"test\"\nfiles: [src/foo.ml, src/bar.ml]\n---\n" in
  let pkt = Math_coding_lib.Parse.parse_packet "test" "/tmp/test" content in
  Alcotest.(check (list string)) "files parsed from inline list"
    ["src/foo.ml"; "src/bar.ml"] pkt.P.files

let test_parse_comma_list () =
  let content = "---\nproposition: \"test\"\nfiles: src/foo.ml, src/bar.ml\n---\n" in
  let pkt = Math_coding_lib.Parse.parse_packet "test" "/tmp/test" content in
  Alcotest.(check (list string)) "files parsed from comma list"
    ["src/foo.ml"; "src/bar.ml"] pkt.P.files

let test_parse_empty_brackets () =
  let content = "---\nproposition: \"test\"\nfiles: []\n---\n" in
  let pkt = Math_coding_lib.Parse.parse_packet "test" "/tmp/test" content in
  Alcotest.(check (list string)) "files parsed from empty brackets" [] pkt.P.files

let test_lifecycle_no_witness () =
  let pkt = P.empty_packet "test" "/tmp/test" in
  let _lifecycle = Math_coding_lib.Lifecycle.compute_lifecycle pkt in
  ()

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
      Alcotest.test_case "inline_list" `Quick test_parse_inline_list;
      Alcotest.test_case "comma_list" `Quick test_parse_comma_list;
      Alcotest.test_case "empty_brackets" `Quick test_parse_empty_brackets;
    ];
    "lifecycle", [
      Alcotest.test_case "no_witness" `Quick test_lifecycle_no_witness;
    ];
  ]
