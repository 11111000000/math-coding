(* lib/render/render_nav.ml — navigation, chrome, and page shell.

   Split from lib/render/render.ml. Renders the site nav, footer,
   head, and the full HTML page shell. Depends on render_lang and
   render_md. *)

open Render_lang
open Render_md

(* --- navigation (site-redesign-2026-10) ---
 *
 * The 12 flat top-level links of the v3 site overflowed the
 * desktop row and broke into two lines on every viewport
 * between 1024 px and 1440 px (the typical developer laptop
 * range). The fix groups the same pages into four intent-
 * bearing categories under dropdown panels, with the Home
 * link staying a direct anchor.
 *
 * Categories:
 *   - Concept      — the why and the philosophical anchors
 *                    (Manifesto, Foundations, Axioms).
 *   - Methodology  — the how: how the chain is built, how it
 *                    lands, how it survives a protocol change
 *                    (Methodology, Workflow, Bootstrap Gate).
 *   - Adopt        — practical entry points for new users
 *                    (README, Install, FAQ, Contributing).
 *   - Reference    — the technical surface
 *                    (Packages, Algebra).
 *
 * The mapping is closed in this file so a future page can be
 * added by appending to exactly one list per language. *)

type nav_link = { key : string; label : string; href : string }

type nav_group = {
  group_key : string;
  group_label : string;
  links : nav_link list;
}

let[@warning "-32"] nav_groups_en : nav_group list =
  [
    {
      group_key = "concept";
      group_label = "Concept";
      links =
        [
          { key = "manifesto"; label = "Manifesto"; href = "manifesto.html" };
          {
            key = "foundations";
            label = "Foundations";
            href = "foundations.html";
          };
          { key = "axioms"; label = "Axioms"; href = "axioms.html" };
        ];
    };
    {
      group_key = "methodology";
      group_label = "Methodology";
      links =
        [
          {
            key = "methodology";
            label = "Methodology";
            href = "methodology.html";
          };
          { key = "workflow"; label = "Workflow"; href = "workflow.html" };
          {
            key = "bootstrap-gate";
            label = "Bootstrap Gate";
            href = "bootstrap-gate.html";
          };
          {
            key = "differences";
            label = "Differences";
            href = "differences.html";
          };
        ];
    };
    {
      group_key = "adopt";
      group_label = "Adopt";
      links =
        [
          { key = "readme"; label = "README"; href = "readme.html" };
          { key = "install"; label = "Install"; href = "install.html" };
          { key = "faq"; label = "FAQ"; href = "faq.html" };
          {
            key = "contributing";
            label = "Contributing";
            href = "contributing.html";
          };
        ];
    };
    {
      group_key = "reference";
      group_label = "Reference";
      links =
        [
          { key = "packages"; label = "Packages"; href = "packages.html" };
          {
            key = "spec/kernel-contract";
            label = "Algebra";
            href = "spec/kernel-contract.html";
          };
        ];
    };
  ]

let[@warning "-32"] nav_groups_ru : nav_group list =
  [
    {
      group_key = "concept";
      group_label = "Идея";
      links =
        [
          { key = "manifesto"; label = "Манифест"; href = "manifesto.ru.html" };
          {
            key = "foundations";
            label = "Основания";
            href = "foundations.ru.html";
          };
          { key = "axioms"; label = "Аксиомы"; href = "axioms.html" };
        ];
    };
    {
      group_key = "methodology";
      group_label = "Методология";
      links =
        [
          {
            key = "methodology";
            label = "Методология";
            href = "methodology.html";
          };
          { key = "workflow"; label = "Workflow"; href = "workflow.html" };
          {
            key = "bootstrap-gate";
            label = "Bootstrap-ворота";
            href = "bootstrap-gate.html";
          };
          {
            key = "differences";
            label = "Отличия";
            href = "differences.ru.html";
          };
        ];
    };
    {
      group_key = "adopt";
      group_label = "Внедрить";
      links =
        [
          { key = "readme"; label = "README"; href = "readme.ru.html" };
          { key = "install"; label = "Установка"; href = "install.ru.html" };
          { key = "faq"; label = "FAQ"; href = "faq.html" };
          {
            key = "contributing";
            label = "Contributing";
            href = "contributing.html";
          };
        ];
    };
    {
      group_key = "reference";
      group_label = "Справочник";
      links =
        [
          { key = "packages"; label = "Пакеты"; href = "packages.html" };
          {
            key = "spec/kernel-contract";
            label = "Алгебра";
            href = "spec/kernel-contract.html";
          };
        ];
    };
  ]

(* Chinese nav groups. Follows the same four-category shape as
   EN/RU. Sibling hrefs point at the `.zh.html` files generated
   when `--lang=zh|all` is passed. The per-decision, per-axiom
   and per-spec pages remain EN-only (they were EN-only for RU
   already, see `build_pages`'s per-decision loop), so links
   under "spec/kernel-contract" and the per-decision sibling toggles
   use the EN URL — this matches what the dispatcher does for
   the Russian home page. *)
let[@warning "-32"] nav_groups_zh : nav_group list =
  [
    {
      group_key = "concept";
      group_label = "理念";
      links =
        [
          { key = "manifesto"; label = "宣言"; href = "manifesto.zh.html" };
          { key = "foundations"; label = "基石"; href = "foundations.zh.html" };
          { key = "axioms"; label = "公理"; href = "axioms.html" };
        ];
    };
    {
      group_key = "methodology";
      group_label = "方法";
      links =
        [
          { key = "methodology"; label = "方法论"; href = "methodology.zh.html" };
          { key = "workflow"; label = "流程"; href = "workflow.zh.html" };
          {
            key = "bootstrap-gate";
            label = "引导闸门";
            href = "bootstrap-gate.zh.html";
          };
          { key = "differences"; label = "区别"; href = "differences.zh.html" };
        ];
    };
    {
      group_key = "adopt";
      group_label = "采用";
      links =
        [
          { key = "readme"; label = "README"; href = "readme.zh.html" };
          { key = "install"; label = "安装"; href = "install.zh.html" };
          { key = "faq"; label = "FAQ"; href = "faq.zh.html" };
          {
            key = "contributing";
            label = "Contributing";
            href = "contributing.zh.html";
          };
        ];
    };
    {
      group_key = "reference";
      group_label = "参考";
      links =
        [
          { key = "packages"; label = "数据包"; href = "packages.zh.html" };
          {
            key = "spec/kernel-contract";
            label = "代数";
            href = "spec/kernel-contract.html";
          };
        ];
    };
  ]

let[@warning "-32"] nav_groups_for lang =
  match lang with
  | Ru -> nav_groups_ru
  | Zh -> nav_groups_zh
  | En -> nav_groups_en

(* `sibling_langs` is the list of additional languages for which
   the current page has a sibling rendering. The English page
   always lists Russian/ZH/etc. siblings; the Russian/ZH page
   always lists English (and any other non-source siblings). The
   set is closed: a sibling is listed only when a rendered HTML
   file actually exists on disk. See `build_pages` for the
   construction. *)
let[@warning "-32"] lang_href_for ~lang ~page_key =
  (* Build the file path for a sibling in `lang`. English is the
     source language: per-page English files live at `<page_key>.html`
     (e.g. `manifesto.html`, `axioms.html`) — they are NOT suffixed
     with `.en`. Every non-source sibling carries an explicit
     `.ru` / `.zh` suffix. The previous unconditional
     `page_key ^ "." ^ lang ^ ".html"` produced a 404 link for the
     EN toggle on any non-EN page (the nav / footer then pointed at
     `manifesto.en.html`, `axioms.en.html`, etc.). The `home` page
     is additionally special: its English name is `index.html` rather
     than `home.html`, while its non-source siblings are
     `index.<lang>.html`. Mirrored by `sibling_translation_href`'s
     per-call propagation. *)
  match (page_key, lang) with
  | "home", En -> "index.html"
  | "home", l -> "index." ^ lang_code l ^ ".html"
  | _, En -> page_key ^ ".html"
  | _, l -> page_key ^ "." ^ lang_code l ^ ".html"

let[@warning "-32"] sibling_translation_href ~lang ~page_key ~sibling_langs =
  (* `sibling_langs` is the closed set of non-source languages for
     which the page has a rendering. The toggle in the nav/footer
     picks the FIRST entry (i.e. the canonical alternate). When
     the current page is EN, that entry is `ru` (when present),
     then `zh`; when the current page is RU, the first entry is
     `en`, then `zh`; and so on. The previous hard-coded
     `has_ru : bool` was generalised to a list to support the
     third language without growing the parameter list further.
     The `home` page_key is special: `page_key ^ ".html"` would
     produce `home.html` (which does not exist), so the home
     page's sibling href is always `index.<lang>.html` — the
     file the renderer actually ships at the site root. *)
  let pick_first_available langs =
    (* Returns the first lang in `langs` that is NOT the current
       page's source language. The result is the alternate-language
       the toggle advertises. The English page's natural alternate
       is Russian; the Russian page's natural alternate is English. *)
    List.find_opt (fun l -> l <> lang) langs
  in
  match pick_first_available sibling_langs with
  | None -> None
  | Some alt -> Some (lang_href_for ~lang:alt ~page_key)

(* The canonical upstream GitHub origin. Footer and nav links
   point here for meta-docs (AGENTS.md, ROADMAP.md, PACKAGES.md,
   spec/kernel-contract.md) and the bare repository URL, so the
   site does not depend on the math-coding HTTP deployment to
   host these references. The previous footer emitted
   `../AGENTS.html`, `../ROADMAP.html`, `../PACKAGES.html`,
   which resolved under `<base href="/math-coding/">` to
   `/AGENTS.html`, etc. — none of which existed; every footer
   link was a 404. Per `decisions/site-broken-links-2026-10@1`,
   those URLs are now GitHub blob URLs. *)
let github_origin = "https://github.com/11111000000/math-coding"
let github_blob ~path = Printf.sprintf "%s/blob/main/%s" github_origin path

let[@warning "-32"] render_nav ~lang ~page_key ~enable_lang_toggle
    ~sibling_langs =
  let buf = Buffer.create 512 in
  let groups = nav_groups_for lang in
  Buffer.add_string buf "<nav class=\"site-nav\">\n";
  (* Brand: logo + name. The logo is an inline-friendly SVG so a
     keyboard user still gets the visible "math-coding" text
     label inside the same anchor. *)
  Buffer.add_string buf
    "  <a class=\"brand\" href=\"./\"><img class=\"brand-logo\" \
     src=\"assets/logo.svg\" alt=\"\" aria-hidden=\"true\"><span \
     class=\"brand-text\">math-coding</span></a>\n";
  (* The hamburger toggle collapses the inner into a column on
     narrow viewports. On desktop the inner is the visible row;
     the toggle is hidden visually but kept in the DOM so the
     mobile behaviour is preserved. *)
  Buffer.add_string buf
    "  <button type=\"button\" class=\"nav-toggle\" aria-label=\"Toggle \
     navigation\" aria-controls=\"nav-inner\" aria-expanded=\"false\"><span \
     aria-hidden=\"true\">&#9776;</span></button>\n";
  Buffer.add_string buf "  <ul class=\"nav-inner\" id=\"nav-inner\">\n";
  (* Home as a direct anchor. The four categorical groups follow. *)
  let home_active_cls =
    if page_key = "home" then " class=\"nav-link active\""
    else " class=\"nav-link\""
  in
  let home_href = "index" ^ lang_suffix lang ^ ".html" in
  let home_label = if lang = Ru then "Главная" else "Home" in
  Printf.bprintf buf
    "    <li class=\"nav-item-direct\"><a%s href=\"%s\">%s</a></li>\n"
    home_active_cls home_href home_label;
  (* Stable id per group so the toggle can reference its panel via
     aria-controls. The id is derived from the group label slug
     plus a numeric fallback so two groups with the same label
     still get distinct ids. The counter is also stamped on the
     outer <li> as data-nav-group for JS and styling hooks. *)
  let group_counter = ref 0 in
  List.iter
    (fun group ->
      let group_active = List.exists (fun l -> l.key = page_key) group.links in
      incr group_counter;
      let panel_id = Printf.sprintf "nav-panel-%d" !group_counter in
      Printf.bprintf buf
        "    <li class=\"nav-group%s\" data-nav-group=\"%d\">\n\
        \      <button type=\"button\" class=\"nav-group-toggle\" \
         aria-expanded=\"false\" aria-controls=\"%s\"><span \
         class=\"nav-group-label\">%s</span><span class=\"nav-group-caret\" \
         aria-hidden=\"true\">&#9662;</span></button>\n\
        \      <ul class=\"nav-group-panel\" id=\"%s\">\n"
        (if group_active then " is-active" else "")
        !group_counter panel_id
        (html_escape group.group_label)
        panel_id;
      List.iter
        (fun link ->
          let cls =
            if link.key = page_key then
              " class=\"nav-link nav-group-link active\""
            else " class=\"nav-link nav-group-link\""
          in
          Printf.bprintf buf "        <li><a%s href=\"%s\">%s</a></li>\n" cls
            link.href link.label)
        group.links;
      Buffer.add_string buf "      </ul>\n    </li>\n")
    groups;
  Buffer.add_string buf "  </ul>\n";
  (* Persistent GitHub anchor. Lives in the nav on every rendered
     page so a visitor landing on any non-home page has a top-
     of-page affordance for the upstream repository. Per
     `decisions/site-broken-links-2026-10@1`. The icon is an
     inline SVG to avoid an extra HTTP round-trip; the visible
     text is "GitHub" so a keyboard-only visitor can reach the
     link without depending on the SVG's accessibility tree. *)
  Printf.bprintf buf
    "  <a class=\"github-link\" href=\"%s\" aria-label=\"%s\"><svg \
     class=\"github-icon\" viewBox=\"0 0 16 16\" width=\"20\" height=\"20\" \
     aria-hidden=\"true\" focusable=\"false\"><path fill=\"currentColor\" \
     d=\"M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 \
     0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 \
     1.08.58 1.23.82.72 1.21 1.87.87 \
     2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 \
     0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 \
     1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 \
     1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 \
     3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 \
     8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z\"/></svg><span \
     class=\"github-label\">GitHub</span></a>\n"
    github_origin "math-coding on GitHub";
  if enable_lang_toggle then
    (* One toggle per non-source sibling. With two languages
        (EN+RU) this renders a single "RU" / "EN" toggle, the
        same UX as the previous build. With three languages
        (EN+RU+ZH), the EN home emits both "RU" and "ZH"
        toggles so a visitor lands on EN and can reach ZH
        without first visiting RU. The order is the natural
        alternation order built by `sibling_langs_for`: RU
        first (canonical alternate), then ZH, then EN. Each
        toggle carries the `hreflang` and `lang` attributes
        for accessibility / SEO; the visible label is the
        two-letter language id in upper case (e.g. "RU"). *)
    List.iter
      (fun other_lang ->
        if other_lang <> lang then
          let href = lang_href_for ~lang:other_lang ~page_key in
          let other_label = String.uppercase_ascii (lang_code other_lang) in
          Printf.bprintf buf
            "  <a class=\"lang-toggle\" href=\"%s\" hreflang=\"%s\" \
             lang=\"%s\">%s</a>\n"
            href (lang_code other_lang) (lang_code other_lang) other_label)
      sibling_langs;
  Buffer.add_string buf "</nav>\n";
  Buffer.contents buf

(* --- footer --- *)

let[@warning "-32"] render_footer ~lang ~version ~page_key ~sibling_langs =
  (* The footer always carries the live project version so a viewer
     who lands on the site can tell which build is live. The string
     is whatever was passed via `config.version` — by default
     this is the contents of the `VERSION` file at render-time.
     The language links in the footer mirror the nav toggles: one
     `<a>` per non-source sibling. The order is the natural
     alternation order built by `sibling_langs_for`: RU first
     (canonical alternate), then ZH, then EN. The meta-doc
     anchors (AGENTS.md, ROADMAP.md, PACKAGES.md) and the kernel
     contract link point at the canonical GitHub blob URL — the
     GitHub UI renders the markdown so a visitor lands on a
     rendered page, not raw source. *)
  let lang_link =
    let links =
      List.filter_map
        (fun other_lang ->
          if other_lang = lang then None
          else
            let href = lang_href_for ~lang:other_lang ~page_key in
            let other_label = String.uppercase_ascii (lang_code other_lang) in
            Some
              (Printf.sprintf "<a href=\"%s\">%s</a>" (html_escape href)
                 other_label))
        sibling_langs
    in
    String.concat " &middot; " links
  in
  let agents_href = github_blob ~path:"AGENTS.md" in
  let roadmap_href = github_blob ~path:"ROADMAP.md" in
  let packages_href = github_blob ~path:"PACKAGES.md" in
  let contract_href = github_blob ~path:"spec/kernel-contract.md" in
  let site_meta =
    Printf.sprintf
      "<p class=\"site-meta\">%s &middot; <a href=\"%s\">AGENTS.md</a> \
       &middot; <a href=\"%s\">ROADMAP.md</a> &middot; <a \
       href=\"%s\">PACKAGES.md</a> &middot; <a \
       href=\"%s\">spec/kernel-contract.md</a>%s%s</p>\n"
      (html_escape version) (html_escape agents_href) (html_escape roadmap_href)
      (html_escape packages_href)
      (html_escape contract_href)
      (if lang_link = "" then "" else " &middot; ")
      lang_link
  in
  Printf.sprintf
    "<footer class=\"site-footer\">\n\
     <p>Built by <code>mathc render</code> at build time. The site follows the \
     math-coding methodology: every page that describes a kernel feature is \
     itself produced by the kernel.</p>\n\
     %s</footer>\n"
    site_meta

(* --- page renderer --- *)

(* `<head>` carries: charset, viewport, <base href>, title, the
   stylesheet, optional MathJax script, and any caller-supplied
   extra head. (Mermaid was removed in diagrams-as-svg-2026-10;
   diagrams are now inline SVGs under `![alt](assets/foo.svg)`.) *)
let[@warning "-32"] render_head ~lang ~site_base ~title ~enable_mathjax
    ~extra_head =
  let buf = Buffer.create 256 in
  Printf.bprintf buf "<meta charset=\"utf-8\">\n";
  Printf.bprintf buf
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n";
  if site_base <> "" then
    Printf.bprintf buf "<base href=\"%s\">\n" (html_escape site_base);
  Printf.bprintf buf "<title>%s &mdash; math-coding</title>\n"
    (html_escape title);
  (* RSS autodiscovery (Phase 4 of site-quality-distribution-2026-10):
     every page exposes a `<link rel="alternate">` pointing at
     `feed.xml` so an RSS reader can subscribe from any page
     without first visiting the home page. *)
  Printf.bprintf buf
    "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"math-coding \
     decisions\" href=\"%sfeed.xml\">\n"
    (if site_base = "" then "" else site_base);
  Printf.bprintf buf "<link rel=\"stylesheet\" href=\"assets/style.css\">\n";
  if enable_mathjax then begin
    Printf.bprintf buf
      "<script defer \
       src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js\"></script>\n";
    (* MathJax 3 TeX-unescapes the inlineMath/displayMath delimiter
       strings. To make the final delimiter the LaTeX sequence
       `\('\` (which is what user text must contain to start
       math), the source must be `\\('` (4 chars: `\\` is
       TeX-escape for `\`, then literal `(`). MathJax
       unescapes to `\\(` then to `\(` and to `\(`.
       In OCaml source, `\\\\('` is 6 source chars (4 backslashes) and emits
       the 3-char runtime string `\\\\('` = `\\\\('`
       in JS, which the TeX-unescape pass converts to
       `\\(` = `\(` (the 2-char delimiter we want). Tested
       empirically: with this string, MathJax's runtime
       config shows the delimiter as `\(` and the
       `t.replace is not a function` error is gone. *)
    Printf.bprintf buf
      "<script>\n\
       window.MathJax = { tex: { inlineMath: [['\\\\(', '\\\\)']], \
       displayMath: [['\\\\[', '\\\\]']] }, options: { skipHtmlTags: \
       ['script', 'noscript', 'style', 'textarea', 'pre', 'code'] } };\n\
       </script>\n"
  end;
  if extra_head <> "" then Printf.bprintf buf "%s\n" extra_head;
  Buffer.contents buf

let[@warning "-32"] render_page ~lang ~page_key ~title ~body ~site_base
    ~enable_mathjax ~enable_lang_toggle ~sibling_langs ~version ~extra_head =
  let head = render_head ~lang ~site_base ~title ~enable_mathjax ~extra_head in
  Printf.sprintf
    "<!DOCTYPE html>\n\
     <html lang=\"%s\">\n\
     <head>\n\
     %s</head>\n\
     <body>\n\
     %s\n\
     <main class=\"site-main\">\n\
     %s\n\
     </main>\n\
     %s\n\
     <script defer src=\"assets/site.js\"></script>\n\
     </body>\n\
     </html>\n"
    (lang_code lang) head
    (render_nav ~lang ~page_key ~enable_lang_toggle ~sibling_langs)
    body
    (render_footer ~lang ~version ~page_key ~sibling_langs)
