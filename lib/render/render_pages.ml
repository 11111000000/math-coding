(* lib/render/render_pages.ml — page-section renderers.

   Split from lib/render/render.ml. Renders the axioms section, the
   index, the per-decision page, and the per-spec / per-axiom pages.
   Depends on render_lang and render_md. *)

open Render_lang
open Render_md

let[@warning "-32"] render_axioms_section axioms =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "<section class=\"mathc-axioms\">\n";
  List.iter
    (fun (id, body) ->
      Printf.bprintf buf
        "<article class=\"mathc-axiom\">\n\
         <h2>%s</h2>\n\
         <div>%s</div>\n\
         </article>\n"
        (html_escape id) (md_parse body))
    axioms;
  Buffer.add_string buf "</section>\n";
  Buffer.contents buf

let[@warning "-32"] render_index ~lang ~version ~policy_id ~templates =
  let html =
    match List.assoc_opt lang templates.index with
    | Some html -> html
    | None -> "" (* fallback: language not shipped *)
  in
  substitute
    [
      ("version", html_escape version);
      ("policy_id", html_escape policy_id);
      ("check", "\xe2\x9c\x94");
    ]
    html

let[@warning "-32"] render_decision_page ~decision_id ~obligation_html =
  Printf.sprintf
    "<section class=\"mathc-decision-page\">\n<h1>%s</h1>\n%s\n</section>\n"
    decision_id obligation_html

let[@warning "-32"] render_spec_page ~name ~body_md =
  (* `spec/<name>.md` pages — normative algebra-3.2 spec, the
     constitution, the domain, the semantics. Each page is rendered
     with `enable_mathjax:true` so MathJax 3 (in defer mode) is
     injected into `<head>` and the page's `$..$` / `$$..$$`
     formulas are typeset as TeX at runtime. The class
     `mathc-spec-page` marks the wrapper so a future stylesheet
     can target math-heavy spec pages distinctly from prose site
     articles. *)
  let body_md_parsed = md_parse body_md in
  Printf.sprintf "<section class=\"mathc-spec-page\">\n%s\n</section>\n"
    body_md_parsed

let[@warning "-32"] render_axiom_page ~axiom_id ~body =
  (* If the source body starts with `# <title>`, strip that
     leading heading — the synthetic `<h1>Axiom <id></h1>` we
     emit is the only heading the page needs. Without this
     strip, every per-axiom page carries two `<h1>` (e.g. on
     `dist/axioms/feedback.html`: "Axiom feedback" from the
     template + "Axiom A1 — Feedback" from the source). *)
  let stripped_body =
    let trimmed = String.trim body in
    let len = String.length trimmed in
    if len > 2 && String.sub trimmed 0 2 = "# " then begin
      let prefix_len = 2 in
      let after_hash = String.sub trimmed prefix_len (len - prefix_len) in
      let nl_in_after =
        let s = String.length after_hash in
        let i = ref 0 in
        while !i < s && after_hash.[!i] <> '\n' do
          incr i
        done;
        if !i = s then s else !i
      in
      let first_line = String.sub after_hash 0 nl_in_after in
      (* `rest_start` is an offset into `trimmed`; convert it back to
         an offset into the original `body` by adding the leading
         whitespace count. *)
      let ws = ref 0 in
      while
        !ws < String.length body && (body.[!ws] = ' ' || body.[!ws] = '\n')
      do
        incr ws
      done;
      let rest_start_in_body = !ws + prefix_len + nl_in_after + 1 in
      let rest =
        if rest_start_in_body < String.length body then
          String.sub body rest_start_in_body
            (String.length body - rest_start_in_body)
        else ""
      in
      String.trim (Printf.sprintf "%s\n%s" first_line rest)
    end
    else body
  in
  (* Axiom icon (Phase 2 of site-quality-illustrations-2026-10).
     Each axiom carries a hand-rolled 80x80 SVG in
     `assets/axiom-<id>.svg` that encodes the axiom's
     essence. The mapping is fixed: A0 = separation,
     A1 = feedback, A2 = invariants, A3 = self-application,
     A4 = care. *)
  let axiom_icon_html =
    Printf.sprintf
      "<figure class=\"mathc-axiom-figure\">\n\
       <img class=\"mathc-axiom-icon\" src=\"assets/axiom-%s.svg\" alt=\"Axiom \
       %s icon\">\n\
       <figcaption>Axiom %s</figcaption>\n\
       </figure>\n"
      axiom_id axiom_id axiom_id
  in
  Printf.sprintf
    "<section class=\"mathc-axiom-page\">\n\
     <h1>Axiom %s</h1>\n\
     %s<div>%s</div>\n\
     </section>\n"
    axiom_id axiom_icon_html (md_parse stripped_body)
