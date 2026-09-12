(* test/test_properties.ml — QCheck properties for math-coding v1.0. *)

module P = Math_coding_lib.Packet

let prop_substrate_inverse s =
  P.substrate_to_string (P.substrate_of_string s) = s

let prop_marker_inverse s =
  P.marker_to_string (P.marker_of_string s) = s

let prop_substrate_distinct () =
  let strs = List.map P.substrate_to_string
    [P.None; P.Shell; P.Tla; P.Coq; P.Alloy; P.Pbt; P.Bpmn; P.PbtPrism]
  in
  List.length (List.sort_uniq String.compare strs) = List.length strs

let prop_parse_proposition s =
  if String.length s > 0 && String.length s < 100 then begin
    let escaped = String.escaped s in
    let content = Printf.sprintf "---\nproposition: \"%s\"\n---\n" escaped in
    let _ = Math_coding_lib.Parse.parse_packet "test" "/tmp/test" content in
    true
  end else true

let substrate_gen = QCheck2.Gen.oneof_list
  ["none"; "shell"; "tla+"; "coq"; "alloy"; "pbt"; "bpmn"; "pbt-prism"]

let marker_gen = QCheck2.Gen.oneof_list
  ["fact"; "hypothesis"; "judgment"; "unknown"; "proven"]

let tests =
  [
    QCheck2.Test.make ~name:"substrate_inverse" ~count:100
      substrate_gen prop_substrate_inverse;
    QCheck2.Test.make ~name:"marker_inverse" ~count:100
      marker_gen prop_marker_inverse;
    QCheck2.Test.make ~name:"substrate_distinct" ~count:1
      substrate_gen (fun _ -> prop_substrate_distinct ());
    QCheck2.Test.make ~name:"parse_proposition" ~count:100
      QCheck2.Gen.string prop_parse_proposition;
  ]

let () = ignore (QCheck_runner.run_tests ~verbose:true tests)
