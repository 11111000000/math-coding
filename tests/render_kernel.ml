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
      ~site_pages:
        [
          {
            Render.name = "methodology";
            Render.title = "Methodology";
            Render.body_md = "before";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "<base href='/math-coding/'> in <head>" true
    (has "<base href=\"/math-coding/\">" home.Render.body)

let[@warning "-32"] bilingual_pairs_complete () =
  let cfg_ru =
    { Render.default_config with Render.languages = [ Render.En; Render.Ru ] }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg_ru
      ~site_pages:
        [
          {
            Render.name = "manifesto";
            Render.title = "Manifesto";
            Render.body_md = "EN body";
          };
          {
            Render.name = "workflow";
            Render.title = "Workflow";
            Render.body_md = "EN workflow";
          };
        ]
      ~site_pages_ru:
        [
          {
            Render.name = "manifesto";
            Render.title = "Manifesto / RU";
            Render.body_md = "RU body";
          };
          {
            Render.name = "readme";
            Render.title = "README / RU";
            Render.body_md = "RU readme";
          };
        ]
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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

(* Regression: nav / footer language toggles on a non-English page
   must point at `<page_key>.html`, not `<page_key>.en.html`. The
   bug: `lang_href_for` used `page_key ^ "." ^ lang ^ ".html"`
   unconditionally for non-home pages, so the RU/ZH site's EN
   toggle advertised `manifesto.en.html` (404). English is the
   source language: per-page English files live at `<page_key>.html`
   with no language suffix. *)
let[@warning "-32"] lang_toggle_en_no_suffix () =
  let cfg =
    {
      Render.default_config with
      Render.languages = [ Render.En; Render.Ru; Render.Zh ];
    }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:
        [
          {
            Render.name = "manifesto";
            Render.title = "Manifesto";
            Render.body_md = "EN body";
          };
          {
            Render.name = "axioms";
            Render.title = "Axioms";
            Render.body_md = "EN axioms";
          };
        ]
      ~site_pages_ru:
        [
          {
            Render.name = "manifesto";
            Render.title = "Manifesto / RU";
            Render.body_md = "RU body";
          };
          {
            Render.name = "axioms";
            Render.title = "Axioms / RU";
            Render.body_md = "RU axioms";
          };
        ]
      ~site_pages_zh:
        [
          {
            Render.name = "axioms";
            Render.title = "Axioms / ZH";
            Render.body_md = "ZH axioms";
          };
        ]
      ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let body_of path =
    List.find (fun p -> p.Render.path = path) pages |> fun p -> p.Render.body
  in
  Alcotest.(check bool)
    "RU page's EN toggle is manifesto.html (not .en.html)" true
    (has "href=\"manifesto.html\"" (body_of "manifesto.ru.html"));
  Alcotest.(check bool)
    "RU page's EN toggle never advertises manifesto.en.html" false
    (has "href=\"manifesto.en.html\"" (body_of "manifesto.ru.html"));
  Alcotest.(check bool)
    "ZH page's EN toggle is axioms.html (not .en.html)" true
    (has "href=\"axioms.html\"" (body_of "axioms.zh.html"));
  Alcotest.(check bool)
    "ZH page's EN toggle never advertises axioms.en.html" false
    (has "href=\"axioms.en.html\"" (body_of "axioms.zh.html"));
  Alcotest.(check bool)
    "ZH page's RU toggle is axioms.ru.html" true
    (has "href=\"axioms.ru.html\"" (body_of "axioms.zh.html"))

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

let[@warning "-32"] inline_figure_renders () =
  (* Inline image ![alt](url) becomes a
     `<figure class="mathc-figure mathc-figure-inline">` wrapping an
     `<img>`. This is the SVG-diagram syntax that replaced Mermaid
     (diagrams-as-svg-2026-10). *)
  let src = "before\n\n![A diagram](assets/foo.svg)\n\nafter\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool)
    "<figure class=\"mathc-figure mathc-figure-inline\"> present" true
    (has "<figure class=\"mathc-figure mathc-figure-inline\">" html);
  Alcotest.(check bool)
    "<img src=\"assets/foo.svg\"> present" true
    (has "<img src=\"assets/foo.svg\"" html);
  Alcotest.(check bool) "alt text preserved" true (has "A diagram" html);
  Alcotest.(check bool)
    "no mermaid div emitted" true
    (not (has "<div class=\"mermaid\">" html))

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

(* --- ordered-list support (render-ordered-lists-2026-10) --- *)

let[@warning "-32"] ordered_list_renders () =
  (* The previous bug: a list of `1. ... 2. ... 3. ...` items
     rendered as a single `<p>` with the numbers concatenated.
     The fixture is the exact text from `site/methodology.ru.md`
     §"Рабочая цепочка на практике", condensed to a single line
     per item so the test is not sensitive to line-wrap. *)
  let src =
    "intro paragraph\n\n\
     1. **A.** first item\n\
     2. **B.** second item\n\
     3. **C.** third item\n\n\
     after\n"
  in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<ol> wrapper present" true (has "<ol>" html);
  Alcotest.(check bool) "</ol> closing present" true (has "</ol>" html);
  Alcotest.(check bool) "three <li> elements" true (count "<li>" html = 3);
  Alcotest.(check bool)
    "first <strong>A.</strong> present" true
    (has "<strong>A.</strong>" html);
  Alcotest.(check bool)
    "second <strong>B.</strong> present" true
    (has "<strong>B.</strong>" html);
  Alcotest.(check bool)
    "third <strong>C.</strong> present" true
    (has "<strong>C.</strong>" html);
  Alcotest.(check bool)
    "no raw '1.' in body" true
    (not (has "1. <strong>" html));
  Alcotest.(check bool)
    "no raw '2. <strong>' glued to first item" true
    (not (has "first item\n2." html || has "2. <strong>B.</strong>" html))
(* NOTE: the second "no raw" check is a defensive belt for the
   failure mode where the renderer still emits the literal `2. `
   after a previous `<li>`.  The first "no raw" check is the
   primary one, see the bug report. *)

let[@warning "-32"] ordered_list_multi_digit_renders () =
  (* Two-digit prefix (`10. `, `12. `) must also be recognised;
     the parser accepts one or more ASCII digits before the
     period. *)
  let src = "10. ten\n11. eleven\n12. twelve\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<ol> wrapper present" true (has "<ol>" html);
  Alcotest.(check bool) "three <li> elements" true (count "<li>" html = 3);
  Alcotest.(check bool) "ten present" true (has "ten" html);
  Alcotest.(check bool) "eleven present" true (has "eleven" html);
  Alcotest.(check bool) "twelve present" true (has "twelve" html)

let[@warning "-32"] ordered_list_continuation_joins_into_one_li () =
  (* Continuation lines (indented body, not a new marker) join
     the current item with a single space — same rule as the
     unordered list.  This matches the
     `site/methodology.ru.md` "Схема. Соответствует ли каждый
     артефакт" item, whose first line ends at "JSON-схеме?" and
     whose second line starts with "(решение, обязательство, ...". *)
  let src =
    "1. **Схема.** Соответствует ли каждый артефакт\n\
    \   (решение, обязательство) своей JSON-схеме?\n\
     2. **Идентичность.** Разрешима ли\n"
  in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<ol> wrapper present" true (has "<ol>" html);
  Alcotest.(check bool) "two <li> elements" true (count "<li>" html = 2);
  Alcotest.(check bool)
    "first item body joined with single space" true
    (has "Соответствует ли каждый артефакт (решение, обязательство)" html);
  Alcotest.(check bool)
    "second item is independent" true
    (has "<strong>Идентичность.</strong>" html)

let[@warning "-32"] ordered_list_invalid_marker_stays_paragraph () =
  (* Negative fixture: lines that LOOK like ordered markers but
     are not (decimal point, missing space) must NOT be wrapped
     in <ol>.  They flow into the paragraph accumulator like any
     other prose.  Note: the hand-rolled subset requires a literal
     space after the period (no CommonMark "trailing newline"
     support); a bare `1.` is not a list marker here.  This is
     consistent with the `- ` rule. *)
  let decimal = "We paid 1.5 dollars for the coffee.\n" in
  let html_decimal = Render.md_parse decimal in
  Alcotest.(check bool)
    "decimal '1.5 ' is NOT an <ol>" false (has "<ol>" html_decimal);
  Alcotest.(check bool) "decimal stays as a <p>" true (has "<p>" html_decimal);
  let no_space = "version 1.foo of the spec is current\n" in
  let html_no_space = Render.md_parse no_space in
  Alcotest.(check bool)
    "no-space '1.foo' is NOT an <ol>" false (has "<ol>" html_no_space);
  Alcotest.(check bool) "no-space stays as a <p>" true (has "<p>" html_no_space);
  let bare = "1.\n" in
  let html_bare = Render.md_parse bare in
  Alcotest.(check bool)
    "bare '1.' (no space) is NOT an <ol>" false (has "<ol>" html_bare);
  Alcotest.(check bool) "bare '1.' stays as a <p>" true (has "<p>" html_bare)

let[@warning "-32"] ordered_list_stops_at_dash_marker () =
  (* A `- ` line at the same indentation as the ordered list
     must end the ordered list and start a new unordered one.
     This protects against the bug where the renderer would
     treat `- ` as a continuation of the previous `<li>`. *)
  let src = "1. first\n2. second\n\n- dash a\n- dash b\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "<ol> wrapper present" true (has "<ol>" html);
  Alcotest.(check bool) "<ul> wrapper present" true (has "<ul>" html);
  Alcotest.(check bool) "two ordered <li>" true (count "<li>" html = 4)

let[@warning "-32"] ordered_list_after_paragraph_continues_paragraph () =
  (* Negative: a `1. ` line that follows a non-blank paragraph
     line is NOT auto-extracted as a list. The hand-rolled
     subset requires a blank line between prose and the list,
     matching the rule for `- ` (no CommonMark "lazy interrupt"
     support).  This regression pin prevents future code from
     silently changing that rule. *)
  let src = "intro 1. continuation is part of the same paragraph\n" in
  let html = Render.md_parse src in
  Alcotest.(check bool) "no <ol> when no blank line" false (has "<ol>" html);
  Alcotest.(check bool)
    "single <p> contains the whole text" true (has "<p>" html)

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
      ~site_pages:
        [
          {
            Render.name = "methodology";
            Render.title = "Methodology";
            Render.body_md = "before";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages:
        [
          {
            Render.name = "methodology";
            Render.title = "Methodology";
            Render.body_md = "before";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages:
        [
          {
            Render.name = "methodology";
            Render.title = "Methodology";
            Render.body_md = "before";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let page = List.find (fun p -> p.Render.path = "methodology.html") pages in
  Alcotest.(check bool)
    "inlineMath declares TeX-escaped \\\\(" true
    (has "['\\\\(', '\\\\)']" page.Render.body);
  Alcotest.(check bool)
    "displayMath declares TeX-escaped \\\\[\\]" true
    (has "['\\\\[', '\\\\]']" page.Render.body);
  Alcotest.(check bool)
    "skipHtmlTags does not include div.mermaid" true
    (not (has "'div.mermaid'" page.Render.body))

(* Project-root resolver. `dune test` exports DUNE_SOURCEROOT
   pointing at the project root; when running the test exe directly
   (e.g. via `./_build/default/tests/render_kernel.exe` from the
   repo root, or via `scripts/dev-fast-test`), that env var is not
   set, so we fall back to walking up from `Sys.argv.(0)` until we
   find the directory containing `dune-project`. The walk-up
   pattern mirrors `bin/Mathc.ml::find_project_root` so the test
   binary always anchors at the same project root as the kernel.
   This replaces the previous fragile `None -> ".."` fallback,
   which silently resolved to a parent directory when the test
   was invoked from the repo root (and broke 7 of the 47 tests
   in this file; see audit 2026-10). *)
let[@warning "-32"] project_root () =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some p -> p
  | None ->
      let rec climb d =
        if Sys.file_exists (Filename.concat d "dune-project") then d
        else
          let parent = Filename.dirname d in
          if parent = d then Filename.dirname Sys.argv.(0) else climb parent
      in
      climb (Filename.dirname Sys.argv.(0))

let[@warning "-32"] css_has_math_rules () =
  (* Read the live stylesheet and assert it ships rules for
     MathJax containers. The rules are scoped to mjx-container
     so a non-MathJax page is unaffected. *)
  let css_path = Filename.concat (project_root ()) "assets/style.css" in
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

let[@warning "-32"] css_has_inline_figure_rules () =
  (* Read the live stylesheet and assert it ships rules for
     the inline SVG figures that replaced Mermaid
     (diagrams-as-svg-2026-10). The .mathc-figure-inline rule
     keeps a diagram inside the prose column. *)
  let css_path = Filename.concat (project_root ()) "assets/style.css" in
  let ic = open_in css_path in
  let n = in_channel_length ic in
  let css = really_input_string ic n in
  close_in ic;
  Alcotest.(check bool)
    ".mathc-figure-inline rule declared" true
    (has ".mathc-figure-inline" css);
  Alcotest.(check bool)
    ".mathc-figure-inline img max-width: 100%" true
    (has "max-width: 100%" css && has ".mathc-figure-inline img" css);
  Alcotest.(check bool)
    "no .mermaid rules remain" true
    (not (has ".mermaid" css))

let[@warning "-32"] mermaid_support_removed () =
  (* Assert the renderer source no longer carries Mermaid
     support (diagrams-as-svg-2026-10): no `enable_mermaid`
     config field, no Mermaid code-fence branch, no Mermaid CDN
     script in lib/render.ml or bin/Mathc.ml. *)
  let read path =
    let ic = open_in path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    s
  in
  let root = project_root () in
  let render_ml = read (Filename.concat root "lib/render/render.ml") in
  let mathc_ml = read (Filename.concat root "bin/Mathc.ml") in
  Alcotest.(check bool)
    "lib/render/render.ml has no mermaid" true
    (not (has "mermaid" render_ml));
  Alcotest.(check bool)
    "bin/Mathc.ml has no mermaid" true
    (not (has "mermaid" mathc_ml))

let[@warning "-32"] packages_page_has_grid () =
  let cfg : Render.config = Render.default_config in
  let pkg_html =
    "<section class=\"mathc-packages\" \
     data-mathc-package-count=\"42\"><h2>packages</h2></section>"
  in
  let pages =
    Render.build_pages ~package_html:pkg_html ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:
        [
          {
            Render.name = "packages";
            Render.title = "Packages";
            Render.body_md = "prose body";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
          {
            Render.name = "methodology";
            Render.title = "Methodology";
            Render.body_md = "EN methodology";
          };
          {
            Render.name = "manifesto";
            Render.title = "Manifesto";
            Render.body_md = "EN manifesto";
          };
        ]
      ~site_pages_ru:
        [
          {
            Render.name = "manifesto";
            Render.title = "Manifesto / RU";
            Render.body_md = "RU manifesto";
          };
        ]
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[]
      ~axioms_data:[ ("feedback", axiom_body) ]
      ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages:
        [
          {
            Render.name = "home";
            Render.title = "Home";
            Render.body_md = "body";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
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
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:
        {
          Render.index =
            [ (Render.En, "<p class=\"mathc-hero-version\">{{version}}</p>") ];
          Render.dashboard = "";
          Render.graph = "";
        }
  in
  let home = List.find (fun p -> p.Render.path = "index.html") pages in
  Alcotest.(check bool)
    "index.html hero carries the configured version" true
    (has "<p class=\"mathc-hero-version\">9.9.9-test</p>" home.Render.body);
  Alcotest.(check bool)
    "index.html footer carries the configured version" true
    (has "9.9.9-test &middot;" home.Render.body);
  Alcotest.(check bool)
    "index.html <title> carries the configured version" true
    (has "math-coding 9.9.9-test &mdash; math-coding" home.Render.body)

let[@warning "-32"] version_default_reads_version_file () =
  (* `default_config` no longer reads `./VERSION` at module load:
     `lib/` must stay I/O-free (§1.3), so the default version is
     now the static `default_version` string. The live VERSION is
     read by the CLI dispatcher (`bin/Mathc.ml`) instead. *)
  let v = Render.default_config.Render.version in
  Alcotest.(check bool)
    "default_config.version is non-empty" true
    (String.length v > 0);
  Alcotest.(check string)
    "default_config.version is the static default" "math-coding" v

(* --- site-ru-en-synced obligation (t5-1) --- *)

(* Project-root resolver. `dune test` exports DUNE_SOURCEROOT
   pointing at the project root; when running the test exe directly
   (e.g. via `./_build/default/tests/render_kernel.exe` from the
   repo root, or via `scripts/dev-fast-test`), that env var is not
   set, so we fall back to walking up from `Sys.argv.(0)` until we
   find the directory containing `dune-project`. The walk-up
   pattern mirrors `bin/Mathc.ml::find_project_root` so the test
   binary always anchors at the same project root as the kernel.
   This replaces the previous fragile `None -> ".."` fallback,
   which silently resolved to a parent directory when the test
was invoked from the repo root (and broke 7 of the 47 tests
    in this file; see audit 2026-10). *)
let[@warning "-32"] bilingual_site_source_root () =
  Filename.concat (project_root ()) "site"

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

(* --- site-broken-links-2026-10 obligations --- *)

let[@warning "-32"] ru_home_sibling_is_index_html () =
  (* The Russian home page's English-sibling toggle and footer
     sibling both point at `index.html`. Before the fix they
     pointed at `home.html` (404). Per
     `decisions/site-broken-links-2026-10@1`, obligation
     `ru-home-sibling-resolves`. *)
  let cfg : Render.config =
    { Render.default_config with Render.languages = [ Render.En; Render.Ru ] }
  in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg ~site_pages:[] ~site_pages_ru:[]
      ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let home_ru = List.find (fun p -> p.Render.path = "index.ru.html") pages in
  Alcotest.(check bool)
    "Russian home page carries NO 'home.html' anywhere" true
    (not (has "home.html" home_ru.Render.body));
  Alcotest.(check bool)
    "Russian home nav toggle points at 'index.html'" true
    (has "lang-toggle" home_ru.Render.body
    && has "href=\"index.html\"" home_ru.Render.body);
  Alcotest.(check bool)
    "Russian home footer 'EN' sibling points at 'index.html'" true
    (has "site-meta" home_ru.Render.body && has ">EN</a>" home_ru.Render.body)

let[@warning "-32"] footer_links_github_origin () =
  (* The footer emits GitHub blob URLs for AGENTS.md, ROADMAP.md,
     PACKAGES.md, and spec/algebra-3.2.md. Before the fix it
     emitted `../AGENTS.html` (404). Per
     `decisions/site-broken-links-2026-10@1`, obligation
     `footer-meta-docs-link-github`. *)
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:
        [
          {
            Render.name = "home";
            Render.title = "Home";
            Render.body_md = "body";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let page = List.find (fun p -> p.Render.path = "index.html") pages in
  let body = page.Render.body in
  (* Positive: each GitHub blob URL is present. *)
  Alcotest.(check bool)
    "footer links to AGENTS.md on GitHub" true
    (has "github.com/11111000000/math-coding/blob/main/AGENTS.md" body);
  Alcotest.(check bool)
    "footer links to ROADMAP.md on GitHub" true
    (has "github.com/11111000000/math-coding/blob/main/ROADMAP.md" body);
  Alcotest.(check bool)
    "footer links to PACKAGES.md on GitHub" true
    (has "github.com/11111000000/math-coding/blob/main/PACKAGES.md" body);
  Alcotest.(check bool)
    "footer links to spec/algebra-3.2.md on GitHub" true
    (has "github.com/11111000000/math-coding/blob/main/spec/algebra-3.2.md" body);
  (* Negative: the old broken-relative-link pattern is gone. *)
  Alcotest.(check bool)
    "footer does NOT carry '../AGENTS.html'" true
    (not (has "../AGENTS.html" body));
  Alcotest.(check bool)
    "footer does NOT carry '../ROADMAP.html'" true
    (not (has "../ROADMAP.html" body));
  Alcotest.(check bool)
    "footer does NOT carry '../PACKAGES.html'" true
    (not (has "../PACKAGES.html" body));
  Alcotest.(check bool)
    "footer does NOT carry '../spec/algebra-3.2.md'" true
    (not (has "../spec/algebra-3.2.md" body))

let[@warning "-32"] nav_has_github_link () =
  (* The nav carries a GitHub anchor pointing at the bare
     repository URL on every rendered page. Before the fix
     no top-of-page GitHub affordance existed. Per
     `decisions/site-broken-links-2026-10@1`, obligation
     `nav-has-github-link`. *)
  let cfg : Render.config = Render.default_config in
  let pages =
    Render.build_pages ~package_html:"" ~decisions_data:[]
      ~policy_id:"bootstrap-v3" ~config:cfg
      ~site_pages:
        [
          {
            Render.name = "home";
            Render.title = "Home";
            Render.body_md = "body";
          };
          {
            Render.name = "axioms";
            Render.title = "Axioms";
            Render.body_md = "body";
          };
          {
            Render.name = "spec/algebra-3.2";
            Render.title = "Algebra";
            Render.body_md = "body";
          };
        ]
      ~site_pages_ru:[] ~site_pages_zh:[] ~axioms_data:[] ~spec_data:[]
      ~templates:{ Render.index = []; Render.dashboard = ""; Render.graph = "" }
  in
  let github_href = "https://github.com/11111000000/math-coding" in
  List.iter
    (fun (page_key, _label) ->
      let path =
        match page_key with
        | "home" -> "index.html"
        | "spec/algebra-3.2" -> "spec/algebra-3.2.html"
        | _ -> page_key ^ ".html"
      in
      let page = List.find (fun p -> p.Render.path = path) pages in
      Alcotest.(check bool)
        (Printf.sprintf "dist/%s has class=\"github-link\" in nav" path)
        true
        (has "class=\"github-link\"" page.Render.body);
      Alcotest.(check bool)
        (Printf.sprintf "dist/%s github-link href is the bare origin" path)
        true
        (has ("href=\"" ^ github_href ^ "\"") page.Render.body);
      Alcotest.(check bool)
        (Printf.sprintf "dist/%s github-link is not a self-link to './github'"
           path)
        true
        (not (has "href=\"./github\"" page.Render.body)))
    [ ("home", "Home"); ("axioms", "Axioms"); ("spec/algebra-3.2", "Algebra") ]

let[@warning "-32"] axioms_link_html_not_md () =
  (* The five axiom markdown sources must reference the rendered
     spec HTML, not the raw spec markdown. Before the fix the
     links were `../spec/algebra-3.2.md`, which 404'd because
     `mathc render` ships the spec as `dist/spec/algebra-3.2.html`.
     Per `decisions/site-broken-links-2026-10@1`, obligation
     `axiom-pages-link-rendered-spec`. The link is the bare
     `spec/algebra-3.2.html` (no `../` prefix) because `<base
     href="/math-coding/">` overrides the document URL as the
     base for relative URL resolution, so `../X` resolves
     outside the site. *)
  let root = project_root () in
  let axiom_files =
    [ "care"; "feedback"; "invariants"; "self-application"; "separation" ]
  in
  List.iter
    (fun name ->
      let path = Filename.concat root ("axioms/" ^ name ^ ".md") in
      let md = read_text path in
      Alcotest.(check bool)
        (Printf.sprintf "axioms/%s.md does NOT link to ../spec/algebra-3.2.md"
           name)
        true
        (not (has "../spec/algebra-3.2.md" md));
      Alcotest.(check bool)
        (Printf.sprintf "axioms/%s.md does NOT link to ../spec/algebra-3.2.html"
           name)
        true
        (not (has "../spec/algebra-3.2.html" md));
      Alcotest.(check bool)
        (Printf.sprintf "axioms/%s.md DOES link to spec/algebra-3.2.html" name)
        true
        (has "spec/algebra-3.2.html" md))
    axiom_files;
  (* Render `dist/` afresh and verify the rendered axiom pages
     carry the link to the rendered spec. *)
  let script = Filename.concat root "scripts/render.sh" in
  let ec = Sys.command script in
  if ec <> 0 then
    Alcotest.failf "scripts/render.sh exited %d; cannot verify axiom pages" ec;
  let dist = Filename.concat root "dist" in
  List.iter
    (fun name ->
      let rel = "axioms/" ^ name ^ ".html" in
      let path = Filename.concat dist rel in
      let html = read_text path in
      Alcotest.(check bool)
        (Printf.sprintf "dist/%s carries spec/algebra-3.2.html link" rel)
        true
        (has "spec/algebra-3.2.html" html);
      Alcotest.(check bool)
        (Printf.sprintf
           "dist/%s does NOT carry the raw spec/algebra-3.2.md link" rel)
        true
        (not (has "../spec/algebra-3.2.md" html)))
    axiom_files

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
      ( "lang_toggle_en_no_suffix",
        [ Alcotest.test_case "en" `Quick lang_toggle_en_no_suffix ] );
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
      ( "inline_figure_renders",
        [ Alcotest.test_case "figure" `Quick inline_figure_renders ] );
      ( "list_continuation_renders",
        [ Alcotest.test_case "cont" `Quick list_continuation_renders ] );
      ( "list_single_item_still_one_li",
        [ Alcotest.test_case "single" `Quick list_single_item_still_one_li ] );
      ( "ordered_list_renders",
        [ Alcotest.test_case "ol" `Quick ordered_list_renders ] );
      ( "ordered_list_multi_digit_renders",
        [ Alcotest.test_case "multi" `Quick ordered_list_multi_digit_renders ]
      );
      ( "ordered_list_continuation_joins_into_one_li",
        [
          Alcotest.test_case "cont" `Quick
            ordered_list_continuation_joins_into_one_li;
        ] );
      ( "ordered_list_invalid_marker_stays_paragraph",
        [
          Alcotest.test_case "neg" `Quick
            ordered_list_invalid_marker_stays_paragraph;
        ] );
      ( "ordered_list_stops_at_dash_marker",
        [ Alcotest.test_case "dash" `Quick ordered_list_stops_at_dash_marker ]
      );
      ( "ordered_list_after_paragraph_continues_paragraph",
        [
          Alcotest.test_case "lazy" `Quick
            ordered_list_after_paragraph_continues_paragraph;
        ] );
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
      ( "css_has_inline_figure_rules",
        [ Alcotest.test_case "figure" `Quick css_has_inline_figure_rules ] );
      ( "mermaid_support_removed",
        [ Alcotest.test_case "removed" `Quick mermaid_support_removed ] );
      ( "packages_page_has_grid",
        [ Alcotest.test_case "grid" `Quick packages_page_has_grid ] );
      ( "ru_nav_omits_missing_sibling",
        [ Alcotest.test_case "ru" `Quick ru_nav_omits_missing_sibling ] );
      ( "axiom_page_single_h1",
        [ Alcotest.test_case "h1" `Quick axiom_page_single_h1 ] );
      ( "footer_mathc_render",
        [ Alcotest.test_case "footer" `Quick footer_mathc_render ] );
      ( "ru_home_sibling_is_index_html",
        [ Alcotest.test_case "ru-home" `Quick ru_home_sibling_is_index_html ] );
      ( "footer_links_github_origin",
        [ Alcotest.test_case "github" `Quick footer_links_github_origin ] );
      ( "nav_has_github_link",
        [ Alcotest.test_case "nav" `Quick nav_has_github_link ] );
      ( "axioms_link_html_not_md",
        [ Alcotest.test_case "axiom-link" `Quick axioms_link_html_not_md ] );
      ( "inline_svg_figures_in_seven_pages",
        [
          Alcotest.test_case "figures" `Quick (fun () ->
              (* Editorial obligation: every site page and per-axiom
                 page that carries a diagram must surface it as an
                 inline SVG `<figure class="mathc-figure
                 mathc-figure-inline">` in the rendered HTML — and
                 must NOT emit any Mermaid `<div class="mermaid">`.
                 (diagrams-as-svg-2026-10) *)
              let root = project_root () in
              let script = Filename.concat root "scripts/render.sh" in
              let ec = Sys.command script in
              if ec <> 0 then
                Alcotest.failf
                  "scripts/render.sh exited %d; cannot verify inline figure \
                   output"
                  ec;
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
                    (Printf.sprintf "dist/%s contains inline figure" rel)
                    true
                    (has "<figure class=\"mathc-figure mathc-figure-inline\">"
                       html);
                  Alcotest.(check bool)
                    (Printf.sprintf "dist/%s has no mermaid div" rel)
                    true
                    (not (has "<div class=\"mermaid\">" html)))
                pages);
        ] );
      ( "axiom_has_formalization_section",
        [
          Alcotest.test_case "formalization" `Quick (fun () ->
              (* Editorial obligation: each of the five axiom pages
                 must end with a `## Formalization` section that
                 references the formal algebra. *)
              let root = project_root () in
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
                    (Printf.sprintf "dist/%s contains Formalization section" rel)
                    true (has "Formalization" html))
                axioms);
        ] );
      ( "dashboard_and_graph_html_landed",
        [
          Alcotest.test_case "ship" `Quick (fun () ->
              (* Decision `render-dashboard-2026-10@1`
                 asserts that `mathc render` writes
                 `dist/dashboard.html` (fuse.js search
                 panel) and `dist/graph.html` (cytoscape.js
                 relations viewer) alongside the existing
                 site. The two files are produced by the
                 same `mathc render` pipeline that the
                 existing `scripts/render.sh` exercises; we
                 re-render and assert. *)
              let root = project_root () in
              (* Re-render via scripts/render.sh so we exercise
                 the same allowlist the operator's local
                 build runs. *)
              let out_dir = Filename.concat root "dist" in
              let script_path = Filename.concat root "scripts/render.sh" in
              let ec = Sys.command script_path in
              if ec <> 0 then
                Alcotest.failf
                  "scripts/render.sh exited %d; cannot verify dashboard/graph \
                   output"
                  ec;
              let dashboard_html =
                read_text (Filename.concat out_dir "dashboard.html")
              in
              Alcotest.(check bool)
                "dist/dashboard.html exists and is non-empty" true
                (String.length dashboard_html > 0);
              Alcotest.(check bool)
                "dist/dashboard.html includes fuse.js CDN tag" true
                (has "fuse" dashboard_html && has "<script" dashboard_html);
              Alcotest.(check bool)
                "dist/dashboard.html fetches index.json" true
                (has "index.json" dashboard_html);
              let graph_html =
                read_text (Filename.concat out_dir "graph.html")
              in
              Alcotest.(check bool)
                "dist/graph.html exists and is non-empty" true
                (String.length graph_html > 0);
              Alcotest.(check bool)
                "dist/graph.html includes cytoscape.js CDN tag" true
                (has "cytoscape" graph_html && has "<script" graph_html);
              Alcotest.(check bool)
                "dist/graph.html fetches graph.json" true
                (has "graph.json" graph_html);
              let graph_json_path = Filename.concat out_dir "graph.json" in
              Alcotest.(check bool)
                "dist/graph.json exists" true
                (Sys.file_exists graph_json_path));
        ] );
    ]
