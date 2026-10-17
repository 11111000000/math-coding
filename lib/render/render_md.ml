(* lib/render/render_md.ml — minimal Markdown subset.

   Split from lib/render/render.ml. Deliberately does NOT pull in a
   full Markdown library; the protocol's published prose uses a
   narrow subset and a hand-rolled parser is auditable. This module
   is self-contained: it depends on no other render module. *)

(* Tiny string-set used by `build_pages` to track which article
   names have a Russian sibling. Implemented as a sorted list of
   strings; for the ≤ 16 entries `site/` carries this is faster
   than pulling in `Set`. *)
module String_set = struct
  type t = string list

  let empty = []

  let rec add x = function
    | [] -> [ x ]
    | y :: rest ->
        if x = y then y :: rest
        else if x < y then x :: y :: rest
        else y :: add x rest

  let rec mem x = function
    | [] -> false
    | y :: rest -> if x = y then true else mem x rest
end

let[@warning "-32"] html_escape s =
  let len = String.length s in
  let buf = Buffer.create len in
  for i = 0 to len - 1 do
    match s.[i] with
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '&' -> Buffer.add_string buf "&amp;"
    | '"' -> Buffer.add_string buf "&quot;"
    | c -> Buffer.add_char buf c
  done;
  Buffer.contents buf

(* Helper: render the HTML of a list of (html, _) fragments
   by joining all their HTML strings. Used for nested inline
   processing (bold inside bold, link text inside a link). *)
let[@warning "-32"] html_of_fragments (frags : (string * bool) list) : string =
  let buf = Buffer.create 64 in
  List.iter (fun (h, _) -> Buffer.add_string buf h) frags;
  Buffer.contents buf

(* Parse the body of an inline segment looking for `^[text]`
   sidenote syntax. Returns a list of (escaped_html, is_sidenote)
   fragments in source order. Outside a sidenote, also handles
   inline code (`...`). *)
(* Per-render-call sidenote counter. Bumped once per `^[body]`
   occurrence so the inline marker and the margin note share an
   anchor id pair (sn-N, snref-N). The reference itself lives in
   the closure of `loop`; both bindings are introduced inside
   `md_inline_parse`. *)
let[@warning "-32"] rec md_inline_parse s =
  let len = String.length s in
  let buf = Buffer.create len in
  let fragments : (string * bool) list ref = ref [] in
  let sidenote_counter = ref 1 in
  let flush_inline () =
    if Buffer.length buf > 0 then begin
      fragments := (Buffer.contents buf, false) :: !fragments;
      Buffer.clear buf
    end
  in
  let rec loop i =
    if i >= len then flush_inline ()
    else
      let c = s.[i] in
      if c = '`' then begin
        let j = ref (i + 1) in
        while !j < len && s.[!j] <> '`' do
          incr j
        done;
        if !j < len then begin
          let code = String.sub s (i + 1) (!j - i - 1) in
          flush_inline ();
          let html = Printf.sprintf "<code>%s</code>" (html_escape code) in
          fragments := (html, false) :: !fragments;
          loop (!j + 1)
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else if c = '^' && i + 1 < len && s.[i + 1] = '[' then begin
        (* sidenote: ^[body] — emit <sup>N</sup> + <label class="sidenote">body</label> *)
        let j = ref (i + 2) in
        let depth = ref 1 in
        while !j < len && !depth > 0 do
          if s.[!j] = '[' then incr depth else if s.[!j] = ']' then decr depth;
          if !depth > 0 then incr j
        done;
        if !j < len && !depth = 0 then begin
          let body_str = String.sub s (i + 2) (!j - i - 2) in
          flush_inline ();
          let n = !sidenote_counter in
          let marker =
            Printf.sprintf
              "<sup><a id=\"snref-%d\" href=\"#sn-%d\" \
               class=\"sidenote-number\">%d</a></sup>"
              n n n
          in
          let sidenote_html =
            Printf.sprintf
              "<label for=\"snref-%d\" class=\"sidenote\" \
               id=\"sn-%d\">%s</label>"
              n n (html_escape body_str)
          in
          fragments := (sidenote_html, true) :: (marker, true) :: !fragments;
          incr sidenote_counter;
          loop (!j + 1)
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else if c = '*' && i + 1 < len && s.[i + 1] = '*' then begin
        (* Bold: **text** → <strong>text</strong> *)
        let k = ref (i + 2) in
        let found = ref false in
        let body_start = i + 2 in
        let body_end = ref body_start in
        while !k + 1 < len && not !found do
          if s.[!k] = '*' && s.[!k + 1] = '*' then begin
            body_end := !k;
            found := true
          end
          else incr k
        done;
        if !found then begin
          flush_inline ();
          let body_str = String.sub s body_start (!body_end - body_start) in
          let html =
            Printf.sprintf "<strong>%s</strong>"
              (html_of_fragments (md_inline_parse body_str))
          in
          fragments := (html, false) :: !fragments;
          loop (!k + 2)
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else if c = '*' then begin
        (* Italic: *text* → <em>text</em>. Tolerant: any non-empty
           body not containing a literal `*` works. Lone asterisk
           without a closing match stays literal. *)
        let k = ref (i + 1) in
        let found = ref false in
        let body_start = i + 1 in
        let body_end = ref body_start in
        while !k < len && not !found do
          if s.[!k] = '*' then begin
            body_end := !k;
            found := true
          end
          else incr k
        done;
        if !found && !body_end > body_start then begin
          flush_inline ();
          let body_str = String.sub s body_start (!body_end - body_start) in
          let html =
            Printf.sprintf "<em>%s</em>"
              (html_of_fragments (md_inline_parse body_str))
          in
          fragments := (html, false) :: !fragments;
          loop (!k + 1)
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else if c = '_' && i + 1 < len && s.[i + 1] <> '_' then begin
        (* Italic via underscore: _text_ → <em>text</em>. Word-
           boundary rule: the opener must be preceded by whitespace
           or string start, AND the body must not start with an
           alphanumeric (so identifiers like `foo_bar` are not
           italicised). This matches CommonMark's "intraword
           underscore" exception and keeps `$x_i$` safe. *)
        let prev_char_ok =
          i = 0
          ||
          let pc = s.[i - 1] in
          pc = ' ' || pc = '\n' || pc = '\t' || pc = '\r'
        in
        if not prev_char_ok then begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
        else begin
          let k = ref (i + 1) in
          let found = ref false in
          let body_start = i + 1 in
          let body_end = ref body_start in
          while !k < len && not !found do
            if s.[!k] = '_' then begin
              let next_idx = !k + 1 in
              let next_ok =
                next_idx >= len
                ||
                let nc = s.[next_idx] in
                nc = ' ' || nc = '\n' || nc = '\t' || nc = '\r' || nc = '.'
                || nc = ',' || nc = ';' || nc = ':' || nc = '!' || nc = '?'
                || nc = ')'
              in
              if next_ok then begin
                body_end := !k;
                found := true
              end
              else incr k
            end
            else incr k
          done;
          if !found && !body_end > body_start then begin
            flush_inline ();
            let body_str = String.sub s body_start (!body_end - body_start) in
            let html =
              Printf.sprintf "<em>%s</em>"
                (html_of_fragments (md_inline_parse body_str))
            in
            fragments := (html, false) :: !fragments;
            loop (!k + 1)
          end
          else begin
            Buffer.add_char buf c;
            loop (i + 1)
          end
        end
      end
      else if c = '!' && i + 1 < len && s.[i + 1] = '[' then begin
        (* Inline image: ![alt](url). Mirrors the link grammar
           above. If the bracketed alt text is not followed by
           `(...)`, the `!` and `[` are emitted literally. The
           result is a `<figure class="mathc-figure mathc-figure-inline">`
           containing an `<img>` with the given alt text — the
           same wrapper used by the page-level body_extra
           appends, but classed as `inline` so CSS can render it
           inline in the prose flow rather than as a full-width
           band. Sites use this to drop an illustration next
           to the paragraph that names the concept it shows
           (see site/methodology.md, site/foundations.md). *)
        let k = ref (i + 2) in
        let depth = ref 1 in
        let found_text = ref false in
        let text_end = ref 0 in
        while !k < len && not !found_text do
          if s.[!k] = '[' then incr depth
          else if s.[!k] = ']' then begin
            decr depth;
            if !depth = 0 then begin
              text_end := !k;
              found_text := true
            end
          end;
          if not !found_text then incr k
        done;
        if !found_text && !text_end + 1 < len && s.[!text_end + 1] = '(' then begin
          let m = ref (!text_end + 2) in
          let depth_p = ref 1 in
          let url_end = ref 0 in
          let found_url = ref false in
          while !m < len && not !found_url do
            if s.[!m] = '(' then incr depth_p
            else if s.[!m] = ')' then begin
              decr depth_p;
              if !depth_p = 0 then begin
                url_end := !m;
                found_url := true
              end
            end;
            if not !found_url then incr m
          done;
          if !found_url then begin
            let alt = String.sub s (i + 2) (!text_end - i - 2) in
            let url =
              String.trim
                (String.sub s (!text_end + 2) (!url_end - !text_end - 2))
            in
            flush_inline ();
            let html =
              Printf.sprintf
                "<figure class=\"mathc-figure mathc-figure-inline\">\
                 <img src=\"%s\" alt=\"%s\">\
                 </figure>"
                (html_escape url) (html_escape alt)
            in
            fragments := (html, true) :: !fragments;
            loop (!url_end + 1)
          end
          else begin
            Buffer.add_char buf c;
            loop (i + 1)
          end
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else if c = '[' then begin
        (* Inline link: [text](url). Tolerant: if no `]` followed by
           `(` is found, the `[` is literal. *)
        let k = ref (i + 1) in
        let depth = ref 1 in
        let found_text = ref false in
        let text_end = ref 0 in
        while !k < len && not !found_text do
          if s.[!k] = '[' then incr depth
          else if s.[!k] = ']' then begin
            decr depth;
            if !depth = 0 then begin
              text_end := !k;
              found_text := true
            end
          end;
          if not !found_text then incr k
        done;
        if !found_text && !text_end + 1 < len && s.[!text_end + 1] = '(' then begin
          let m = ref (!text_end + 2) in
          let depth_p = ref 1 in
          let url_end = ref 0 in
          let found_url = ref false in
          while !m < len && not !found_url do
            if s.[!m] = '(' then incr depth_p
            else if s.[!m] = ')' then begin
              decr depth_p;
              if !depth_p = 0 then begin
                url_end := !m;
                found_url := true
              end
            end;
            if not !found_url then incr m
          done;
          if !found_url then begin
            let text = String.sub s (i + 1) (!text_end - i - 1) in
            let url =
              String.trim
                (String.sub s (!text_end + 2) (!url_end - !text_end - 2))
            in
            flush_inline ();
            let html =
              Printf.sprintf "<a href=\"%s\">%s</a>" (html_escape url)
                (html_of_fragments (md_inline_parse text))
            in
            fragments := (html, false) :: !fragments;
            loop (!url_end + 1)
          end
          else begin
            Buffer.add_char buf c;
            loop (i + 1)
          end
        end
        else begin
          Buffer.add_char buf c;
          loop (i + 1)
        end
      end
      else begin
        Buffer.add_char buf c;
        loop (i + 1)
      end
  in
  loop 0;
  List.rev !fragments

(* Wrap a list of (html_fragment, is_sidenote) into the final
   inline HTML: pure-text fragments get md_inline (which handles
   backtick code), sidenote fragments are emitted verbatim. *)
let[@warning "-32"] md_inline s =
  let frags = md_inline_parse s in
  let buf = Buffer.create (String.length s) in
  List.iter
    (fun (html, is_sn) ->
      if is_sn then Buffer.add_string buf html else Buffer.add_string buf html)
    frags;
  Buffer.contents buf

(* Detect the language tag on a fenced code block. The line is
   `\`\`\`TAG`. Returns Some TAG if the tag is meaningful
   (anything but the empty string), else None. *)
let[@warning "-32"] code_fence_tag (line : string) : string option =
  let t = String.trim line in
  if String.length t > 3 && String.sub t 0 3 = "```" then begin
    let rest = String.sub t 3 (String.length t - 3) in
    let lang = String.trim rest in
    if lang = "" then None else Some lang
  end
  else None

let[@warning "-32"] md_parse source =
  let lines = String.split_on_char '\n' source in
  let buf = Buffer.create 256 in
  let flush_para text =
    if text <> "" then begin
      Buffer.add_string buf "  <p>";
      Buffer.add_string buf (html_of_fragments (md_inline_parse text));
      Buffer.add_string buf "</p>\n"
    end
  in
  let rec collect_code acc = function
    | [] -> (List.rev acc, [])
    | l :: r ->
        let trimmed = String.trim l in
        (* Closing fence is at least 3 backticks (CommonMark allows
           longer, but our subset honours the minimum). Length check
           is `>= 3` (not `> 4`) — the previous form silently missed
           a 3-char "```" because "```" has length 3 but `String.sub
           "```" 0 4` raised Invalid_argument on the unguarded form;
           the `> 4` guard hid the bug behind "matches too few
           lines". *)
        if String.length trimmed >= 3 && String.sub trimmed 0 3 = "```" then
          (List.rev acc, r)
        else collect_code (l :: acc) r
  in
  (* Detect whether a line is a horizontal rule: dashes or
     asterisks only. Used by md_parse. *)
  let[@warning "-32"] is_hr_line t =
    if String.length t < 3 then false
    else
      let c0 = t.[0] in
      (c0 = '-' || c0 = '*') && String.for_all (fun c -> c = c0) t
  in
  (* Detect whether a line starts a markdown table row.
     The line must start with `|`. *)
  let[@warning "-32"] is_table_line t = String.length t > 0 && t.[0] = '|' in
  (* A line is a table separator when it consists solely of
     `|`, `-`, `:`, and whitespace. *)
  let[@warning "-32"] is_table_separator t =
    String.length t > 2
    && String.contains t '|' && String.contains t '-'
    && String.for_all (fun c -> c = '|' || c = '-' || c = ':' || c = ' ') t
  in
  (* Split a table row by `|`, dropping the leading/trailing
     empty cell when the row starts or ends with `|`. *)
  let[@warning "-32"] split_table_row t =
    let len = String.length t in
    if len = 0 then []
    else
      let start = if t.[0] = '|' then 1 else 0 in
      let finish = if t.[len - 1] = '|' then len - 1 else len in
      let cells = ref [] in
      let i = ref start in
      while !i < finish do
        let j = ref !i in
        while !j < finish && t.[!j] <> '|' do
          incr j
        done;
        let cell = String.trim (String.sub t !i (!j - !i)) in
        cells := cell :: !cells;
        i := !j + 1
      done;
      List.rev !cells
  in
  let render_table header_rows body_rows =
    Buffer.add_string buf "<table class=\"mathc-table\">\n";
    if header_rows <> [] then begin
      Buffer.add_string buf "  <thead>\n  <tr>";
      List.iter
        (fun cell ->
          Buffer.add_string buf "<th>";
          Buffer.add_string buf (html_of_fragments (md_inline_parse cell));
          Buffer.add_string buf "</th>")
        header_rows;
      Buffer.add_string buf "</tr>\n  </thead>\n"
    end;
    if body_rows <> [] then begin
      Buffer.add_string buf "  <tbody>\n";
      List.iter
        (fun row ->
          Buffer.add_string buf "    <tr>";
          List.iter
            (fun cell ->
              Buffer.add_string buf "<td>";
              Buffer.add_string buf (html_of_fragments (md_inline_parse cell));
              Buffer.add_string buf "</td>")
            row;
          Buffer.add_string buf "</tr>\n")
        body_rows;
      Buffer.add_string buf "  </tbody>\n"
    end;
    Buffer.add_string buf "</table>\n"
  in
  (* Collect subsequent table rows until a blank line or non-table line. *)
  let collect_table_rows rem =
    let rec loop acc = function
      | [] -> (List.rev acc, [])
      | line :: more ->
          let t = String.trim line in
          if t = "" then (List.rev acc, more)
          else if is_table_line t then loop (split_table_row t :: acc) more
          else (List.rev acc, line :: more)
    in
    loop [] rem
  in
  (* --- ordered-list support (render-ordered-lists-2026-10) ---
   *
   * The hand-rolled Markdown subset previously recognised only
   * `- ` unordered lists. Lines starting with `<digits>. `
   * (e.g., `1. `, `2. `, `12. `) fell through to the paragraph
   * accumulator and were rendered as a single `<p>` with the
   * numbers concatenated, e.g.,
   *   "1. Схема. ... 2. Идентичность. ... 3. ..."
   * instead of three `<li>` elements inside an `<ol>`. Twelve
   * paragraphs across seven site pages (methodology, contributing,
   * differences, install, faq — EN/RU/ZH) plus the rendered
   * AGENTS.md / USAGE.md excerpts were affected.
   *
   * The fix adds `is_ordered_marker` / `ordered_marker_body` (a
   * parser for `<digits>. ` prefixes) and a shared `render_list`
   * helper that takes the HTML opening tag (`<ul>` or `<ol>`) and
   * a per-type item trigger. The previous `- `-only code lived
   * inline in the loop; that branch now becomes a thin call into
   * the helper, and a sibling branch handles the new ordered
   * case. *)

  (* Parse a line that starts an ordered list item: one or more
     ASCII digits, then a literal `.`, then a single space. Returns
     the body (substring after the space) when matched, None
     otherwise. A line like "1.5 " (decimal point) is rejected
     because the character after `.` must be a space; "1.foo"
     (no space) is rejected the same way. *)
  let[@warning "-32"] ordered_marker_body t =
    let len = String.length t in
    let i = ref 0 in
    while !i < len && t.[!i] >= '0' && t.[!i] <= '9' do
      incr i
    done;
    if !i = 0 || !i + 1 >= len || t.[!i] <> '.' || t.[!i + 1] <> ' ' then
      None
    else Some (String.sub t (!i + 2) (len - !i - 2))
  in
  let[@warning "-32"] is_ordered_marker t =
    match ordered_marker_body t with Some _ -> true | None -> false
  in
  let[@warning "-32"] ordered_trigger tt = ordered_marker_body tt in
  (* Render a list block. `tag` is the HTML opening element
     (`<ul>` or `<ol>`); `trigger` is a per-list-type predicate
     returning Some body when a line starts a new item, or None
     otherwise. The first body is taken from `first_line`; each
     subsequent line is either a new item (per `trigger`), a
     continuation of the current item, or a block starter that
     ends the list entirely. Continuation lines are joined with a
     single space, matching the "tight list with single-line
     continuation" convention used throughout `site/*.md` and
     `axioms/*.md`. The block-starter check includes `- ` so an
     unordered list marker ends an in-flight ordered list (and
     vice versa). *)
  let render_list ~tag ~trigger first_line rest =
    let close_tag = if tag = "<ul>" then "</ul>" else "</ol>" in
    Buffer.add_string buf (tag ^ "\n");
    let is_block_starter tt =
      (String.length tt >= 3 && String.sub tt 0 3 = "```")
      || (String.length tt > 2 && String.sub tt 0 2 = "# ")
      || (String.length tt > 3 && String.sub tt 0 3 = "## ")
      || (String.length tt > 4 && String.sub tt 0 4 = "### ")
      || (String.length tt > 0 && tt.[0] = '>')
      || is_hr_line tt
      || (String.length tt > 0 && tt.[0] = '|')
      || (String.length tt > 2 && String.sub tt 0 2 = "- ")
    in
    let rec collect items_rev current_item rem =
      match rem with
      | [] -> (List.rev items_rev, List.rev current_item, [])
      | l :: r ->
          let tt = String.trim l in
          if tt = "" then
            (List.rev items_rev, List.rev current_item, l :: r)
          else if is_block_starter tt then
            (List.rev items_rev, List.rev current_item, l :: r)
          else begin
            match trigger tt with
            | Some body ->
                let finished = List.rev current_item in
                collect ([ finished ] @ items_rev) [ body ] r
            | None -> collect items_rev (l :: current_item) r
          end
    in
    let first_body =
      match trigger first_line with Some b -> b | None -> first_line
    in
    let items, current, after = collect [] [ first_body ] rest in
    let all_items =
      match current with [] -> items | _ -> items @ [ current ]
    in
    List.iter
      (fun item_lines ->
        let joined =
          String.concat " "
            (List.map (fun s -> String.trim s) item_lines)
        in
        Buffer.add_string buf "  <li>";
        Buffer.add_string buf (md_inline joined);
        Buffer.add_string buf "</li>\n")
      all_items;
    Buffer.add_string buf (close_tag ^ "\n");
    after
  in
  let rec loop acc_para = function
    | [] -> flush_para acc_para
    | line :: rest -> (
        let t = String.trim line in
        let push_para () = flush_para acc_para in
        match t with
        | "" ->
            push_para ();
            loop "" rest
        | _ when String.length t > 2 && String.sub t 0 2 = "# " ->
            push_para ();
            Buffer.add_string buf "<h1>";
            Buffer.add_string buf
              (md_inline (String.sub t 2 (String.length t - 2)));
            Buffer.add_string buf "</h1>\n";
            loop "" rest
        | _ when String.length t > 3 && String.sub t 0 3 = "## " ->
            push_para ();
            Buffer.add_string buf "<h2>";
            Buffer.add_string buf
              (md_inline (String.sub t 3 (String.length t - 3)));
            Buffer.add_string buf "</h2>\n";
            loop "" rest
        | _ when String.length t > 4 && String.sub t 0 4 = "### " ->
            push_para ();
            Buffer.add_string buf "<h3>";
            Buffer.add_string buf
              (md_inline (String.sub t 4 (String.length t - 4)));
            Buffer.add_string buf "</h3>\n";
            loop "" rest
        | _ when String.length t >= 3 && String.sub t 0 3 = "```" -> begin
            push_para ();
            let tag = code_fence_tag line in
            let collected, after = collect_code [] rest in
            let code = String.concat "\n" collected in
            (match tag with
            | Some lang ->
                Buffer.add_string buf "<pre><code class=\"language-";
                Buffer.add_string buf (html_escape lang);
                Buffer.add_string buf "\">";
                Buffer.add_string buf (html_escape code);
                Buffer.add_string buf "</code></pre>\n"
            | None ->
                Buffer.add_string buf "<pre><code>";
                Buffer.add_string buf (html_escape code);
                Buffer.add_string buf "</code></pre>\n");
            loop "" after
          end
        | _ when is_hr_line t ->
            push_para ();
            Buffer.add_string buf "<hr>\n";
            loop "" rest
        | _ when String.length t > 1 && t.[0] = '>' ->
            push_para ();
            (* Blockquote: each `> ` line joins the quote body. The
               FIRST line's body is taken from `t` (the matched line);
               subsequent lines contribute their own body via
               collect's recursive body extraction. *)
            let first_body =
              String.trim (String.sub t 1 (String.length t - 1))
            in
            let rec collect acc rem =
              match rem with
              | [] -> (acc, [])
              | l :: r ->
                  let tt = String.trim l in
                  if String.length tt > 0 && tt.[0] = '>' then
                    let b =
                      String.trim (String.sub tt 1 (String.length tt - 1))
                    in
                    collect (b :: acc) r
                  else (acc, l :: r)
            in
            let collected, after = collect [ first_body ] rest in
            let joined = String.concat " " (List.rev collected) in
            Buffer.add_string buf "<blockquote><p>";
            Buffer.add_string buf (html_of_fragments (md_inline_parse joined));
            Buffer.add_string buf "</p></blockquote>\n";
            loop "" after
        | _ when is_table_line t && String.length t > 2 -> (
            push_para ();
            (* Detect table: header | separator | row* | blank. *)
            let header_cells = split_table_row t in
            match rest with
            | sep :: rows when is_table_separator (String.trim sep) ->
                let body_rows, after = collect_table_rows rows in
                render_table header_cells body_rows;
                loop "" after
            | _ ->
                (* Not a table; emit as paragraph *)
                let next = if acc_para = "" then t else acc_para ^ " " ^ t in
                loop next rest)
        | _ when is_ordered_marker t ->
            push_para ();
            (* Ordered list (`<ol>`). Each `<digits>. ` line starts a
               new item; continuation lines (non-marker, non-block
               starter) join the previous item with a single space. *)
            let after =
              render_list ~tag:"<ol>" ~trigger:ordered_trigger t rest
            in
            loop "" after
        | _ when String.length t > 2 && String.sub t 0 2 = "- " ->
            push_para ();
            (* Unordered list (`<ul>`). Each `- ` line starts a new
               item; continuation lines (non-marker, non-block
               starter) join the previous item with a single space.
               This is the "tight list with single-line continuation"
               used by all `site/*.md` and `axioms/*.md` content; we
               do not honour the indented-2-space hard-break rule
               (CommonMark §6). The list-body collection is shared
               with the ordered case via `render_list`; only the
               trigger predicate differs. *)
            let trigger tt =
              if String.length tt > 2 && String.sub tt 0 2 = "- " then
                Some (String.sub tt 2 (String.length tt - 2))
              else None
            in
            let after = render_list ~tag:"<ul>" ~trigger t rest in
            loop "" after
        | _ ->
            let next = if acc_para = "" then t else acc_para ^ " " ^ t in
            loop next rest)
  in
  loop "" lines;
  Buffer.contents buf
