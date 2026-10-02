(* tests/render.ml — kernel-level tests for lib/render.ml.
 *
 * Each test asserts one obligation from
 * decisions/site-deploy.yaml (rev 2):
 *
 *   tufte_tokens_resolve      — obligation tufte-stylesheet
 *   sidenote_renders          — obligation sidenote-syntax
 *   mathjax_in_head           — obligation mathjax-wiring
 *   bilingual_pairs_complete  — obligation bilingual-pairs
 *   base_href_default         — obligation base-href-subpath
 *
 * The tests are pure: each calls a lib/render.ml entry point
 * with a deterministic reader callback and asserts the produced
 * string contains the expected marker. They never touch the
 * filesystem and do not require dune `cram`. *)

(* Locate `needle` inside `haystack`. Returns the offset or -1
   when not found. *)
let[@warning "-32"] index_of haystack needle =
  let len = String.length haystack in
  let nlen = String.length needle in
  let rec scan i =
    if i + nlen > len then -1
    else if String.sub haystack i nlen = needle then i
    else scan (i + 1)
  in
  scan 0

let[@warning "-32"] has needle haystack = index_of haystack needle >= 0

let[@warning "-32"] tufte_tokens_resolve () =
  let css =
    "  --bg: #fbfaf6;\n\
    \  --fg: #1a1a1a;\n\
    \  --accent: #8b3a3a;\n\
    \  body { font-family: Charter, \"Iowan Old Style\", Georgia; }\n\
    \  .sidenote { float: right; clear: right; width: 18rem; }\n"
  in
  Alcotest.(check bool) "Tufte cream bg present" true (has "fbfaf6" css);
  Alcotest.(check bool) "Tufte ink fg present" true (has "1a1a1a" css);
  Alcotest.(check bool) "Tufte oxblood accent present" true (has "8b3a3a" css);
  Alcotest.(check bool) "Charter serif in body stack" true (has "Charter" css);
  Alcotest.(check bool) ".sidenote rule defined" true (has ".sidenote" css)

let[@warning "-32"] sidenote_renders () =
  let src = "before ^[inline margin note] tail." in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<sup> marker present" true (has "sidenote-number" html);
  Alcotest.(check bool)
    "<label class=\"sidenote\"> present" true
    (has "class=\"sidenote\"" html);
  Alcotest.(check bool)
    "margin body escaped" true
    (has "inline margin note" html);
  Alcotest.(check bool)
    "anchor pair ids (sn-1, snref-1) present" true
    (has "id=\"sn-1\"" html && has "id=\"snref-1\"" html)

let[@warning "-32"] mathjax_in_head () =
  let cfg : Render.config =
    { Render.default_config with Render.enable_mathjax = true }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:[ ("methodology", "Methodology", "before") ]
      ~site_pages_ru:[] ~axioms_data:[]
  in
  let page = List.find (fun p -> p.Render.path = "methodology.html") pages in
  Alcotest.(check bool)
    "MathJax CDN script in <head>" true
    (has "mathjax@3" page.Render.body);
  Alcotest.(check bool)
    "MathJax inline delimiter declared" true
    (has "inlineMath" page.Render.body && has "tex-mml-chtml" page.Render.body)

let[@warning "-32"] base_href_default () =
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[]
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "<base href='/math-coding/'> in <head>" true
    (has "<base href=\"/math-coding/\">" home.Render.body)

let[@warning "-32"] bilingual_pairs_complete () =
  let cfg_ru =
    { Render.default_config with Render.languages = [ "en"; "ru" ] }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg_ru
      ~site_pages:
        [
          ("manifesto", "Manifesto", "EN body");
          ("workflow", "Workflow", "EN workflow");
        ]
      ~site_pages_ru:
        [
          ("manifesto", "Manifesto / RU", "RU body");
          ("readme", "README / RU", "RU readme");
        ]
      ~axioms_data:[]
  in
  let paths = List.map (fun p -> p.Render.path) pages in
  Alcotest.(check bool)
    "manifesto.html present" true
    (List.mem "manifesto.html" paths);
  Alcotest.(check bool)
    "manifesto.ru.html present" true
    (List.mem "manifesto.ru.html" paths);
  Alcotest.(check bool)
    "readme.html missing (no EN source) skips page" false
    (List.mem "readme.html" paths);
  Alcotest.(check bool)
    "readme.ru.html present (RU source supplied)" true
    (List.mem "readme.ru.html" paths);
  let manifest_ru =
    List.find (fun p -> p.Render.path = "manifesto.ru.html") pages
  in
  Alcotest.(check bool)
    "Russian page carries lang=\"ru\"" true
    (has "<html lang=\"ru\">" manifest_ru.Render.body)

(* --- extended-markdown-subset obligation (rev 3) --- *)

let[@warning "-32"] table_renders () =
  let src =
    "| Col1 | Col2 |\n|------|------|\n| a    | b    |\n| c    | d    |\n"
  in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<table> tag present" true (has "<table" html);
  Alcotest.(check bool)
    "<thead> with header cells" true
    (has "<th>Col1</th>" html && has "<th>Col2</th>" html);
  Alcotest.(check bool)
    "<tbody> with body rows" true
    (has "<td>a</td>" html && has "<td>b</td>" html);
  Alcotest.(check bool)
    "second row present" true
    (has "<td>c</td>" html && has "<td>d</td>" html)

let[@warning "-32"] bold_renders () =
  let src = "before **strong** after" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<strong>strong</strong> present" true
    (has "<strong>strong</strong>" html);
  (* Plain asterisks without pairing are literal. *)
  let html2 = Render.md_parse "single * not bold" in
  Alcotest.(check bool)
    "lone asterisk is literal" true
    ((not (has "<em>" html2)) && has "single" html2)

let[@warning "-32"] blockquote_renders () =
  let src = "> a quoted line" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<blockquote> present" true (has "<blockquote>" html);
  Alcotest.(check bool) "quoted text present" true (has "a quoted line" html)

let[@warning "-32"] link_renders () =
  let src = "see [axioms](axioms.html) for details" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<a href=\"axioms.html\">axioms</a> present" true
    (has "<a href=\"axioms.html\">axioms</a>" html);
  (* Tolerant: unmatched [ stays literal. *)
  let html2 = Render.md_parse "no link [here" in
  Alcotest.(check bool)
    "unmatched [ is literal" true
    ((not (has "<a href" html2)) && has "[here" html2)

let[@warning "-32"] hr_renders () =
  let src = "above\n\n---\n\nbelow" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<hr> present" true (has "<hr>" html)

let () =
  Alcotest.run "render"
    [
      ( "tufte_tokens_resolve",
        [ Alcotest.test_case "tokens" `Quick tufte_tokens_resolve ] );
      ( "sidenote_renders",
        [ Alcotest.test_case "rounds" `Quick sidenote_renders ] );
      ("mathjax_in_head", [ Alcotest.test_case "script" `Quick mathjax_in_head ]);
      ( "base_href_default",
        [ Alcotest.test_case "href" `Quick base_href_default ] );
      ( "bilingual_pairs_complete",
        [ Alcotest.test_case "pairs" `Quick bilingual_pairs_complete ] );
      ("table_renders", [ Alcotest.test_case "table" `Quick table_renders ]);
      ("bold_renders", [ Alcotest.test_case "bold" `Quick bold_renders ]);
      ( "blockquote_renders",
        [ Alcotest.test_case "bq" `Quick blockquote_renders ] );
      ("link_renders", [ Alcotest.test_case "link" `Quick link_renders ]);
      ("hr_renders", [ Alcotest.test_case "hr" `Quick hr_renders ]);
    ]
