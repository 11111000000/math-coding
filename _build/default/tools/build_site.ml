(* tools/build_site.ml — render math/<name>/packet.md into static HTML.
 *
 * Usage:
 *   tools/build_site.exe math_dir dist_dir
 *
 * Reuses Math_coding_lib.Parse.parse_packet so that packet format
 * is defined once. No third-party markdown parser; a tiny markdown
 * subset handles the bodies.
 *
 * Per-packet page renders:
 *   - YAML frontmatter (parsed via Math_coding_lib.Parse): proposition,
 *     antithesis, synthesis, status, axiom, substrate
 *   - Markdown body (subset: ## headings, ``` blocks, paragraphs)
 *)

let html_escape s =
  let len = String.length s in
  let buf = Buffer.create (len + 16) in
  let rec loop i =
    if i >= len then ()
    else
      let c = s.[i] in
      match c with
      | '&' -> Buffer.add_string buf "&amp;"; loop (i + 1)
      | '<' -> Buffer.add_string buf "&lt;"; loop (i + 1)
      | '>' -> Buffer.add_string buf "&gt;"; loop (i + 1)
      | '"' -> Buffer.add_string buf "&quot;"; loop (i + 1)
      | _ -> Buffer.add_char buf c; loop (i + 1)
  in
  loop 0;
  Buffer.contents buf

(* Split packet.md content into frontmatter and body via the
 * canonical parser in Math_coding_lib.Parse. *)
let split (content : string) : string * string =
  match Math_coding_lib.Parse.split_frontmatter content with
  | Some (fm, body) -> (fm, body)
  | None -> ("", content)

(* Site navigation helpers used by the new design. *)
let site_nav _current =
  let items = [
    "index.html", "overview";
    "about.html", "about";
    "guide.html", "guide";
    "substrates.html", "substrates";
    "axioms.html", "axioms";
    "installing.html", "installing";
    "packets.html", "packets";
  ] in
  let buf = Buffer.create 512 in
  Buffer.add_string buf "<nav class=\"site-nav\">";
  List.iter (fun (href, label) ->
    let active = if href = _current then " aria-current=\"page\"" else "" in
    Printf.bprintf buf "  <a href=\"%s\"%s>%s</a>" href active label
  ) items;
  Buffer.add_string buf "</nav>\n";
  Buffer.contents buf

let page_header _current title =
  let nav = site_nav _current in
  Printf.sprintf
    "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n\
     <meta charset=\"utf-8\">\n\
     <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
     <meta name=\"color-scheme\" content=\"light dark\">\n\
     <title>%s — math-coding v1.0</title>\n\
     <link rel=\"stylesheet\" href=\"assets/tokens.css\">\n\
     </head>\n<body>\n%s"
    (html_escape title) nav

let page_footer _current =
  let nav_links = [
    "index.html", "overview";
    "about.html", "about";
    "guide.html", "guide";
    "substrates.html", "substrates";
    "axioms.html", "axioms";
    "installing.html", "installing";
    "packets.html", "packets";
  ] in
  let buf = Buffer.create 512 in
  Buffer.add_string buf "<footer class=\"site-foot\"><p>";
  Buffer.add_string buf "math-coding v1.0 · Living Beings License · ";
  List.iteri (fun i (href, label) ->
    if i > 0 then Buffer.add_string buf " · ";
    Printf.bprintf buf "<a href=\"%s\">%s</a>" href label
  ) nav_links;
  Buffer.add_string buf "</p></footer>\n</body>\n</html>\n";
  Buffer.contents buf

(* Tiny markdown subset: paragraphs, ## headings, ``` blocks. *)
let render_md md =
  let buf = Buffer.create (String.length md * 2) in
  let lines = String.split_on_char '\n' md in
  let in_code = ref false in
  let paragraph = ref [] in
  let flush_paragraph () =
    if !paragraph <> [] then begin
      Buffer.add_string buf "<p>";
      List.iter (fun line ->
        Buffer.add_string buf (html_escape line);
        Buffer.add_char buf ' '
      ) !paragraph;
      Buffer.add_string buf "</p>\n";
      paragraph := []
    end
  in
  let rec process = function
    | [] -> flush_paragraph ()
    | line :: rest ->
        if !in_code then begin
          if line = "```" then begin
            Buffer.add_string buf "</code></pre>\n";
            in_code := false
          end else begin
            Buffer.add_string buf (html_escape line);
            Buffer.add_char buf '\n'
          end;
          process rest
        end else if line = "```" then begin
          flush_paragraph ();
          Buffer.add_string buf "<pre><code>";
          in_code := true;
          process rest
        end else if String.starts_with ~prefix:"## " line then begin
          flush_paragraph ();
          let title = String.sub line 3 (String.length line - 3) in
          Buffer.add_string buf "<h3>";
          Buffer.add_string buf (html_escape title);
          Buffer.add_string buf "</h3>\n";
          process rest
        end else if String.starts_with ~prefix:"# " line then begin
          flush_paragraph ();
          let title = String.sub line 2 (String.length line - 2) in
          Buffer.add_string buf "<h2>";
          Buffer.add_string buf (html_escape title);
          Buffer.add_string buf "</h2>\n";
          process rest
        end else if line = "" then begin
          flush_paragraph ();
          process rest
        end else begin
          paragraph := line :: !paragraph;
          process rest
        end
  in
  process lines;
  Buffer.contents buf

(* Render one packet page using the canonical parser. *)
let render_packet_html (name : string) (content : string) =
  let module P = Math_coding_lib.Packet in
  let pkt = Math_coding_lib.Parse.parse_packet name ("math/" ^ name) content in
  let buf = Buffer.create 4096 in
  let lifecycle_to_string = function
    | P.Draft -> "draft"
    | P.Applied -> "applied"
    | P.Drift -> "drift"
    | P.Stale -> "stale"
    | P.Retired -> "retired"
    | P.Abandoned -> "abandoned"
  in
  let status_str = match pkt.P.status with
    | Some s -> lifecycle_to_string s
    | None -> "draft"
  in
  let status_class = Printf.sprintf "status-%s" status_str in

  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>math-coding | ";
  Buffer.add_string buf (html_escape name);
  Buffer.add_string buf "</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n";
  Buffer.add_string buf "  <a href=\"index.html\">index</a>\n";
  Buffer.add_string buf "  <a href=\"axioms.html\">axioms</a>\n";
  Buffer.add_string buf "  <a href=\"installing.html\">installing</a>\n";
  Buffer.add_string buf "</nav>\n";

  Buffer.add_string buf "<h1>";
  if P.substrate_to_string pkt.P.substrate <> "none" then begin
    Buffer.add_string buf "<span class=\"axiom\">";
    Buffer.add_string buf (html_escape name);
    Buffer.add_string buf "</span>"
  end else begin
    Buffer.add_string buf (html_escape name)
  end;
  Buffer.add_string buf "</h1>\n";

  Buffer.add_string buf "<dl class=\"facts\">\n";
  Printf.bprintf buf "<dt>Status</dt><dd><span class=\"%s\">%s</span></dd>\n"
    status_class (html_escape status_str);
  (match pkt.P.axiom with
   | Some a ->
       Printf.bprintf buf "<dt>Axiom</dt><dd><span class=\"axiom\">%s</span></dd>\n"
         (html_escape a)
   | None -> ());
  (match pkt.P.substrate with
   | s ->
       let s_str = P.substrate_to_string s in
       if s_str <> "none" then
         Printf.bprintf buf "<dt>Substrate</dt><dd><code>%s</code></dd>\n"
           (html_escape s_str));
  (match pkt.P.intent with
   | Some i -> Printf.bprintf buf "<dt>Intent</dt><dd>%s</dd>\n" (html_escape i)
   | None -> ());
  (match pkt.P.superseded_by with
   | Some s ->
       Printf.bprintf buf "<dt>Superseded by</dt><dd><code>%s</code></dd>\n"
         (html_escape s)
   | None -> ());
  Buffer.add_string buf "</dl>\n";

  Printf.bprintf buf
    "<section class=\"theorem\"><h3>Proposition</h3>\n<p>%s</p>\n</section>\n"
    (html_escape pkt.P.proposition);

  (match pkt.P.antithesis with
   | Some a ->
       Buffer.add_string buf
         "<section><h3 class=\"antithesis\">Antithesis</h3>\n<p>";
       Buffer.add_string buf (html_escape a);
       Buffer.add_string buf "</p>\n</section>\n"
   | None -> ());

  (match pkt.P.synthesis with
   | Some s ->
       Buffer.add_string buf
         "<section class=\"proof-block\"><h3 class=\"synthesis\">Synthesis</h3>\n<p>";
       Buffer.add_string buf (html_escape s);
       Buffer.add_string buf "</p>\n</section>\n"
   | None -> ());

  let _, body = split content in
  Buffer.add_string buf "<section><h3>Body</h3>\n";
  Buffer.add_string buf (render_md body);
  Buffer.add_string buf "</section>\n";

  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf "<p>math-coding v1.0 · Living Beings License · ";
  Buffer.add_string buf "<a href=\"index.html\">index</a>";
  Buffer.add_string buf "</p>\n</footer>\n</body>\n</html>\n";
  Buffer.contents buf

let render_index (packets : (string * string * bool) list) =
  let n_axiom = List.length (List.filter (fun (_, _, is_axiom) -> is_axiom) packets) in
  let n_v1 = List.length packets - n_axiom in
  let buf = Buffer.create 4096 in
  Buffer.add_string buf (page_header "index.html" "math-coding");
  Buffer.add_string buf "<section class=\"hero\">\n";
  Buffer.add_string buf "<h1>math-coding</h1>\n";
  Buffer.add_string buf "<p>A convention for documenting decisions in code.</p>\n";
  Buffer.add_string buf "<p class=\"formula\">decisions = packet &times; git &times; one binary</p>\n";
  Buffer.add_string buf "</section>\n";
  Printf.bprintf buf
    "<p>Currently <strong>%d packets</strong> (%d axiom + %d v1.0 design). Lifecycle is observed, not assigned.</p>\n"
    (List.length packets) n_axiom n_v1;
  Buffer.add_string buf "<h2>What you get</h2>\n<ul>\n";
  Buffer.add_string buf "<li><b>Disciplined commits.</b> Every decision is a packet with a proposition, antithesis, and synthesis.</li>\n";
  Buffer.add_string buf "<li><b>Self-checking.</b> <code>math-coding check</code> validates structure and lifecycle. <code>math-coding probe</code> proves the convention applies to itself.</li>\n";
  Buffer.add_string buf "<li><b>Epistemic honesty.</b> A <code>proven</code> marker means the evidence command re-runs and matches its recorded exit code.</li>\n";
  Buffer.add_string buf "<li><b>Plain text.</b> No database, no CMS, no SaaS. The convention is a directory and a binary.</li>\n";
  Buffer.add_string buf "</ul>\n";
  Buffer.add_string buf "<h2>Packet index</h2>\n";
  Buffer.add_string buf "<table class=\"index\">\n";
  Buffer.add_string buf "<tr><th>packet</th><th>category</th><th>proposition</th></tr>\n";
  List.iter (fun (name, prop, is_axiom) ->
    let cls = if is_axiom then " class=\"axiom\"" else "" in
    let link_path = Printf.sprintf "math/%s.html" name in
    let subtitle = if String.length prop > 80 then
      String.sub prop 0 77 ^ "..." else prop in
    Printf.bprintf buf "<tr%s><td><a href=\"%s\">%s</a></td><td>%s</td></tr>\n"
      cls link_path (html_escape name) (html_escape subtitle)
  ) packets;
  Buffer.add_string buf "</table>\n";
  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf (page_footer "index.html");
  Buffer.contents buf

let render_axioms () =
  let axioms = [
    ("A0", "Difference", "A proposition differs from its implementation.");
    ("A1", "Care", "A developer cares whether the code does what it claims.");
    ("A2", "Curry-Howard", "A packet is a spec; the code is the impl; the witness closes the gap.");
    ("A3", "Material Basis", "Plain text for content, git for state, single binary for tools.");
    ("A4", "Process", "Lifecycle is computed from git history; `status:` field overrides.");
    ("A5", "Accounting", "Marked knowledge is reproducible when `proven`.");
    ("A6", "Self-Application", "Each axiom is realized as a packet; the runtime proves itself.");
  ] in
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>math-coding v1.0 — axioms</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n";
  Buffer.add_string buf "  <a href=\"index.html\">index</a>\n";
  Buffer.add_string buf "  <a href=\"axioms.html\">axioms</a>\n";
  Buffer.add_string buf "  <a href=\"installing.html\">installing</a>\n";
  Buffer.add_string buf "</nav>\n";
  Buffer.add_string buf "<h1>The seven axioms</h1>\n";
  List.iter (fun (code, name, stmt) ->
    Printf.bprintf buf "<section class=\"theorem\"><h3><span class=\"axiom\">%s</span> %s</h3>\n<p>%s</p></section>\n"
      code (html_escape name) (html_escape stmt)
  ) axioms;
  Buffer.add_string buf "<footer class=\"site-foot\">\n<p><a href=\"index.html\">index</a></p>\n</footer>\n";
  Buffer.add_string buf "</body>\n</html>\n";
  Buffer.contents buf

let render_installing () =
  "<!DOCTYPE html>\n\
   <html lang=\"en\">\n\
   <head>\n\
   <meta charset=\"utf-8\">\n\
   <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
   <meta name=\"color-scheme\" content=\"light dark\">\n\
   <title>math-coding v1.0 — installing</title>\n\
   <link rel=\"stylesheet\" href=\"assets/tokens.css\">\n\
   </head>\n<body>\n\
   <nav class=\"site-nav\">\n  \
   <a href=\"index.html\">index</a>\n  \
   <a href=\"axioms.html\">axioms</a>\n  \
   <a href=\"installing.html\">installing</a>\n\
   </nav>\n\
   <h1>Installing math-coding v1.0</h1>\n\
   <p>One binary. Plain-text packets. Git history. Nothing else.</p>\n\
   <h3>Prerequisites</h3>\n\
   <p>OCaml 5.x, dune 3.x, opam. Easiest via Nix flake:</p>\n\
   <pre><code>nix develop</code></pre>\n\
   <h3>Install</h3>\n\
   <pre><code>sh scripts/install.sh</code></pre>\n\
   <p>Installs to <code>$XDG_DATA_HOME/math-coding/&lt;ver&gt;/math-coding</code> with a <code>current</code> symlink.</p>\n\
   <h3>Use</h3>\n\
   <p>Wrapper at project root forwards to the shared binary:</p>\n\
   <pre><code>./math-coding check\n\
   ./math-coding probe\n\
   ./math-coding packet create NAME --proposition=...</code></pre>\n\
   <h3>Packet layout</h3>\n\
   <pre><code>math/&lt;name&gt;/\n\
   ├── packet.md        # YAML frontmatter + Markdown body\n\
   ├── witness          # YAML list of witness entries\n\
   ├── run.sh           # only if substrate: shell\n\
   ├── properties/      # only if substrate: pbt\n\
   ├── tla/             # only if substrate: tla+\n\
   ├── coq/             # only if substrate: coq\n\
   ├── alloy/           # only if substrate: alloy\n\
   └── bpmn/            # only if substrate: bpmn</code></pre>\n\
   <h3>Verify axiom Self-Application</h3>\n\
   <pre><code>./math-coding probe</code></pre>\n\
   <p>Each axiom is realized as a packet under <code>math/</code>. The probe verifies that each axiom packet satisfies structural and substantive checks.</p>\n\
   <footer class=\"site-foot\"><p><a href=\"index.html\">index</a></p></footer>\n\
   </body>\n</html>\n"

let render_about () =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>about — math-coding</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n  \
  <a href=\"index.html\">overview</a>\n  \
  <a href=\"about.html\">about</a>\n  \
  <a href=\"guide.html\">guide</a>\n  \
  <a href=\"substrates.html\">substrates</a>\n  \
  <a href=\"axioms.html\">axioms</a>\n  \
  <a href=\"installing.html\">installing</a>\n  \
  <a href=\"packets.html\">packets</a>\n\
  </nav>\n";
  Buffer.add_string buf "<h1>about</h1>\n";
  Buffer.add_string buf "<p>math-coding is a convention for documenting decisions in code. Each non-trivial choice becomes a <em>packet</em>: a short proposition, the strongest objection, and how it resolves.</p>\n";
  Buffer.add_string buf "<h2>Why this exists</h2>\n";
  Buffer.add_string buf "<p>Code reviews fail because reviewers see only the diff. The decision that produced the diff — what was tried, what was rejected, why this option — is gone. Six months later nobody can tell whether a line is load-bearing or accidental. math-coding fixes this by treating every decision as a first-class artefact in version control.</p>\n";
  Buffer.add_string buf "<p>The verb is <em>care</em>. The noun is <em>decision</em>. The medium is <em>plain text + git</em>. The verifier is the runtime itself: <code>math-coding check</code> validates structure and lifecycle, <code>math-coding probe</code> proves the convention applies to itself.</p>\n";
  Buffer.add_string buf "<h2>How math-coding differs from related things</h2>\n";
  Buffer.add_string buf "<p>People sometimes ask: &ldquo;isn't this just an ADR? or a fancy README? or TODO.md with rules?&rdquo; Short answer: no. Here is how it differs.</p>\n";
  Buffer.add_string buf "<h3>Compared to ADRs (Architectural Decision Records)</h3>\n";
  Buffer.add_string buf "<ul>\n";
  Buffer.add_string buf "<li><b>ADRs are for architecture</b> — usually kept in <code>docs/adr/</code> or a wiki, are heavyweight to write, and are reviewed as documents, not as code. ADRs are the right tool for &ldquo;we are switching from PostgreSQL to SQLite&rdquo; — a big choice, made rarely, by senior people, with consequences measured in quarters.</li>\n";
  Buffer.add_string buf "<li><b>math-coding is for every decision</b> — the cache TTL, the error message wording, the retry count, the order of arguments in a public function. Anything that someone might reasonably disagree with and that will be hard to recover from <em>by reading the code</em> is a candidate packet. ADRs are a subset; math-coding is the union of ADRs and the long tail of in-flight decisions.</li>\n";
  Buffer.add_string buf "<li><b>ADRs are a record; math-coding is a record + a verifier.</b> An ADR is a document you write once and forget. A packet has a lifecycle (draft, applied, drift, retired) that the runtime computes from git history. If the code in the witness commit no longer matches the proposition, the packet is in <span class=\"badge drift\">drift</span> and you have to act on it. ADRs decay silently; packets can't.</li>\n";
  Buffer.add_string buf "<li><b>ADRs are architecture; math-coding is epistemology.</b> A good packet answers not just &ldquo;what did we decide&rdquo; but &ldquo;what were we considering, what did we reject, and why is this better than that.&rdquo; The antithesis is the part you usually skip — and it's the part future-you most needs.</li>\n";
  Buffer.add_string buf "</ul>\n";
  Buffer.add_string buf "<h3>Compared to a <code>*</code> / TODO.md / comments-only approach</h3>\n";
  Buffer.add_string buf "<ul>\n";
  Buffer.add_string buf "<li><b>Comments in code drift.</b> A comment says &ldquo;we used X because Y&rdquo; on the day it was written. Two years later, Y has changed and the comment is a lie. math-coding moves the reasoning out of the source file into a separate, reviewable, lifecycle-tracked artefact. The code is the what; the packet is the why.</li>\n";
  Buffer.add_string buf "<li><b>TODO.md is a backlog.</b> It's a flat list of things someone should get around to. It doesn't record the reasoning <em>behind</em> the deferral — was it deferred because of risk, cost, or some other option? A packet on the same topic reads: &ldquo;we chose X over Y because Z, and we may revisit when W.&rdquo; When W happens, the packet is already in git history; you don't have to reconstruct the reasoning from a one-line TODO.</li>\n";
  Buffer.add_string buf "<li><b><code>*</code> markers in source code</b> are unsearchable across files, unversioned, and disappear when the file is rewritten. A packet is searchable, has a real lifecycle, and survives rewrites because it lives in its own file.</li>\n";
  Buffer.add_string buf "</ul>\n";
  Buffer.add_string buf "<h3>Compared to a wiki / Confluence / Notion</h3>\n";
  Buffer.add_string buf "<p>wikis are <em>separate</em> from the code. They drift, they get stale, they require maintenance, and they live behind a login. math-coding is a directory in the same repository as the code. Every packet is just a YAML file. It is grep-able, diff-able, and reviewable in the same pull request that changes the code.</p>\n";
  Buffer.add_string buf "<h3>Compared to a typed language (TypeScript, F*, TLA+)</h3>\n";
  Buffer.add_string buf "<p>math-coding does not invent a new type system. It uses git as the storage layer, plain text as the format, and the OCaml runtime as a thin verifier. If your team already has a typed language, that's the right place for invariants <em>the compiler can check</em>. math-coding is for the layer above: design intent, alternative-considered, trade-off-recorded, lifecycle-tracked. The eight <a href=\"substrates.html\">substrates</a> include <code>tla+</code>, <code>coq</code>, and <code>alloy</code> precisely so you can layer formal methods on top when a decision warrants it.</p>\n";
  Buffer.add_string buf "<h2>The seven axioms</h2>\n";
  Buffer.add_string buf "<dl class=\"axioms\">\n";
  let ax = [
    ("A0", "Difference", "A proposition differs from its implementation.");
    ("A1", "Care", "A developer cares whether the code does what it claims.");
    ("A2", "Curry-Howard", "A packet is a spec; the code is the impl; the witness closes the gap.");
    ("A3", "Material Basis", "Plain text for content, git for state, single binary for tools.");
    ("A4", "Process", "Lifecycle is computed from git history.");
    ("A5", "Accounting", "Marked knowledge is reproducible when proven.");
    ("A6", "Self-Application", "Each axiom is realised as a packet; the runtime proves itself.");
  ] in
  List.iter (fun (code, name, stmt) ->
    Printf.bprintf buf "<dt><span class=\"axiom\">%s</span> %s</dt><dd>%s</dd>\n"
      code (html_escape name) (html_escape stmt)
  ) ax;
  Buffer.add_string buf "</dl>\n";
  Buffer.add_string buf "<h2>When to use</h2>\n";
  Buffer.add_string buf "<ul>\n";
  Buffer.add_string buf "<li>Public APIs, architecture choices, configuration defaults, trade-offs.</li>\n";
  Buffer.add_string buf "<li>Decisions that are obviously forced by the problem don't need packets — use a regular commit.</li>\n";
  Buffer.add_string buf "<li>Documentation that doesn't change code doesn't need a packet — use a README.</li>\n";
  Buffer.add_string buf "</ul>\n";
  Buffer.add_string buf "<h2>The four questions a packet answers</h2>\n";
  Buffer.add_string buf "<ol>\n";
  Buffer.add_string buf "<li><b>What</b> was decided? — the proposition.</li>\n";
  Buffer.add_string buf "<li><b>What else</b> was considered? — the antithesis.</li>\n";
  Buffer.add_string buf "<li><b>Why this</b> and not that? — the synthesis.</li>\n";
  Buffer.add_string buf "<li><b>Is it still true</b>? — the lifecycle, computed from git.</li>\n";
  Buffer.add_string buf "</ol>\n";
  Buffer.add_string buf "<p>ADRs answer the first three. A wiki answers the first. Comments can answer the first. Only math-coding answers all four — including the fourth, automatically, every time you run <code>math-coding check</code>.</p>\n";
  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf "<p>Living Beings License · <a href=\"index.html\">overview</a></p></footer>\n";
  Buffer.add_string buf "</body>\n</html>\n";
  Buffer.contents buf

let render_guide () =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>guide — math-coding</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n  \
  <a href=\"index.html\">overview</a>\n  \
  <a href=\"axioms.html\">axioms</a>\n  \
  <a href=\"installing.html\">installing</a>\n\
  </nav>\n";
  Buffer.add_string buf "<h1>guide</h1>\n";
  Buffer.add_string buf "<h2>Install</h2>\n";
  Buffer.add_string buf "<pre><code>nix develop\nsh scripts/install.sh</code></pre>\n";
  Buffer.add_string buf "<p>Builds the OCaml binary, installs to\n";
  Buffer.add_string buf "<code>$XDG_DATA_HOME/math-coding/current/math-coding</code>,\n";
  Buffer.add_string buf "drops a wrapper at the project root.</p>\n";
  Buffer.add_string buf "<h2>Create your first packet</h2>\n";
  Buffer.add_string buf "<pre><code>./math-coding packet create cache-ttl \\\n";
  Buffer.add_string buf "  --proposition=\"Cache entries expire after 60 seconds\" \\\n";
  Buffer.add_string buf "  --antithesis=\"Manual invalidation forces users to wait\" \\\n";
  Buffer.add_string buf "  --synthesis=\"TTL is fixed; manual invalidate is /admin/cache\"</code></pre>\n";
  Buffer.add_string buf "<h2>Daily workflow</h2>\n";
  Buffer.add_string buf "<ol>\n";
  Buffer.add_string buf "<li>Make code change. <code>git commit -m \"...\"</code></li>\n";
  Buffer.add_string buf "<li><code>./math-coding check</code> verifies structure.</li>\n";
  Buffer.add_string buf "<li><code>./math-coding probe</code> proves the convention applies to itself.</li>\n";
  Buffer.add_string buf "</ol>\n";
  Buffer.add_string buf "<h2>Five commands you need</h2>\n";
  Buffer.add_string buf "<pre><code>./math-coding check      # structure + lifecycle of every packet\n";
  Buffer.add_string buf "./math-coding probe      # every axiom packet is sound\n";
  Buffer.add_string buf "./math-coding site       # render dist/ from math/\n";
  Buffer.add_string buf "./math-coding packet show NAME\n";
  Buffer.add_string buf "./math-coding packet edit NAME --antithesis=\"...\"</code></pre>\n";
  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf "<p>Living Beings License · <a href=\"index.html\">overview</a></p>\n</footer>\n";
  Buffer.add_string buf "</body>\n</html>\n";
  Buffer.contents buf

let render_substrates () =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>substrates — math-coding</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n  \
  <a href=\"index.html\">overview</a>\n  \
  <a href=\"axioms.html\">axioms</a>\n  \
  <a href=\"installing.html\">installing</a>\n\
  </nav>\n";
  Buffer.add_string buf "<h1>eight substrates</h1>\n";
  Buffer.add_string buf "<p>The substrate is how strongly the proposition is verified.\n";
  Buffer.add_string buf "Pick the simplest one that gives you the right confidence.</p>\n";
  Buffer.add_string buf "<table class=\"index\">\n";
  Buffer.add_string buf "<tr><th>substrate</th><th>verifies</th><th>use when</th></tr>\n";
  let rows = [
    ("none", "nothing", "cosmetic changes, name choices");
    ("shell", "exit code of a shell command", "one executable check");
    ("pbt", "property-based tests", "\"for all X, P(X)\" with generators");
    ("tla+", "TLA+ state-machine spec via TLC", "state, concurrency, ordering");
    ("coq", "Coq proof via coqc", "critical invariant");
    ("alloy", "Alloy relational constraint", "structural shape, reachability");
    ("bpmn", "XML well-formedness", "business workflow");
    ("pbt-prism", "probabilistic model checking via Prism", "probabilities, randomised systems");
  ] in
  List.iter (fun (s, v, w) ->
    Printf.bprintf buf "<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>\n"
      s (html_escape v) (html_escape w);
  ) rows;
  Buffer.add_string buf "</table>\n";
  Buffer.add_string buf "<h2>Decision tree</h2>\n";
  Buffer.add_string buf "<pre><code>Is the proposition about a single executable fact?\n";
  Buffer.add_string buf "  -> yes: shell\n";
  Buffer.add_string buf "  -> no: Is it \"for all X, P(X)\" with many cases?\n";
  Buffer.add_string buf "    -> yes: pbt\n";
  Buffer.add_string buf "    -> no: state, concurrency?\n";
  Buffer.add_string buf "      -> yes: tla+\n";
  Buffer.add_string buf "      -> no: critical invariant?\n";
  Buffer.add_string buf "        -> yes: coq\n";
  Buffer.add_string buf "        -> no: structural shape?\n";
  Buffer.add_string buf "          -> yes: alloy\n";
  Buffer.add_string buf "          -> no: workflow?\n";
  Buffer.add_string buf "            -> yes: bpmn\n";
  Buffer.add_string buf "            -> no: probabilities?\n";
  Buffer.add_string buf "              -> yes: pbt-prism\n";
  Buffer.add_string buf "              -> no: none</code></pre>\n";
  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf "<p>Living Beings License · <a href=\"index.html\">overview</a></p>\n</footer>\n";
  Buffer.add_string buf "</body>\n</html>\n";
  Buffer.contents buf

let list_packets math_dir =
  let rec loop acc = function
    | [] -> List.rev acc
    | entry :: rest ->
        if entry.[0] = '.' then loop acc rest
        else
          let path = Filename.concat math_dir entry in
          let pm = Filename.concat path "packet.md" in
          if Sys.is_directory path && Sys.file_exists pm then
            loop (entry :: acc) rest
          else loop acc rest
  in
  let entries = try Sys.readdir math_dir with Sys_error _ -> [||] in
  loop [] (Array.to_list entries)

let write_file path content =
  let oc = open_out_bin path in
  output_string oc content;
  close_out oc

let build_site math_dir dist_dir =
  Printf.printf "build site: math=%s dist=%s\n" math_dir dist_dir;
  let _ = Sys.command (Printf.sprintf "rm -rf %s && mkdir -p %s/math %s/assets"
                          dist_dir dist_dir dist_dir) in
  Sys.command (Printf.sprintf "cp site/assets/tokens.css %s/assets/" dist_dir) |> ignore;

  let names = list_packets math_dir in
  Printf.printf "packets: %d\n" (List.length names);

  let entries = ref [] in
  List.iter (fun name ->
    let pkt_path = Filename.concat math_dir name in
    let packet_md = Filename.concat pkt_path "packet.md" in
    let ic = open_in packet_md in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let pkt = Math_coding_lib.Parse.parse_packet name pkt_path content in
    let is_axiom =
      match pkt.Math_coding_lib.Packet.axiom with
      | Some a ->
          String.length a = 2 && a.[0] = 'A'
          && a.[1] >= '0' && a.[1] <= '6'
      | None -> false
    in
    let html = render_packet_html name content in
    let out_path = Printf.sprintf "%s/math/%s.html" dist_dir name in
    write_file out_path html;
    entries := (name, pkt.Math_coding_lib.Packet.proposition, is_axiom) :: !entries
  ) names;

  let list_entries = List.rev !entries in
  write_file (Filename.concat dist_dir "index.html") (render_index list_entries);
  write_file (Filename.concat dist_dir "about.html") (render_about ());
  write_file (Filename.concat dist_dir "guide.html") (render_guide ());
  write_file (Filename.concat dist_dir "substrates.html") (render_substrates ());
  write_file (Filename.concat dist_dir "axioms.html") (render_axioms ());
  write_file (Filename.concat dist_dir "installing.html") (render_installing ());

  Printf.printf "done\n"

let () =
  let args = Array.to_list Sys.argv in
  match args with
  | _ :: math_dir :: dist_dir :: _ -> build_site math_dir dist_dir
  | _ ->
      Printf.printf "usage: %s <math_dir> <dist_dir>\n"
        (Filename.basename Sys.argv.(0));
      exit 1
