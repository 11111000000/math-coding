(* lib/new_decision/new_decision.ml - `mathc new-decision <id>`
   implementation.
   The subcommand scaffolds a new decision file from a canonical
   template. The implementation lives in this sub-library per
   OCAML_BEST_PRACTICES \u00a710.1; the dispatcher in `bin/Mathc.ml`
   parses argv and forwards to `New_decision.run`.
   Pure module: the only I/O is reading the project root and
   writing the rendered template to disk. *)

(* --- id validation ----------------------------------------------- *)

(* The kebab-case regex is the same regex that
   `mathc validate` uses for decision `id` validation. We
   mirror it here so the user gets a template that
   `mathc validate` will accept. *)
(* Pure-OCaml id validation: 1..128 chars, all in [a-z0-9-], no
   leading or trailing dash. We avoid Str.regexp to sidestep the
   POSIX ERE interaction with shell-passed strings. *)
let is_id_char c = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-'

let validate_id id =
  let len = String.length id in
  if len = 0 then Error "decision id is empty"
  else if len > 128 then Error "decision id exceeds 128 chars"
  else if (not (is_id_char id.[0])) || id.[0] = '-' then
    Error
      ("invalid decision id: " ^ id
     ^ " (expected kebab-case: must start with [a-z0-9])")
  else if (not (is_id_char id.[len - 1])) || id.[len - 1] = '-' then
    Error
      ("invalid decision id: " ^ id
     ^ " (expected kebab-case: must end with [a-z0-9])")
  else
    begin try
      for i = 0 to len - 1 do
        if not (is_id_char id.[i]) then raise Exit
      done;
      Ok id
    with Exit ->
      Error
        ("invalid decision id: " ^ id
       ^ " (expected kebab-case: only [a-z0-9-] allowed)")
    end

(* --- template ------------------------------------------------- *)

(* Template variants. `Full` is the canonical adoption/SKILL.md
   Step-3 shaped template first shipped by
   `ux-3-new-decision-subcommand-2026-10@1`; `Minimal` is the
   5-7 user-editable field stub on `math-coding/3.3` shipped by
   `ux-3-new-decision-template-minimal-2026-10`. The dispatcher
   in `bin/Mathc.ml` selects the variant via
   `--template=<minimal|full>`. *)
type template_kind = Full | Minimal

(* The template mirrors `adoption/SKILL.md` Step 3 with `<id>`
   substituted in. The schema-string is `math-coding/3.2` to
   match the live schema after
   `decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml@1`.
   `body_sha` and `yaml_sha` are 64-zero placeholders; the
   user re-runs `mathc validate` after the first edit, and the
   kernel recomputes the digests via the body-vs-wrapper
   canonicalization algorithm (algebra \u00a77.1,
   `lib/decision.ml::body_canonical_sha256`). *)

let template ~id =
  Printf.sprintf
    "---\n\
     schema: math-coding/3.2\n\
     id: %s\n\
     revision: 1\n\
     state: active\n\
     body_sha: \"sha256:%s\"\n\
     yaml_sha: \"sha256:%s\"\n\n\
     intent: |\n\
    \  One paragraph. What should become true after this decision lands?\n\n\
     commitment: |\n\
    \  Two sentences max. What is promised. If you cannot phrase it in two\n\
    \  sentences, the decision is not ready.\n\n\
     outcomes:\n\
    \  - id: %s-outcome-1\n\
    \    statement: |\n\
    \      One sentence. The observable property this decision delivers.\n\n\
     scope:\n\
    \  paths:\n\
    \    - \"<path/glob/that/this/decision/touches/**>\"\n\n\
     obligations:\n\
    \  - id: %s-obligation-1\n\
    \    claim: |\n\
    \      One sentence. What the kernel or fixture can verify.\n\
    \    acceptance:\n\
    \      all:\n\
    \        - verifier: <fixture-path-or-kernel-verifier>\n\
    \          result: pass\n\n\
     risk:\n\
    \  declared_triggers:\n\
    \    - <what-could-go-wrong>\n\
    \  owner: <human:role or human:name>\n\n\
     relations:\n\
    \  addresses:\n\
    \    - bootstrap-v3@3\n"
    id (String.make 64 '0') (String.make 64 '0') id id

(* Minimal template: 5-7 user-editable TODO stubs (intent,
   commitment, outcomes, obligations, risk owner, relations)
   plus the kernel-required defaults
   (axiom_link, scope, risk.declared_triggers, body_sha,
   yaml_sha). The `mode: light` keeps the counterexample slot
   from blocking accept; the user adds a counterexample when
   they fill in the stub. The schema family is bumped to
   `math-coding/3.3` (current published brand); the full
   template above is preserved on 3.2 for backward
   compatibility with existing adopters.

   The result is a valid `mathc validate` accept (with the
   soft `deficit/MC-COUNTEREXAMPLE-MISSING` warning). The
   user is expected to fill in the TODO markers and re-run
   `mathc validate` after their first edit; the kernel
   recomputes the SHA digests. *)
let template_minimal ~id =
  Printf.sprintf
    "---\n\
     schema: math-coding/3.3\n\
     id: %s\n\
     revision: 1\n\
     state: active\n\
     mode: light\n\
     body_sha: \"sha256:%s\"\n\
     yaml_sha: \"sha256:%s\"\n\n\
     intent: |\n\
    \  TODO: one paragraph. What should become true after this decision lands?\n\n\
     commitment: |\n\
    \  TODO: two sentences max. What is promised.\n\n\
     outcomes:\n\
    \  - id: %s-outcome-1\n\
    \    statement: |\n\
    \      TODO: one sentence. The observable property this decision delivers.\n\n\
     scope:\n\
    \  paths:\n\
    \    - \"<TODO: path/glob/that/this/decision/touches/**>\"\n\n\
     obligations:\n\
    \  - id: %s-obligation-1\n\
    \    claim: |\n\
    \      TODO: one sentence. What the kernel or fixture can verify.\n\
    \    acceptance:\n\
    \      all:\n\
    \        - verifier: <TODO: fixture-path-or-kernel-verifier>\n\
    \          result: pass\n\n\
     axiom_link:\n\
    \  - A0\n\n\
     risk:\n\
    \  declared_triggers:\n\
    \    - <TODO: what-could-go-wrong>\n\
    \  owner: <human:role or human:name>\n\n\
     relations:\n\
    \  addresses:\n\
    \    - bootstrap-v3@3\n"
    id (String.make 64 '0') (String.make 64 '0') id id

(* template_for: pick the template variant. `Full` preserves the
   47-line adoption/SKILL.md-shaped output emitted since the
   subcommand landed (decision
   `ux-3-new-decision-subcommand-2026-10@1`); `Minimal` is the
   5-7 user-editable field stub on schema 3.3. *)
let template_for (kind : template_kind) ~id =
  match kind with Full -> template ~id | Minimal -> template_minimal ~id

(* --- project root resolution ---------------------------------- *)

let project_root () =
  match Sys.getenv_opt "MATH_CODING_ROOT" with
  | Some p -> p
  | None -> (
      match Sys.getenv_opt "DUNE_SOURCEROOT" with
      | Some p -> p
      | None -> Sys.getcwd ())

(* --- run ------------------------------------------------------- *)

type mode = Print_mode | Write_mode | Interactive_mode

type options = {
  id : string;
  mode : mode;
  force : bool;
  template_kind : template_kind;
}

let run (opts : options) =
  match validate_id opts.id with
  | Error m ->
      Printf.fprintf stderr "mathc new-decision: %s\n" m;
      exit 2
  | Ok id -> (
      let contents = template_for opts.template_kind ~id in
      match opts.mode with
      | Print_mode ->
          print_string contents;
          flush stdout
      | Interactive_mode ->
          Printf.printf
            "mathc new-decision: --interactive is a no-op stub in this slice; \
             the printed template below is the scaffold.\n";
          print_string contents;
          flush stdout;
          Printf.fprintf stdout
            "mathc new-decision: --write would write to %s/decisions/%s.yaml\n"
            (project_root ()) id
      | Write_mode ->
          let root = project_root () in
          let path = Filename.concat root "decisions" in
          (try Unix.mkdir path 0o755
           with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
          let target = Filename.concat path (id ^ ".yaml") in
          if Sys.file_exists target && not opts.force then begin
            Printf.fprintf stderr
              "mathc new-decision: %s already exists; pass --force to overwrite\n"
              target;
            exit 1
          end;
          let oc = open_out target in
          output_string oc contents;
          close_out oc;
          Printf.printf "mathc new-decision: wrote %s\n" target)
