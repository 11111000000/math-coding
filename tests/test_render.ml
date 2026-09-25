(* tests/test_render.ml — tests for core/render.ml.

   Covers rewrite_md_links, the post-processor that lowercases
   href paths for GitHub Pages. Critical to test because:
     - previous version was hand-rolled byte scanner with dead code
     - lowercase must NOT touch anchor fragments (#Foo preserved)
     - empty href and query strings must round-trip *)

open Test_runner

let test_lower_plain_href () =
  Printf.printf "rewrite: plain href is lowercased\n";
  let inp = {|href="MANIFESTO.html"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"plain" (s out) (s {|href="manifesto.html"|})

let test_lower_preserves_anchor () =
  Printf.printf "rewrite: anchor after # is preserved\n";
  let inp = {|href="MANIFESTO.html#Section-Title"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"anchor" (s out) (s {|href="manifesto.html#Section-Title"|})

let test_lower_preserves_query () =
  Printf.printf "rewrite: query after ? is preserved\n";
  let inp = {|href="MANIFESTO.html?Key=Value"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"query" (s out) (s {|href="manifesto.html?Key=Value"|})

let test_lower_handles_query_before_fragment () =
  Printf.printf "rewrite: query and anchor both preserved\n";
  let inp = {|href="FOO.html?x=1#Bar"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"query-anchor" (s out) (s {|href="foo.html?x=1#Bar"|})

let test_rewrite_md_extension () =
  Printf.printf "rewrite: .md links become .html (and lowercase follows)\n";
  let inp = {|href="README.md"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"md-ext" (s out) (s {|href="readme.html"|})

let test_rewrite_math_modeling_to_manifesto () =
  Printf.printf "rewrite: math/modeling/* collapses to manifesto.html\n";
  let inp = {|href="math/modeling/syntax.tex"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"modeling" (s out) (s {|href="manifesto.html"|})

let test_rewrite_license_to_root () =
  Printf.printf "rewrite: LICENSE becomes root anchor\n";
  let inp = {|href="LICENSE"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"license" (s out) (s {|href="#"|})

let test_rewrite_multiple_in_one_string () =
  Printf.printf "rewrite: multiple hrefs in one string\n";
  let inp = {|a <a href="A.html">a</a> <a href="B.html#X">b</a>|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"multi" (s out)
    (s {|a <a href="a.html">a</a> <a href="b.html#X">b</a>|})

let test_rewrite_already_lowercase_passthrough () =
  Printf.printf "rewrite: already lowercase passes through unchanged\n";
  let inp = {|href="already-lowercase.html"|} in
  let out = Render.rewrite_md_links inp in
  assert_eq ~label:"passthrough" (s out) (s inp)

(* --- render_packet_body markdown support --- *)

let test_body_h3 () =
  Printf.printf "body: '## Heading' renders as h3\n";
  let out = Render.render_packet_body "## Hello\n\nbody text\n" in
  let has = String.contains out '<' && String.contains out 'h' && String.contains out '3' in
  assert_eq ~label:"h3" (b has) (b true)

let test_body_h4 () =
  Printf.printf "body: '### Heading' renders as h4\n";
  let out = Render.render_packet_body "### Sub\n" in
  let has = String.contains out '<' && String.contains out 'h' && String.contains out '4' in
  assert_eq ~label:"h4" (b has) (b true)

let test_body_h5 () =
  Printf.printf "body: '#### Heading' renders as h5\n";
  let out = Render.render_packet_body "#### Detail\n" in
  let has = String.contains out '<' && String.contains out 'h' && String.contains out '5' in
  assert_eq ~label:"h5" (b has) (b true)

let test_body_unordered_list () =
  Printf.printf "body: unordered list renders as <ul>\n";
  let out = Render.render_packet_body "- first\n- second\n- third\n" in
  let has_ul = String.contains out '<' && String.contains out 'u' && String.contains out 'l' in
  let has_li = String.contains out 'l' && String.contains out 'i' in
  assert_eq ~label:"ul" (b has_ul) (b true);
  assert_eq ~label:"li" (b has_li) (b true)

let test_body_ordered_list () =
  Printf.printf "body: ordered list renders as <ol>\n";
  let out = Render.render_packet_body "1. one\n2. two\n3. three\n" in
  let has = String.contains out '<' && String.contains out 'o' && String.contains out 'l' in
  assert_eq ~label:"ol" (b has) (b true)

let test_body_list_with_blank_terminates () =
  Printf.printf "body: blank line terminates a list\n";
  let out = Render.render_packet_body "- a\n- b\n\npara after\n" in
  let has_ul_close = String.contains out '<' && String.contains out '/' in
  let has_p_after = String.contains out 'p' in
  assert_eq ~label:"ul-closed" (b has_ul_close) (b true);
  assert_eq ~label:"p-after" (b has_p_after) (b true)

let test_body_code_fence_preserved () =
  Printf.printf "body: triple-backtick code blocks render as <pre><code>\n";
  let out = Render.render_packet_body "```\nlet x = 1\n```\n" in
  let has_pre = String.contains out '<' && String.contains out 'p' && String.contains out 'r' && String.contains out 'e' in
  let has_code = String.contains out 'c' && String.contains out 'o' && String.contains out 'd' && String.contains out 'e' in
  assert_eq ~label:"pre" (b has_pre) (b true);
  assert_eq ~label:"code" (b has_code) (b true)

let run () =
  test_lower_plain_href ();
  test_lower_preserves_anchor ();
  test_lower_preserves_query ();
  test_lower_handles_query_before_fragment ();
  test_rewrite_md_extension ();
  test_rewrite_math_modeling_to_manifesto ();
  test_rewrite_license_to_root ();
  test_rewrite_multiple_in_one_string ();
  test_rewrite_already_lowercase_passthrough ();
  test_body_h3 ();
  test_body_h4 ();
  test_body_h5 ();
  test_body_unordered_list ();
  test_body_ordered_list ();
  test_body_list_with_blank_terminates ();
  test_body_code_fence_preserved ()
