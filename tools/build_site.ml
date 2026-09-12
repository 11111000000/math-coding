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
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n";
  Buffer.add_string buf "<meta charset=\"utf-8\">\n";
  Buffer.add_string buf "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";
  Buffer.add_string buf "<meta name=\"color-scheme\" content=\"light dark\">\n";
  Buffer.add_string buf "<title>math-coding v1.0 — packets</title>\n";
  Buffer.add_string buf "<link rel=\"stylesheet\" href=\"assets/tokens.css\">\n";
  Buffer.add_string buf "</head>\n<body>\n";
  Buffer.add_string buf "<nav class=\"site-nav\">\n";
  Buffer.add_string buf "  <a href=\"index.html\">index</a>\n";
  Buffer.add_string buf "  <a href=\"axioms.html\">axioms</a>\n";
  Buffer.add_string buf "  <a href=\"installing.html\">installing</a>\n";
  Buffer.add_string buf "</nav>\n";
  Buffer.add_string buf "<h1>math-coding v1.0</h1>\n";
  Buffer.add_string buf "<p>Plain text. Git. Single OCaml binary. Eight substrates. Five epistemic markers. ";
  Buffer.add_string buf "<span class=\"epistemic\">Curry-Howard</span> as a checkable claim, not a metaphor.";
  Buffer.add_string buf "</p>\n";
  Printf.bprintf buf "<p>Currently <strong>%d packets</strong> under <code>math/</code>.</p>\n"
    (List.length packets);
  Buffer.add_string buf "<table class=\"index\">\n";
  Buffer.add_string buf "<tr><th>packet</th><th>status</th><th>subtitle</th></tr>\n";
  List.iter (fun (name, prop, is_axiom) ->
    let cls = if is_axiom then " class=\"axiom\"" else "" in
    let link_path = Printf.sprintf "math/%s.html" name in
    let subtitle = if String.length prop > 70 then
      String.sub prop 0 67 ^ "..." else prop in
    Printf.bprintf buf "<tr%s><td><a href=\"%s\">%s</a></td><td>%s</td><td>%s</td></tr>\n"
      cls link_path (html_escape name) (html_escape (if prop = "" then "—" else "")) (html_escape subtitle)
  ) packets;
  Buffer.add_string buf "</table>\n";
  Buffer.add_string buf "<footer class=\"site-foot\">\n";
  Buffer.add_string buf "<p>Living Beings License · <a href=\"axioms.html\">axioms</a> · ";
  Buffer.add_string buf "<a href=\"installing.html\">installing</a></p>\n</footer>\n";
  Buffer.add_string buf "</body>\n</html>\n";
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
