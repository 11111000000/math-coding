(* lib/render/render_extras.ml — RSS 2.0 feed.

   Split from lib/render/render.ml. Renders the decision feed
   (`dist/feed.xml`). Self-contained. *)

(* --- RSS 2.0 feed (Phase 4 of site-quality-distribution-2026-10) --- *)

(* RSS 2.0 channel-level constants. The project ships a single
   feed at `dist/feed.xml`; the channel metadata is fixed by the
   project name + version; `<item>`s come from `decisions_data`
   (the same list that drives the per-decision pages) so a
   reviewer who polls the feed sees the same decisions the
   site lists. Items are capped at 60 (the most-recent by
   decision_id alphabetical order) to keep the file bounded;
   GitHub Pages hosts a 1 MB file limit and a feed well below
   that, but a future move to a different host may need this
   cap. *)
type rss_decision_item = {
  rss_decision_id : string;
  rss_decision_revision : string option;
  rss_intent_summary : string;
  rss_obligation_count : int;
}

let[@warning "-32"] rss_escape s =
  let buf = Buffer.create (String.length s + 16) in
  let len = String.length s in
  for i = 0 to len - 1 do
    match s.[i] with
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '&' -> Buffer.add_string buf "&amp;"
    | '"' -> Buffer.add_string buf "&quot;"
    | '\'' -> Buffer.add_string buf "&apos;"
    | c -> Buffer.add_char buf c
  done;
  Buffer.contents buf

(* Extract a one-line summary from a YAML body for the
   feed's `<description>`. The summary is the first non-empty
   line under the `intent:` key; if `intent:` is absent we
   fall back to the decision id alone. *)
let[@warning "-32"] extract_intent_summary ~yaml_body ~decision_id =
  match yaml_body with
  | None -> decision_id
  | Some body ->
      let lines = String.split_on_char '\n' body in
      let idx =
        let rec scan i =
          if i >= List.length lines then -1
          else
            let l = List.nth lines i in
            if
              String.length (String.trim l) > 7
              && String.sub (String.trim l) 0 7 = "intent:"
            then i
            else scan (i + 1)
        in
        scan 0
      in
      if idx < 0 then decision_id
      else begin
        let raw = List.nth lines idx in
        let prefix_len = 7 in
        let rest =
          String.sub raw prefix_len (String.length raw - prefix_len)
          |> String.trim
        in
        if rest = "|" || rest = "" then
          (* Block scalar: take the first non-empty continuation
             line. *)
          let len = List.length lines in
          let rec first_non_empty i =
            if i >= len then ""
            else
              let l = List.nth lines i in
              let t = String.trim l in
              if t = "" then first_non_empty (i + 1) else t
          in
          let first = first_non_empty (idx + 1) in
          if first = "" then decision_id else first
        else if rest = "" then decision_id
        else rest
      end

let[@warning "-32"] render_rss_feed ~version ~site_base ~items =
  let buf = Buffer.create 1024 in
  let now_iso =
    (* Use a fixed pubDate so re-running the renderer
       produces a stable feed; the kernel-level
       `as_of` is the audit-time timestamp. *)
    "Mon, 12 Oct 2026 14:30:00 GMT"
  in
  Buffer.add_string buf "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  Buffer.add_string buf "<rss version=\"2.0\">\n";
  Buffer.add_string buf "  <channel>\n";
  Printf.bprintf buf "    <title>math-coding %s</title>\n" (rss_escape version);
  Printf.bprintf buf "    <link>%s</link>\n"
    (rss_escape (site_base ^ "index.html"));
  Printf.bprintf buf
    "    <description>Assurance protocol for software changes. %s decisions, \
     %d items in this feed.</description>\n"
    version (List.length items);
  Printf.bprintf buf "    <pubDate>%s</pubDate>\n" now_iso;
  Printf.bprintf buf "    <language>en</language>\n";
  List.iter
    (fun item ->
      let href =
        Printf.sprintf "%sdecisions/%s.html" site_base item.rss_decision_id
      in
      let summary =
        let s = item.rss_intent_summary in
        let len = String.length s in
        if len > 240 then String.sub s 0 240 ^ "..." else s
      in
      let revision_tag =
        match item.rss_decision_revision with
        | Some r -> Printf.sprintf " (rev %s)" (rss_escape r)
        | None -> ""
      in
      Printf.bprintf buf
        "    <item>\n\
        \      <title>%s%s</title>\n\
        \      <link>%s</link>\n\
        \      <guid isPermaLink=\"false\">%s</guid>\n\
        \      <description>%d obligation(s); %s</description>\n\
        \    </item>\n"
        (rss_escape item.rss_decision_id)
        revision_tag (rss_escape href)
        (rss_escape item.rss_decision_id)
        item.rss_obligation_count (rss_escape summary))
    items;
  Buffer.add_string buf "  </channel>\n";
  Buffer.add_string buf "</rss>\n";
  Buffer.contents buf
