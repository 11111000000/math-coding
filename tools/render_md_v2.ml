(* Tiny markdown subset: paragraphs, ## headings, ``` blocks. *)
let render_md (md : string) : string =
  let buf = Buffer.create 4096 in
  let in_code = ref false in
  let paragraph = ref [] in
  let flush_paragraph () =
    if !paragraph <> [] then begin
      Buffer.add_string buf "<p>";
      List.iter (fun line ->
        Buffer.add_string buf (html_escape line);
        Buffer.add_char buf ' ') !paragraph;
      Buffer.add_string buf "</p>\n";
      paragraph := []
    end
  in
  let rec process = function
    | [] -> flush_paragraph ()
    | line :: rest ->
      if !in_code then
        if line = "```" then begin
          Buffer.add_string buf "</code></pre>\n";
          in_code := false
        end else begin
          Buffer.add_string buf (html_escape line);
          Buffer.add_char buf '\n'
        end
      else if line = "```" then begin
        flush_paragraph ();
        Buffer.add_string buf "<pre><code>";
        in_code := true
      end
      else if String.starts_with ~prefix:"## " line then begin
        flush_paragraph ();
        let title = String.sub line 3 (String.length line - 3) in
        Buffer.add_string buf "<h3>";
        Buffer.add_string buf (html_escape title);
        Buffer.add_string buf "</h3>\n"
      end
      else if String.starts_with ~prefix:"# " line then begin
        flush_paragraph ();
        let title = String.sub line 2 (String.length line - 2) in
        Buffer.add_string buf "<h2>";
        Buffer.add_string buf (html_escape title);
        Buffer.add_string buf "</h2>\n"
      end
      else if line = "" then flush_paragraph ()
      else paragraph := line :: !paragraph;
      process rest
  in
  ignore (process (String.split_on_char '\n' md));
  Buffer.contents buf

;;
;; the rest of the file
