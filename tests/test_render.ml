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

let run () =
  test_lower_plain_href ();
  test_lower_preserves_anchor ();
  test_lower_preserves_query ();
  test_lower_handles_query_before_fragment ();
  test_rewrite_md_extension ();
  test_rewrite_math_modeling_to_manifesto ();
  test_rewrite_license_to_root ();
  test_rewrite_multiple_in_one_string ();
  test_rewrite_already_lowercase_passthrough ()
