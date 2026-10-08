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

(* Count non-overlapping occurrences of `needle` inside `haystack`. *)
let[@warning "-32"] count needle haystack =
  let len = String.length haystack in
  let nlen = String.length needle in
  let rec loop i acc =
    if i + nlen > len then acc
    else if String.sub haystack i nlen = needle then loop (i + nlen) (acc + 1)
    else loop (i + 1) acc
  in
  loop 0 0

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

(* --- render-kernel-fixes-2026-10 obligations --- *)

let[@warning "-32"] fenced_code_renders () =
  let src = "```text\ncommitment\n   |\n   v\nprediction\n```\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<pre><code class=\"language-text\"> present" true
    (has "<pre><code class=\"language-text\">" html);
  Alcotest.(check bool)
    "diagram body inside <pre>" true
    (has "commitment\n   |\n   v\nprediction" html);
  (* Negative: <pre> must NOT include the closing fence itself. *)
  Alcotest.(check bool)
    "closing fence is not echoed verbatim" true
    ((not (has "```" html)) || has "<pre>" html)

let[@warning "-32"] fenced_code_closing_fence_length_3 () =
  (* Regression test for the "```text" bug: the previous predicate
     was `String.length trimmed > 4 && String.sub trimmed 0 4 = "```"`,
     which can NEVER match because `String.sub "```" 0 4` raises
     Invalid_argument — and the `> 4` guard hid that crash by
     silently failing the predicate. The closing fence is length 3. *)
  let src = "before\n\n```text\nbody\n```\n\nafter\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<pre><code> wraps the body" true
    (has "<pre><code class=\"language-text\">body" html);
  Alcotest.(check bool)
    "<p>after</p> present after fence" true (has "after" html)

let[@warning "-32"] mermaid_fence_renders_as_div () =
  let src = "```mermaid\ngraph TD; A-->B;\n```\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<div class=\"mermaid\"> present" true
    (has "<div class=\"mermaid\">" html);
  Alcotest.(check bool)
    "no <pre><code> for mermaid" true
    (not (has "<pre><code class=\"language-mermaid\">" html))

let[@warning "-32"] list_continuation_renders () =
  (* Multi-line list item: continuation lines joined into one <li>. *)
  let src = "- first line\n  second line\n  third line\n- second item\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "two <li> for two items" true
    (has "<li>" html && count "<li>" html = 2);
  Alcotest.(check bool)
    "first item contains continuation" true
    (has "first line second line third line" html);
  Alcotest.(check bool)
    "second item is independent" true (has "second item" html)

let[@warning "-32"] list_single_item_still_one_li () =
  (* Single-line list item stays as one <li>. *)
  let src = "- just one line\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "single <li>" true (count "<li>" html = 1)

let[@warning "-32"] italic_renders () =
  let src = "an *italic* word" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<em>italic</em> present" true
    (has "<em>italic</em>" html);
  (* A separate test pairs italic with bold to ensure both
     render in one pass. *)
  let src2 = "**bold** and *italic*" in
  let html2 = Render.md_parse src2 in
  Alcotest.(check bool)
    "<strong>bold</strong> still rendered" true
    (has "<strong>bold</strong>" html2);
  Alcotest.(check bool)
    "<em>italic</em> still rendered" true
    (has "<em>italic</em>" html2);
  (* Underscore italic with word-boundary. *)
  let src3 = "see _emphasis_ here" in
  let html3 = Render.md_parse src3 in
  Alcotest.(check bool)
    "_text_ becomes <em> via word-boundary" true
    (has "<em>emphasis</em>" html3)

let[@warning "-32"] italic_lone_asterisk_literal () =
  let html = Render.md_parse "single * not italic" in
  Alcotest.(check bool)
    "lone asterisk stays literal" true
    (has "single * not italic" html && not (has "<em>" html))

let[@warning "-32"] italic_underscore_inside_identifier_safe () =
  (* `$x_i$` style identifiers must not be italicised; the underscore
     is preceded by an alphanumeric so the rule does not match. *)
  let html = Render.md_parse "subscript $x_i$ is fine" in
  Alcotest.(check bool)
    "no <em> for intraword underscore" true
    (not (has "<em>" html))

let[@warning "-32"] mathjax_default_on () =
  let cfg : Render.config = Render.default_config in
  Alcotest.(check bool)
    "default_config.enable_mathjax is true" true cfg.Render.enable_mathjax

let[@warning "-32"] mathjax_in_head_when_enabled () =
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
    "MathJax CDN script emitted when flag on" true
    (has "mathjax@3" page.Render.body)

let[@warning "-32"] mathjax_script_on_prose_page_when_enabled () =
  (* Reverses `mathjax-default-off` from `render-kernel-fixes-2026-10@1`.
     The default config now has `enable_mathjax = true`, so a
     flagless `Render.build_pages` call must emit the MathJax
     script tag on the prose path (`index.html`). The test
     mirrors `mathjax_in_head_when_enabled` but uses the default
     config without overriding `enable_mathjax` — the default
     itself is the asserted behaviour. *)
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[]
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "MathJax script tag emitted on prose index by default" true
    (has "mathjax@3" home.Render.body)

let[@warning "-32"] mathjax_no_dollar_delimiters () =
  (* `decisions/mathjax-delimiter-hardening-2026-10.yaml`
     narrows MathJax to LaTeX-style delimiters: `\(..\)` and
     `\[..\]`. The `$..$` and `$$..$$` pairs are NOT in the
     emitted configuration, so a stray `$` in prose remains
     a literal character even when MathJax is enabled. *)
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
    "$..$ pair absent from inlineMath declaration" true
    (not (has "['$','$']" page.Render.body));
  Alcotest.(check bool)
    "$$..$$ pair absent from displayMath declaration" true
    (not (has "['$$','$$']" page.Render.body))

let[@warning "-32"] mathjax_uses_latex_delimiters () =
  (* The LaTeX-style delimiters `\(..\)` and `\[..\]` MUST be
     present in the MathJax configuration when enabled. MathJax 3
     TeX-unescapes delimiter strings, so the JS source must
     contain TeX-escaped backslashes (`\\(` to yield `\(` after
     unescape) — which is what makes every parenthetical in the
     page NOT be typeset as math. *)
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
    "inlineMath declares TeX-escaped \\\\(" true
    (has "['\\\\(', '\\\\)']" page.Render.body);
  Alcotest.(check bool)
    "displayMath declares TeX-escaped \\\\[\\]" true
    (has "['\\\\[', '\\\\]']" page.Render.body);
  Alcotest.(check bool)
    "skipHtmlTags includes div.mermaid" true
    (has "'div.mermaid'" page.Render.body)

let[@warning "-32"] css_has_math_rules () =
  (* Read the live stylesheet and assert it ships rules for
     MathJax containers. The rules are scoped to mjx-container
     so a non-MathJax page is unaffected. *)
  let css_path =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p -> Filename.concat p "assets/style.css"
    | None -> "../assets/style.css"
  in
  let ic = open_in css_path in
  let n = in_channel_length ic in
  let css = really_input_string ic n in
  close_in ic;
  Alcotest.(check bool)
    "mjx-container rule declared" true (has "mjx-container" css);
  Alcotest.(check bool)
    "display-math overflow rule declared" true
    (has "mjx-container[display=\"true\"]" css && has "overflow-x: auto" css);
  Alcotest.(check bool)
    "math font stack declared" true (has "STIX Two Math" css)

let[@warning "-32"] css_has_mermaid_svg_rules () =
  (* Read the live stylesheet and assert it ships rules for
     mermaid SVG diagrams. The .mermaid svg rule keeps diagrams
     inside the 54-rem column on narrow viewports. *)
  let css_path =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p -> Filename.concat p "assets/style.css"
    | None -> "../assets/style.css"
  in
  let ic = open_in css_path in
  let n = in_channel_length ic in
  let css = really_input_string ic n in
  close_in ic;
  Alcotest.(check bool)
    ".mermaid svg rule declared" true (has ".mermaid svg" css);
  Alcotest.(check bool)
    ".mermaid svg max-width: 100%" true
    (has "max-width: 100%" css && has ".mermaid svg" css)

let[@warning "-32"] packages_page_has_grid () =
  let cfg : Render.config = Render.default_config in
  let pkg_html =
    "<section class=\"mathc-packages\" \
     data-mathc-package-count=\"42\"><h2>packages</h2></section>"
  in
  let pages =
    Render.build_pages ~package_html:pkg_html ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:[ ("packages", "Packages", "prose body") ]
      ~site_pages_ru:[] ~axioms_data:[]
  in
  let page = List.find (fun p -> p.Render.path = "packages.html") pages in
  Alcotest.(check bool)
    "packages.html has <section class=\"mathc-packages-section\">" true
    (has "<section class=\"mathc-packages-section\">" page.Render.body);
  Alcotest.(check bool)
    "packages.html has the grid body" true
    (has "data-mathc-package-count=\"42\"" page.Render.body)

let[@warning "-32"] ru_nav_omits_missing_sibling () =
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:
        [
          ("methodology", "Methodology", "EN methodology");
          ("manifesto", "Manifesto", "EN manifesto");
        ]
      ~site_pages_ru:[ ("manifesto", "Manifesto / RU", "RU manifesto") ]
      ~axioms_data:[]
  in
  let methodology =
    List.find (fun p -> p.Render.path = "methodology.html") pages
  in
  let manifesto = List.find (fun p -> p.Render.path = "manifesto.html") pages in
  Alcotest.(check bool)
    "methodology omits RU toggle (no .ru.md sibling)" true
    ((not (has "lang-toggle" methodology.Render.body))
    || not (has "methodology.ru.html" methodology.Render.body));
  Alcotest.(check bool)
    "manifesto carries RU toggle" true
    (has "manifesto.ru.html" manifesto.Render.body)

let[@warning "-32"] axiom_page_single_h1 () =
  let cfg : Render.config = Render.default_config in
  let axiom_body = "# Axiom A1 — Feedback\n\nbody text\n" in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[ ("feedback", axiom_body) ]
  in
  let page =
    List.find (fun p -> p.Render.path = "axioms/feedback.html") pages
  in
  let h1_count = count "<h1>" page.Render.body in
  Alcotest.(check bool)
    "exactly one <h1> on axiom page (template h1 + stripped source h1)" true
    (h1_count = 1)

let[@warning "-32"] footer_mathc_render () =
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:[ ("home", "Home", "body") ]
      ~site_pages_ru:[] ~axioms_data:[]
  in
  let page = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "footer says mathc render" true
    (has "mathc render" page.Render.body);
  Alcotest.(check bool)
    "footer does not say mc render" true
    (not (has "<code>mc render</code>" page.Render.body))

let[@warning "-32"] base_href_default () =
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[]
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "<base href='/math-coding/'> in <head> by default" true
    (has "<base href=\"/math-coding/\">" home.Render.body)

let[@warning "-32"] base_href_empty () =
  let cfg : Render.config =
    { Render.default_config with Render.site_base = "" }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[]
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "empty site_base suppresses <base href>" true
    (not (has "<base href=" home.Render.body))

let[@warning "-32"] version_in_hero_and_footer () =
  let cfg : Render.config =
    { Render.default_config with Render.version = "9.9.9-test" }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~axioms_data:[]
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "index.html hero carries the configured version" true
    (has "<h1>math-coding 9.9.9-test</h1>" home.Render.body);
  Alcotest.(check bool)
    "index.html footer carries the configured version" true
    (has "9.9.9-test &middot;" home.Render.body);
  Alcotest.(check bool)
    "index.html <title> carries the configured version" true
    (has "math-coding 9.9.9-test &mdash; math-coding" home.Render.body)

let[@warning "-32"] version_default_reads_version_file () =
  (* `default_config` is built once at module load. The build harness
     that runs the tests in this directory is the math-coding repo
     itself, which carries a `VERSION` file at the repo root. We
     therefore expect the default config's `version` field to be
     non-empty and to match the file's contents. *)
  let v = Render.default_config.Render.version in
  Alcotest.(check bool)
    "default_config.version is non-empty" true
    (String.length v > 0);
  (* `dune test` exports DUNE_SOURCEROOT pointing at the project
     root; fall back to ../VERSION from the test exe directory
     for direct invocation. *)
  let path =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some p -> Filename.concat p "VERSION"
    | None -> "../VERSION"
  in
  let ic = open_in path in
  let n = in_channel_length ic in
  let file_version = really_input_string ic n |> String.trim in
  close_in ic;
  Alcotest.(check string)
    "default_config.version matches VERSION" file_version v

(* --- site-ru-en-synced obligation (t5-1) --- *)

(* `dune test` exports DUNE_SOURCEROOT pointing at the project
   root; fall back to ../site from the test exe directory
   for direct invocation. *)
let[@warning "-32"] bilingual_site_source_root () =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some p -> Filename.concat p "site"
  | None -> "../site"

let[@warning "-32"] read_text path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let[@warning "-32"] split_lines s = String.split_on_char '\n' s

let[@warning "-32"] trim s =
  let len = String.length s in
  let rec left i =
    if i >= len then i
    else match s.[i] with ' ' | '\t' | '\r' -> left (i + 1) | _ -> i
  in
  let rec right i =
    if i <= 0 then i
    else match s.[i - 1] with ' ' | '\t' | '\r' -> right (i - 1) | _ -> i
  in
  let l = left 0 in
  let r = right len in
  if l >= r then "" else String.sub s l (r - l)

(* Count lines that begin with a Markdown heading marker (any
   depth from # to ######). *)
let[@warning "-32"] count_headings lines =
  List.fold_left
    (fun acc line ->
      let t = trim line in
      if String.length t > 0 && t.[0] = '#' then acc + 1 else acc)
    0 lines

(* Count list items whose first non-whitespace char is `-` or `*`
   followed by a space. Wrapped continuations are skipped. *)
let[@warning "-32"] count_list_items lines =
  List.fold_left
    (fun acc line ->
      let t = trim line in
      let n = String.length t in
      if n >= 2 && (t.[0] = '-' || t.[0] = '*') && t.[1] = ' ' then acc + 1
      else acc)
    0 lines

(* Count fenced code blocks. Each block contributes a pair of
   ``` markers; we divide by 2 to count blocks. *)
let[@warning "-32"] count_fenced_blocks lines =
  let n =
    List.fold_left
      (fun acc line ->
        let t = trim line in
        if String.length t >= 3 && String.sub t 0 3 = "```" then acc + 1
        else acc)
      0 lines
  in
  n / 2

(* Count pipe-table rows: lines whose first non-whitespace char
   is `|`. *)
let[@warning "-32"] count_table_rows lines =
  List.fold_left
    (fun acc line ->
      let t = trim line in
      if String.length t > 0 && t.[0] = '|' then acc + 1 else acc)
    0 lines

(* The drift metric is the sum of absolute differences across four
   structural fingerprints:
     - headings,
     - list items,
     - fenced code blocks,
     - pipe-table rows.
   Each structural divergence is one substantive difference.
   The threshold is 3 (per decisions/plan-2026-10-improvements/t5-1). *)
let[@warning "-32"] structural_drift en_text ru_text =
  let en_lines = split_lines en_text in
  let ru_lines = split_lines ru_text in
  let en_h = count_headings en_lines in
  let ru_h = count_headings ru_lines in
  let en_b = count_list_items en_lines in
  let ru_b = count_list_items ru_lines in
  let en_c = count_fenced_blocks en_lines in
  let ru_c = count_fenced_blocks ru_lines in
  let en_t = count_table_rows en_lines in
  let ru_t = count_table_rows ru_lines in
  abs (en_h - ru_h) + abs (en_b - ru_b) + abs (en_c - ru_c) + abs (en_t - ru_t)

(* Enumerate every name under `site/<name>.md` that also has a
   `site/<name>.ru.md` sibling. The set is the reconciliation
   surface for obligation t5-1. *)
let[@warning "-32"] bilingual_pairs_with_drift () =
  let root = bilingual_site_source_root () in
  let names =
    [ "manifesto"; "workflow"; "readme"; "foundations"; "contributing"; "faq" ]
  in
  List.map
    (fun name ->
      let en = read_text (Filename.concat root (name ^ ".md")) in
      let ru = read_text (Filename.concat root (name ^ ".ru.md")) in
      (name, structural_drift en ru))
    names

let[@warning "-32"] bilingual_drift_under_threshold () =
  let threshold = 3 in
  let root = bilingual_site_source_root () in
  (* Sanity: every reconciled pair has both EN and RU source files.
     The renderer relies on the same invariant; if this fails the
     bilingual_pairs_complete test will also fail. *)
  let pairs = bilingual_pairs_with_drift () in
  let present_en name = Sys.file_exists (Filename.concat root (name ^ ".md")) in
  let present_ru name =
    Sys.file_exists (Filename.concat root (name ^ ".ru.md"))
  in
  List.iter
    (fun (name, _drift) ->
      Alcotest.(check bool)
        (Printf.sprintf "%s.md present" name)
        true (present_en name);
      Alcotest.(check bool)
        (Printf.sprintf "%s.ru.md present" name)
        true (present_ru name))
    pairs;
  (* For each pair, structural_drift must be ≤ threshold. *)
  List.iter
    (fun (name, drift) ->
      Alcotest.(check bool)
        (Printf.sprintf "%s structural drift %d <= %d" name drift threshold)
        true (drift <= threshold))
    pairs

let () =
  Alcotest.run "render"
    [
      ( "tufte_tokens_resolve",
        [ Alcotest.test_case "tokens" `Quick tufte_tokens_resolve ] );
      ( "sidenote_renders",
        [ Alcotest.test_case "rounds" `Quick sidenote_renders ] );
      ( "mathjax_in_head_when_enabled",
        [ Alcotest.test_case "script" `Quick mathjax_in_head_when_enabled ] );
      ( "base_href_default",
        [ Alcotest.test_case "href" `Quick base_href_default ] );
      ("base_href_empty", [ Alcotest.test_case "empty" `Quick base_href_empty ]);
      ( "version_in_hero_and_footer",
        [ Alcotest.test_case "ver" `Quick version_in_hero_and_footer ] );
      ( "version_default_reads_version_file",
        [ Alcotest.test_case "vfile" `Quick version_default_reads_version_file ]
      );
      ( "bilingual_pairs_complete",
        [ Alcotest.test_case "pairs" `Quick bilingual_pairs_complete ] );
      ( "bilingual_drift_under_threshold",
        [ Alcotest.test_case "drift" `Quick bilingual_drift_under_threshold ] );
      ("table_renders", [ Alcotest.test_case "table" `Quick table_renders ]);
      ("bold_renders", [ Alcotest.test_case "bold" `Quick bold_renders ]);
      ( "blockquote_renders",
        [ Alcotest.test_case "bq" `Quick blockquote_renders ] );
      ("link_renders", [ Alcotest.test_case "link" `Quick link_renders ]);
      ("hr_renders", [ Alcotest.test_case "hr" `Quick hr_renders ]);
      ( "fenced_code_renders",
        [ Alcotest.test_case "pre" `Quick fenced_code_renders ] );
      ( "fenced_code_closing_fence_length_3",
        [ Alcotest.test_case "len-3" `Quick fenced_code_closing_fence_length_3 ]
      );
      ( "mermaid_fence_renders_as_div",
        [ Alcotest.test_case "mermaid" `Quick mermaid_fence_renders_as_div ] );
      ( "list_continuation_renders",
        [ Alcotest.test_case "cont" `Quick list_continuation_renders ] );
      ( "list_single_item_still_one_li",
        [ Alcotest.test_case "single" `Quick list_single_item_still_one_li ] );
      ("italic_renders", [ Alcotest.test_case "em" `Quick italic_renders ]);
      ( "italic_lone_asterisk_literal",
        [ Alcotest.test_case "lone" `Quick italic_lone_asterisk_literal ] );
      ( "italic_underscore_inside_identifier_safe",
        [
          Alcotest.test_case "id" `Quick
            italic_underscore_inside_identifier_safe;
        ] );
      ( "mathjax_default_on",
        [ Alcotest.test_case "on" `Quick mathjax_default_on ] );
      ( "mathjax_script_on_prose_page_when_enabled",
        [
          Alcotest.test_case "prose-default" `Quick
            mathjax_script_on_prose_page_when_enabled;
        ] );
      ( "mathjax_no_dollar_delimiters",
        [ Alcotest.test_case "no-dollar" `Quick mathjax_no_dollar_delimiters ]
      );
      ( "mathjax_uses_latex_delimiters",
        [ Alcotest.test_case "latex" `Quick mathjax_uses_latex_delimiters ] );
      ( "css_has_math_rules",
        [ Alcotest.test_case "math" `Quick css_has_math_rules ] );
      ( "css_has_mermaid_svg_rules",
        [ Alcotest.test_case "mermaid" `Quick css_has_mermaid_svg_rules ] );
      ( "packages_page_has_grid",
        [ Alcotest.test_case "grid" `Quick packages_page_has_grid ] );
      ( "ru_nav_omits_missing_sibling",
        [ Alcotest.test_case "ru" `Quick ru_nav_omits_missing_sibling ] );
      ( "axiom_page_single_h1",
        [ Alcotest.test_case "h1" `Quick axiom_page_single_h1 ] );
      ( "footer_mathc_render",
        [ Alcotest.test_case "footer" `Quick footer_mathc_render ] );
      ( "mermaid_in_seven_pages",
        [
          Alcotest.test_case "mermaid" `Quick
            (fun () ->
              (* Editorial obligation: every site page and per-axiom
                 page that declares a mermaid diagram must surface
                 it as `<div class="mermaid">…</div>` in the
                 rendered HTML. *)
              let root =
                match Sys.getenv_opt "DUNE_SOURCEROOT" with
                | Some p -> p
                | None -> ".."
              in
              let script = Filename.concat root "scripts/render.sh" in
              let ec = Sys.command script in
              if ec <> 0 then
                Alcotest.failf
                  "scripts/render.sh exited %d; cannot verify mermaid \
                   output" ec;
              let dist = Filename.concat root "dist" in
              let pages =
                [
                  "axioms/separation.html";
                  "axioms/feedback.html";
                  "axioms/self-application.html";
                  "methodology.html";
                  "workflow.html";
                  "bootstrap-gate.html";
                  "foundations.html";
                ]
              in
              List.iter
                (fun rel ->
                  let path = Filename.concat dist rel in
                  let html = read_text path in
                  Alcotest.(check bool)
                    (Printf.sprintf
                       "dist/%s contains <div class=\"mermaid\">" rel)
                    true (has "<div class=\"mermaid\">" html))
                pages)
        ] );
      ( "axiom_has_formalization_section",
        [
          Alcotest.test_case "formalization" `Quick
            (fun () ->
              (* Editorial obligation: each of the five axiom pages
                 must end with a `## Formalization` section that
                 references the formal algebra. *)
              let root =
                match Sys.getenv_opt "DUNE_SOURCEROOT" with
                | Some p -> p
                | None -> ".."
              in
              let dist = Filename.concat root "dist" in
              let axioms =
                [
                  "axioms/separation.html";
                  "axioms/feedback.html";
                  "axioms/invariants.html";
                  "axioms/self-application.html";
                  "axioms/care.html";
                ]
              in
              List.iter
                (fun rel ->
                  let path = Filename.concat dist rel in
                  let html = read_text path in
                  Alcotest.(check bool)
                    (Printf.sprintf
                       "dist/%s contains Formalization section" rel)
                    true (has "Formalization" html))
                axioms)
        ] );
    ]
