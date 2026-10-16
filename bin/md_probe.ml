(* bin/md_probe.ml — fast parser probe (process-fastpath-2026-10).
 *
 * Reads markdown from stdin (or `--file PATH`) and prints the HTML
 * produced by `Render.md_parse`. Designed for parser-bug workflows
 * where a 5+ min full test cycle is wasteful: the agent can
 * iterate on `lib/render.ml` and see the output in <1s.
 *
 * Usage:
 *   dune exec bin/md_probe.exe -- <<'MD'
 *   1. first
 *   2. second
 *   MD
 *
 *   dune exec bin/md_probe.exe -- --file site/methodology.md
 *
 * Exit codes:
 *   0  ok
 *   2  bad usage (missing file, both --file and stdin)
 *
 * Implementation note: this is a thin driver around
 * `Render.md_parse`. It does not call `Render.build_pages`; for
 * site-level rendering use `scripts/render.sh`. The probe is for
 * parser-level debugging only. *)

let read_stdin () =
  (* Line-by-line read until EOF. Works for both pipes and
     regular files. Per OCAML_BEST_PRACTICES §11.16,
     `in_channel_length` on a subprocess pipe returns 0, so we
     cannot use it to size the read. *)
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_string buf (input_line stdin);
       Buffer.add_char buf '\n'
     done
   with End_of_file -> ());
  Buffer.contents buf

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  match args with
  | [] ->
      (* stdin *)
      let src = read_stdin () in
      print_string (Render.md_parse src)
  | [ "--file"; path ] ->
      let ic = open_in path in
      let n = in_channel_length ic in
      let src = really_input_string ic n in
      close_in ic;
      print_string (Render.md_parse src)
  | [ "--help" ] | [ "-h" ] ->
      Printf.printf "usage: md_probe [--file PATH]\n";
      Printf.printf "  reads markdown from stdin (or PATH) and prints HTML\n"
  | _ ->
      prerr_endline "md_probe: bad usage; try --help";
      exit 2
