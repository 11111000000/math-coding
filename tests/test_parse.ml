(* tests/test_parse.ml — tests for core/parse.ml.

   Covers: frontmatter extraction with mixed quotes, body-section
   detection (including the code-fence trap that previously let
   '## Why' inside a code block count as a dialectic section). *)

open Test_runner

let mk_packet name proposition body_sections =
  let body = String.concat "\n"
    (List.map (fun (h, c) -> Printf.sprintf "## %s\n\n%s" h c) body_sections) in
  Printf.sprintf "---\nschema_version: \"2.1\"\nname: %s\nproposition: %s\nregister: hypothesis\nstate: applied\nactor: human\nconfidence: 0.7\nsuperseded_by:\nbeneficiary: system\nkind: policy\n---\n%s\n" name proposition body

let write_packet name content =
  let dir = Filename.concat "math" name in
  (try Unix.system (Printf.sprintf "rm -rf %s" (Filename.quote dir)) |> ignore with _ -> ());
  Unix.mkdir dir 0o755;
  let oc = open_out (Filename.concat dir "packet.md") in
  output_string oc content;
  close_out oc;
  let oc = open_out (Filename.concat dir "witness") in
  output_string oc "sha: deadbeef\ndate: 2026-01-01\nby: test\n";
  close_out oc

let cleanup name =
  let dir = Filename.concat "math" name in
  try Unix.system (Printf.sprintf "rm -rf %s" (Filename.quote dir)) |> ignore with _ -> ()

let test_parse_basic () =
  Printf.printf "Parse: basic packet\n";
  let name = "_test_basic" in
  write_packet name (mk_packet name "test proposition" []);
  match Parse.parse_packet dir:((Filename.concat "math" name)) with
  | Ok d ->
      assert_eq ~label:"name" (s d.Types.name) (s name);
      assert_eq ~label:"proposition" (s d.Types.proposition) (s "test proposition");
      assert_eq ~label:"register" (v d.Types.register) (v Types.RHypothesis);
      cleanup name
  | Error e ->
      cleanup name;
      failwith ("parse failed: " ^ e)

let test_parse_quoted_proposition () =
  Printf.printf "Parse: quoted proposition with colon\n";
  let name = "_test_quoted" in
  let content = "---\nschema_version: \"2.1\"\nname: q\nproposition: \"a:b\"\nregister: hypothesis\nstate: applied\nactor: human\nconfidence: 0.7\nsuperseded_by:\nbeneficiary: system\nkind: policy\n---\n" in
  write_packet name content;
  match Parse.parse_packet dir:((Filename.concat "math" name)) with
  | Ok d ->
      assert_eq ~label:"quoted-prop" (s d.Types.proposition) (s "a:b");
      cleanup name
  | Error e ->
      cleanup name;
      failwith ("parse failed: " ^ e)

let test_parse_escaped_quote_in_proposition () =
  Printf.printf "Parse: escaped double quote inside proposition\n";
  let name = "_test_escaped" in
  let content = "---\nschema_version: \"2.1\"\nname: e\nproposition: \"a \\\"b\\\" c\"\nregister: hypothesis\nstate: applied\nactor: human\nconfidence: 0.7\nsuperseded_by:\nbeneficiary: system\nkind: policy\n---\n" in
  write_packet name content;
  match Parse.parse_packet dir:((Filename.concat "math" name)) with
  | Ok d ->
      assert_eq ~label:"escaped-quote" (s d.Types.proposition) (s {|a "b" c|});
      cleanup name
  | Error e ->
      cleanup name;
      failwith ("parse failed: " ^ e)

let test_parse_escaped_backslash_in_proposition () =
  Printf.printf "Parse: backslash-quote escapes; double-backslash preserved\n";
  let name = "_test_backslash" in
  let content = "---\nschema_version: \"2.1\"\nname: bs\nproposition: \"a\\\\b\"\nregister: hypothesis\nstate: applied\nactor: human\nconfidence: 0.7\nsuperseded_by:\nbeneficiary: system\nkind: policy\n---\n" in
  write_packet name content;
  match Parse.parse_packet dir:((Filename.concat "math" name)) with
  | Ok d ->
      assert_eq ~label:"backslash" (s d.Types.proposition) (s {|a\\b|});
      cleanup name
  | Error e ->
      cleanup name;
      failwith ("parse failed: " ^ e)

let test_parse_body_section_in_code_fence_is_not_section () =
  Printf.printf "Parse: '## Why' inside a code fence must NOT be a section\n";
  let name = "_test_codefence" in
  let body = "## Why\n\nbecause\n\n```\n## Antithesis\n\nthis is inside a code block\n```\n\n## Synthesis\n\ntherefore\n" in
  let content = "---\nschema_version: \"2.1\"\nname: cf\nproposition: p\nregister: judgment\nstate: applied\nactor: human\nconfidence: 1.0\nsuperseded_by:\nbeneficiary: system\nkind: policy\n---\n" ^ body in
  write_packet name content;
  match Parse.parse_packet dir:((Filename.concat "math" name)) with
  | Ok d ->
      let names = List.map fst d.Types.body_sections in
      let has_antithesis = List.mem "Antithesis" names in
      assert_eq ~label:"antithesis-section" (b has_antithesis) (b false);
      let has_why = List.mem "Why" names in
      let has_synthesis = List.mem "Synthesis" names in
      assert_eq ~label:"why-present" (b has_why) (b true);
      assert_eq ~label:"synthesis-present" (b has_synthesis) (b true);
      cleanup name
  | Error e ->
      cleanup name;
      failwith ("parse failed: " ^ e)

let test_parse_missing_frontmatter () =
  Printf.printf "Parse: missing frontmatter returns Error\n";
  let name = "_test_nofrontmatter" in
  let dir = Filename.concat "math" name in
  (try Unix.system (Printf.sprintf "rm -rf %s" (Filename.quote dir)) |> ignore with _ -> ());
  Unix.mkdir dir 0o755;
  let oc = open_out (Filename.concat dir "packet.md") in
  output_string oc "no frontmatter here\n";
  close_out oc;
  (match Parse.parse_packet dir:dir with
   | Ok _ -> cleanup name; failwith "expected Error"
   | Error _ -> cleanup name)

let run () =
  test_parse_basic ();
  test_parse_quoted_proposition ();
  test_parse_escaped_quote_in_proposition ();
  test_parse_escaped_backslash_in_proposition ();
  test_parse_body_section_in_code_fence_is_not_section ();
  test_parse_missing_frontmatter ();
  summary ()
