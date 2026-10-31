(* lib/new_decision/new_decision.ml - `mathc new-decision <id>`
   implementation.
   The subcommand scaffolds a new decision file from a canonical
   template. The implementation lives in this sub-library per
   OCAML_BEST_PRACTICES \u00a710.1; the dispatcher in `bin/Mathc.ml`
   parses argv and forwards to `New_decision.run`.
   Pure module: the only I/O is reading the project root and
   writing the rendered template to disk. *)

(* `axiom-link-inference-2026-10`: when the produced decision
   lacks `axiom_link`, emit a soft-warn naming the top-3 most
   likely axiom IDs based on `scope.paths`. The warning code is
   `MC-AXIOM-LINK-INFERENCE-EMPTY` (registered in
   `lib/diagnostic.ml::explain`); the inference rule lives in
   `Decision.infer_axiom_candidates`. Suggest-only: the field
   is NEVER auto-filled; the author retains full control over
   the final axiom choice. *)

(* --- id validation ----------------------------------------------- *)

(* The kebab-case regex is the same regex that
   `mathc validate` uses for decision `id` validation. We
   mirror it here so the user gets a template that
   `mathc validate` will accept. *)
(* Pure-OCaml id validation: 1..128 chars, all in [a-z0-9._-],
   no leading or trailing dash. The character set matches
   `schemas/decision.json` (`^[a-z0-9][a-z0-9._-]{0,127}$`) so a
   `mathc new-decision <id>` invocation produces an id the
   kernel accepts. We avoid Str.regexp to sidestep the POSIX
   ERE interaction with shell-passed strings. *)
let is_id_char c =
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-' || c = '.'

let validate_id id =
  let len = String.length id in
  if len = 0 then Error "decision id is empty"
  else if len > 128 then Error "decision id exceeds 128 chars"
  else if (not (is_id_char id.[0])) || id.[0] = '-' then
    Error
      ("invalid decision id: " ^ id
     ^ " (expected to match schemas/decision.json pattern: \
        ^[a-z0-9][a-z0-9._-]{0,127}$)")
  else if (not (is_id_char id.[len - 1])) || id.[len - 1] = '-' then
    Error
      ("invalid decision id: " ^ id
     ^ " (expected to match schemas/decision.json pattern: \
        ^[a-z0-9][a-z0-9._-]{0,127}$)")
  else
    begin try
      for i = 0 to len - 1 do
        if not (is_id_char id.[i]) then raise Exit
      done;
      Ok id
    with Exit ->
      Error
        ("invalid decision id: " ^ id
       ^ " (expected to match schemas/decision.json pattern: \
          ^[a-z0-9][a-z0-9._-]{0,127}$)")
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
   `archive/decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml@1`.
`body_sha` and `yaml_sha` are 64-zero placeholders. The kernel
   VALIDATES but never WRITES them, so the placeholder must be
   replaced before the decision counts as attested: run
   `mathc rehash <path> --write`, which computes both fields from
   the file's own bytes under the body-vs-wrapper canonicalisation
   (algebra §7.1, `lib/decision.ml::body_canonical_sha256`) and
   verifies the result is a fixed point. Re-running
   `mathc validate` alone leaves the zeros in place — since
   §7.1 makes body_sha = yaml_sha, `0^64 = 0^64` satisfied the
   older string-equality check forever. See
   `decisions/enforce-body-sha-digest-2026-10`. *)

(* `paths_block`: format a `paths:` list for the
   `scope.paths` YAML block. When `paths` is empty, emits the
   legacy placeholder string so existing adopters (and the
   cram fixtures in `tests/cli/new-decision.t`) see the same
   output as before this commit. When `paths` is non-empty,
   emits one `- "<path>"` line per entry. *)
let[@warning "-32"] paths_block (paths : string list) : string =
  match paths with
  | [] -> "    - \"<path/glob/that/this/decision/touches/**>\""
  | _ ->
      String.concat ""
        (List.map (fun p -> Printf.sprintf "    - \"%s\"\n" p) paths)

let template ~id ~paths =
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
     %s\n\n\
     obligations:\n\
    \  - id: %s-obligation-1\n\
    \    claim: |\n\
    \      One sentence. What the kernel or fixture can verify.\n\
    \    acceptance:\n\
    \      all:\n\
    \        - verifier: <fixture-path-or-kernel-verifier>\n\
     risk:\n\
    \  declared_triggers:\n\
    \    - <what-could-go-wrong>\n\
    \  owner: \"<human:role or human:name>\"\n\n\
     relations:\n\
    \  addresses:\n\
    \    - bootstrap-v3@3\n"
    id (String.make 64 '0') (String.make 64 '0') id (paths_block paths) id

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
let template_minimal ~id ~paths =
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
    \      One sentence. The observable property this decision delivers.\n\n\
     scope:\n\
    \  paths:\n\
     %s\n\n\
     obligations:\n\
    \  - id: %s-obligation-1\n\
    \    claim: |\n\
    \      One sentence. What the kernel or fixture can verify.\n\
    \    acceptance:\n\
    \      all:\n\
    \        - verifier: \"<TODO: fixture-path-or-kernel-verifier>\"\n\
     axiom_link:\n\
    \  - A0\n\n\
     counterexample: |\n\
    \  TODO: the strongest practical objection to this decision. At\n\
    \  mode light this is a warning, not a block, but an empty slot\n\
    \  is an admission that the counter-case was not considered.\n\n\
     risk:\n\
    \  declared_triggers:\n\
    \    - \"<TODO: what-could-go-wrong>\"\n\
    \  owner: \"<human:role or human:name>\"\n\n\
     relations:\n\
    \  addresses:\n\
    \    - bootstrap-v3@3\n"
    id (String.make 64 '0') (String.make 64 '0') id (paths_block paths) id

(* template_for: pick the template variant. `Full` preserves the
   47-line adoption/SKILL.md-shaped output emitted since the
   subcommand landed (decision
   `ux-3-new-decision-subcommand-2026-10@1`); `Minimal` is the
   5-7 user-editable field stub on schema 3.3. The `paths`
   argument overrides the `scope.paths` placeholder when
   non-empty; empty list preserves the legacy placeholder
   string so existing adopters see no behavioural change. *)
let template_for (kind : template_kind) ~id ~paths =
  let raw =
    match kind with
    | Full -> template ~id ~paths
    | Minimal -> template_minimal ~id ~paths
  in
  (* Stamp a REAL digest instead of the 64-zero placeholder.

     The templates above emit `sha256:0000...` because the digest is
     a fixed point: it is the digest of the file *including* its own
     digest fields, so it cannot be written until the content is
     final. That was harmless while the validator only compared the
     two stored fields to each other, since 0^64 = 0^64 satisfied the
     equality invariant forever. It stops being harmless once
     MC-SHA-DIGEST-STALE recomputes the digest: a freshly scaffolded
     decision would be rejected by `mathc validate`, which breaks the
     scaffold-then-validate loop the tool exists to support.

     `stamp_digest` substitutes a literal hex and is
     length-preserving, so stamping cannot change the canonical form
     that was hashed — the write is a fixed point. Asserting that here
     rather than assuming it means a future edit to the templates
     cannot silently reintroduce a scaffold that does not validate. *)
  let computed = Decision.body_canonical_sha256 raw in
  let hex = String.sub computed 7 (String.length computed - 7) in
  let stamped = Decision.stamp_digest ~hex raw in
  if not (String.equal (Decision.body_canonical_sha256 stamped) computed) then
    failwith
      (Printf.sprintf
         "new-decision: stamped digest is not a fixed point for %s (%s vs %s)"
         id computed
         (Decision.body_canonical_sha256 stamped));
  stamped

(* `scope_paths_override_from_env` — read the
   `MATH_CODING_NEW_DECISION_SCOPE_PATHS` env var as a
   comma-separated list of paths. Returns `Some paths` when
   the env var is set to a non-empty value, `None` otherwise
   (signalling "use the template's default placeholder").
   The env var is a low-effort user-facing escape hatch — no
   new CLI flag is added. Primary use is the cram test in
   `tests/cli/new-decision-axiom-warn.t`, which needs real
   paths to exercise the inference rule for `lib/`, `tests/`,
   `decisions/`, `spec/`, and empty paths. The end user can
   set the env var to pre-fill `scope.paths` at scaffold time
   so the resulting decision validates cleanly without
   re-editing the placeholder. *)
let[@warning "-32"] scope_paths_override_from_env () : string list option =
  match Sys.getenv_opt "MATH_CODING_NEW_DECISION_SCOPE_PATHS" with
  | None -> None
  | Some s -> (
      let parts = String.split_on_char ',' s in
      let cleaned = List.filter (fun p -> String.trim p <> "") parts in
      match cleaned with [] -> None | _ -> Some cleaned)

(* `extract_scope_paths`: parse the `scope.paths` list out of
   the rendered template's text content. The template's
   structure is fixed (the `paths:` block is always at the
   same indentation level), so we use a small line-based
   parser instead of the full kernel YAML reader. Returns
   the list of path strings; empty list when the block is
   missing or unparseable.

   Only used by the soft-warn code path (when the env-var
   override is unset and the template carries the
   placeholder); the kernel's full YAML parser is the source
   of truth for everything else. *)
let[@warning "-32"] extract_scope_paths (contents : string) : string list =
  let[@warning "-32"] strip_prefix ~prefix s =
    let pl = String.length prefix in
    if String.length s >= pl && String.sub s 0 pl = prefix then
      Some (String.sub s pl (String.length s - pl))
    else None
  in
  let[@warning "-32"] strip_quote s =
    let len = String.length s in
    if len >= 2 && s.[0] = '"' && s.[len - 1] = '"' then
      Some (String.sub s 1 (len - 2))
    else Some s
  in
  let[@warning "-32"] path_from_line line =
    let t = String.trim line in
    match strip_prefix ~prefix:"- " t with
    | None -> None
    | Some rest -> (
        match strip_quote rest with Some p when p <> "" -> Some p | _ -> None)
  in
  let lines = String.split_on_char '\n' contents in
  let[@warning "-32"] rec scan_paths = function
    | [] -> []
    | "  paths:" :: rest ->
        let[@warning "-32"] rec take_paths acc = function
          | [] -> List.rev acc
          | line :: more ->
              if String.length line >= 4 && String.sub line 0 4 = "    " then
                match path_from_line line with
                | Some p -> take_paths (p :: acc) more
                | None -> List.rev acc
              else List.rev acc
        in
        take_paths [] rest
    | _ :: rest -> scan_paths rest
  in
  scan_paths lines

(* `has_axiom_link_block`: return true if the template
   carries an `axiom_link:` block (with at least one
   non-empty entry). The Minimal template hardcodes
   `axiom_link: [A0]`; the Full template omits the field
   entirely. The soft-warn fires only on the Full template
   (or any template that lacks the field). *)
let[@warning "-32"] has_axiom_link_block (contents : string) : bool =
  let lines = String.split_on_char '\n' contents in
  let[@warning "-32"] rec loop = function
    | [] -> false
    | line :: rest ->
        let t = String.trim line in
        if t = "axiom_link:" then true else loop rest
  in
  loop lines

(* `emit_axiom_link_inference_warn`: print the soft-warn to
   stderr when the produced decision lacks `axiom_link` and
   we have a non-trivial scope.paths. Format:

     deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: scope.paths includes \
     <paths>; top candidates: <ax1>, <ax2>, <ax3>; add axiom_link

   The code `MC-AXIOM-LINK-INFERENCE-EMPTY` is registered in
   `lib/diagnostic.ml::explain` so `mathc explain-diagnostic
   MC-AXIOM-LINK-INFERENCE-EMPTY` returns prose remediation. *)
let[@warning "-32"] emit_axiom_link_inference_warn (paths : string list) =
  let candidates = Decision.infer_axiom_candidates paths in
  let paths_str =
    if List.length paths <= 3 then String.concat ", " paths
    else
      Printf.sprintf "%s, ... (%d total)"
        (String.concat ", " (List.filteri (fun i _ -> i < 3) paths))
        (List.length paths)
  in
  let cand_str = Decision.axiom_candidates_pretty candidates in
  Printf.fprintf stderr
    "deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: scope.paths includes %s; top \
     candidates: %s; add axiom_link\n"
    paths_str cand_str

(* --- project root resolution ---------------------------------- *)

(* Nearest ancestor of `start` (inclusive) holding a `dune-project`.
   Same predicate as the `climb` inside
   `bin/Mathc.ml::find_project_root`; that helper lives in `bin/` and
   is not linkable from this sub-library, so the walk is repeated
   rather than extracted. Returns `None` when no ancestor qualifies,
   which is the adopter-project case (an artifact layout exists with
   or without dune). *)
let[@warning "-32"] climb_to_dune_project start =
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then Some d
    else
      let parent = Filename.dirname d in
      if parent = d then None else loop parent
  in
  loop start

(* Resolution chain, first hit wins:
     1. $MATH_CODING_ROOT — explicit, recommended for tests
     2. $DUNE_SOURCEROOT  — dune cram runtime export
     3. the nearest ancestor of the cwd holding a `dune-project`
     4. the cwd itself

   Step 3 is the one this revision adds. Previously the chain fell
   straight from (2) to (4), so `mathc new-decision ID --write` run
   from `<project>/lib/deep` with both env vars unset resolved the
   layout against `<project>/lib/deep`, found neither `.math-coding/`
   nor `decisions/` there, chose the New default, and died on the
   single-level `Unix.mkdir` with an uncaught
   `Unix_error (ENOENT, "mkdir", "<project>/lib/deep/.math-coding/decisions")`
   — no decision written, exit 3. With (3) the same invocation
   climbs to `<project>`, sees the project's real layout, and writes
   into it. Decision `path-probe-anchoring-2026-11@1`, whose
   `risk.drift_recurs` records this site as the residual gap left by
   the wave-1 anchoring pass.

   Steps (1) and (2) are unchanged and still win unconditionally
   (no `dune-project` existence check), because the env vars are the
   explicit override; step (4) is unchanged, so a non-dune project
   behaves exactly as before.

   THE ORDER OF (2) AND (3) IS WHAT CHANGED. `$DUNE_SOURCEROOT` is the
   DUNE TEST HARNESS's hint about where the source tree is. It is not
   a statement about the project the operator is working on. A writer
   that prefers it over the operator's own directory writes into the
   tree the harness pointed at.

   Measured: with a source build, `mathc new-decision x --write` run
   inside a fresh project wrote the decision into the KERNEL's own
   `decisions/` directory, because the harness exported
   `$DUNE_SOURCEROOT` and the chain preferred it over the cwd. The
   adopter's project got no decision; the kernel's corpus got a
   stranger's file. The cwd is now consulted BEFORE
   `$DUNE_SOURCEROOT`, and the climb recognises a math-coding layout
   marker (`dune-project`, `.math-coding/`, `decisions/`,
   `attestations/`) rather than only a dune project — an adopter's Go
   or Python repository has no `dune-project`, and the kernel must
   still write its decision THERE.

   `$DUNE_SOURCEROOT` remains as step (3), for the case the cwd cannot
   answer at all. *)
let project_root () =
  match Sys.getenv_opt "MATH_CODING_ROOT" with
  | Some p -> p
  | None -> (
      let cwd = Sys.getcwd () in
      let looks_like_project d =
        List.exists
          (fun name -> Sys.file_exists (Filename.concat d name))
          [ "dune-project"; ".math-coding"; "decisions"; "attestations" ]
      in
      let climb start =
        let rec loop d =
          if looks_like_project d then Some d
          else
            let parent = Filename.dirname d in
            if parent = d then None else loop parent
        in
        loop start
      in
      match climb cwd with
      | Some p -> p
      | None -> (
          match Sys.getenv_opt "DUNE_SOURCEROOT" with
          | Some p -> p
          | None -> cwd))

(* mkdir -p. The single-level `Unix.mkdir` this replaces raised an
   uncaught `Unix_error (ENOENT, "mkdir", ...)` whenever the parent of
   the resolved decisions directory did not exist yet. That is the
   ordinary case for a project holding no decisions: on the forward
   layout the resolver returns `.math-coding/decisions`, and
   `.math-coding/` is created by `mathc init`, which this command does
   not require to have run. The `dune-project` climb added by
   `path-probe-anchoring-2026-11` changed WHICH tree the layout probe
   reads; it never made the mkdir deeper, so the write still failed on
   the very path it was added to rescue.

   Same shape as the copies in `lib/import_adr/import_adr.ml` and
   `lib/init/init.ml`, and twice more in `bin/Mathc.ml`. Five copies of
   one recursive mkdir is the duplication worth paying down next;
   `decisions/new-decision-mkdir-parent-2026-10.yaml` records it as a
   follow-up rather than pretending this revision consolidated them. *)
let rec mkdir_p dir =
  if dir = "" || dir = "/" || dir = "." || Sys.file_exists dir then ()
  else begin
    mkdir_p (Filename.dirname dir);
    try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
  end

(* --- run ------------------------------------------------------- *)

type mode = Print_mode | Write_mode | Interactive_mode

type options = {
  id : string;
  mode : mode;
  force : bool;
  template_kind : template_kind;
}

(* `emit_scope_placeholder_warn`: the scaffold's scope path is a
   placeholder that matches no file. A scope that matches no file
   makes the materials digest a digest of NOTHING, and an empty
   digest is the freshness wildcard: the attestation is fresh for
   every tree, for ever, and no change can invalidate it. That is
   the defect class `semantics A` closed for the store, and the
   scaffold must not open it again on the way in.

   The check is a string comparison, not a filesystem probe: the
   scaffold is written before the project has any source tree, and
   the placeholder is a known literal. *)
let[@warning "-32"] emit_scope_placeholder_warn contents =
  let placeholder = "<path/glob/that/this/decision/touches/**>" in
  let is_placeholder_line line =
    let t = String.trim line in
    t = "- \"" ^ placeholder ^ "\"" || t = "- " ^ placeholder
  in
  if not (List.exists is_placeholder_line (String.split_on_char '\n' contents))
  then ()
  else
    Printf.fprintf stderr
      "deficit/MC-SCOPE-PLACEHOLDER: scope.paths still names the placeholder \
       %s; a scope that matches no file makes the materials digest a digest of \
       nothing, and an empty digest is the freshness wildcard. Replace it with \
       the paths this decision actually covers.\n"
      placeholder

let run (opts : options) =
  match validate_id opts.id with
  | Error m ->
      Printf.fprintf stderr "mathc new-decision: %s\n" m;
      exit 2
  | Ok id -> (
      let paths_override = scope_paths_override_from_env () in
      let effective_paths =
        match paths_override with None -> [] | Some ps -> ps
      in
      let contents =
        template_for opts.template_kind ~id ~paths:effective_paths
      in
      match opts.mode with
      | Print_mode ->
          print_string contents;
          flush stdout;
          (* Soft-warn to keep the printed scaffold informative
             even when no file is written. *)
          if not (has_axiom_link_block contents) then (
            let warn_paths =
              match paths_override with
              | Some ps -> ps
              | None -> extract_scope_paths contents
            in
            emit_axiom_link_inference_warn warn_paths;
            emit_scope_placeholder_warn contents)
      | Interactive_mode ->
          Printf.printf
            "mathc new-decision: --interactive is a no-op stub in this slice; \
             the printed template below is the scaffold.\n";
          print_string contents;
          flush stdout;
          Printf.fprintf stdout
            "mathc new-decision: --write would write to %s/decisions/%s.yaml\n"
            (project_root ()) id;
          if not (has_axiom_link_block contents) then
            let warn_paths =
              match paths_override with
              | Some ps -> ps
              | None -> extract_scope_paths contents
            in
            emit_axiom_link_inference_warn warn_paths
      | Write_mode ->
          let root = project_root () in
          (* `~root` anchors the layout probe on the same tree the
             result is composed onto. Without it the probe asks
             `Path_config.effective_root` — which reads only
             $MATH_CODING_ROOT, not $DUNE_SOURCEROOT and not the
             `dune-project` climb above — while the concat uses the
             full chain, so under $DUNE_SOURCEROOT-only conditions the
             two disagreed about which layout the project uses.
             Decision `path-probe-anchoring-2026-11@1`. *)
          let path =
            Filename.concat root (Path_config.resolve_decisions_dir ~root ())
          in
          mkdir_p path;
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
          Printf.printf "mathc new-decision: wrote %s\n" target;
          if not (has_axiom_link_block contents) then begin
            let warn_paths =
              match paths_override with
              | Some ps -> ps
              | None -> extract_scope_paths contents
            in
            emit_axiom_link_inference_warn warn_paths
          end;
          emit_scope_placeholder_warn contents)
