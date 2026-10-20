(* lib/init/init.ml — `mathc init` implementation.
 *
 * Scaffolds a new math-coding project: creates `decisions/` and
 * `attestations/`, writes `decisions/decision.yaml` from a
 * minimal master-policy template, and installs the pre-commit
 * hook (unless --no-install).
 *
 * Brownfield detection: refuses on arc42 (`docs/arc42/`),
 * MADR (`docs/adr/`), or adr-tools (`adr/`) unless `--merge`
 * is passed. This is the Q5 "Refuse + explicit --merge" answer.
 *
 * Adapter convention: lives in `lib/init/` as a sub-library per
 * OCAML_BEST_PRACTICES §10.1. The kernel under `lib/` stays
 * offline; this module is I/O. *)

type brownfield = Empty | Arc42 | Madr | AdrTools | Mixed
type agent = Generic | Opencode | ClaudeCode | Cursor | Continue

type options = {
  root : string;
  agent : agent;
  from_adr : string option;
  no_install : bool;
  merge : bool;
  with_ci_workflow : bool;
}

(* --- brownfield detection ----------------------------------------- *)

let exists_as_dir root sub =
  let p = Filename.concat root sub in
  Sys.file_exists p && Sys.is_directory p

let detect_brownfield ~root : brownfield =
  let has_arc42 = exists_as_dir root "docs/arc42" in
  let has_madr =
    exists_as_dir root "docs/adr" && not (exists_as_dir root "docs/arc42")
  in
  let has_adr_tools = exists_as_dir root "adr" in
  match (has_arc42, has_madr, has_adr_tools) with
  | false, false, false -> Empty
  | true, false, false -> Arc42
  | false, true, false -> Madr
  | false, false, true -> AdrTools
  | _, _, _ -> Mixed

let string_of_brownfield = function
  | Empty -> "empty"
  | Arc42 -> "arc42 (docs/arc42/)"
  | Madr -> "MADR (docs/adr/)"
  | AdrTools -> "adr-tools (adr/)"
  | Mixed -> "mixed (arc42 + MADR + adr-tools)"

(* --- agent --------------------------------------------------------- *)

let agent_of_string s =
  match String.lowercase_ascii s with
  | "opencode" -> Ok Opencode
  | "claude-code" | "claude_code" | "claudecode" -> Ok ClaudeCode
  | "cursor" -> Ok Cursor
  | "continue" | "continue.dev" -> Ok Continue
  | "generic" | "" -> Ok Generic
  | _ ->
      Error
        ("unknown --agent value: " ^ s
       ^ " (expected: generic | opencode | claude-code | cursor | continue)")

let string_of_agent = function
  | Generic -> "generic"
  | Opencode -> "opencode"
  | ClaudeCode -> "claude-code"
  | Cursor -> "cursor"
  | Continue -> "continue"

(* --- minimal master-policy template ------------------------------- *)

let master_policy_template =
  "schema: math-coding/3.2\n\
   id: bootstrap-v3\n\
   revision: 1\n\
   state: active\n\
   intent: |\n\
  \  Master policy for this project. Edit `scope.paths[]` below to\n\
  \  match the source tree under version control. The shipped\n\
  \  `mathc` binary uses this file as the active policy when\n\
  \  running `mathc self-check` and `mathc gate`.\n\
   axiom_link:\n\
  \  - A0\n\
  \  - A3\n\
   commitment: |\n\
  \  Replace the placeholder paths in `scope.paths` with the\n\
  \  directories that hold your kernel, scripts, and specs.\n\
  \  The kernel is offline and side-effect-free; everything\n\
  \  outside `scope.paths` is untracked by `mathc self-check`.\n\
   counterexample: |\n\
  \  The strongest objection considered and rejected: \"Adopting\n\
  \  math-coding is overhead for a project where one developer\n\
  \  works alone.\" That fails as a reason to skip. The\n\
  \  applicability envelope (spec/algebra-3.2.md §28) is\n\
  \  default-on: its only Path C class is prototype_or_throwaway,\n\
  \  and \"we are small\" is not a membership test. The friction\n\
  \  observation survives as a mode choice rather than an exit —\n\
  \  declare `mode_floor: light` in this project's policies.yaml\n\
  \  and the per-commit cost falls to {commitment, counterexample}\n\
  \  plus a `decision:` trailer. What stays behind is the part\n\
  \  that outlives the maintainer's memory. What would change the\n\
  \  verdict: if this project turns out to be a spike nobody\n\
  \  reopens, delete this tree and say why in the README.\n\
   scope:\n\
  \  paths:\n\
  \    - \"src/**\"\n\
  \    - \"tests/**\"\n\
  \    - \"docs/**\"\n\
  \    - \"scripts/**\"\n\
  \    - \"schemas/**\"\n\
  \    - \"site/**\"\n\
  \  exclusions:\n\
  \    - \"**/.git/**\"\n\
   outcomes:\n\
  \  - id: master-policy-active\n\
  \    statement: |\n\
  \      This file is the active policy; `mathc self-check`\n\
  \      reads it on every invocation.\n\
   obligations:\n\
  \  - id: scope-paths-match-tree\n\
  \    claim: |\n\
  \      Every source file under version control appears in\n\
  \      `scope.paths` or is explicitly excluded.\n\
  \    acceptance:\n\
  \      all:\n\
  \        - verifier: mathc self-check\n\
  \          result: pass\n\
   - verifier: tests/cli/init-scope-language-agnostic.t\n\
   result: pass\n\
   risk:\n\
  \  declared_triggers:\n\
  \    - bootstrap-template-not-edited\n\
  \    - kernel-changed-without-self-application\n\
  \  owner: human:maintainer\n\
   relations:\n\
  \  addresses: []\n\
  \  supersedes: []\n\
  \  superseded_by: []\n"

(* --- file I/O helpers --------------------------------------------- *)

let write_file ~path ~contents =
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let[@warning "-32"] read_file_text path : string =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

(* --- pre-commit hook ---------------------------------------------- *)

let pre_commit_hook_body =
  "#!/usr/bin/env bash\n\
   # math-coding pre-commit hook (installed by `mathc init`).\n\
   #\n\
   # Runs `mathc validate` on every staged decisions/*.yaml, then\n\
   # `mathc self-check`. Exits non-zero on any failure; the\n\
   # commit is blocked.\n\
   set -eu\n\
   staged=$(git diff --cached --name-only -- 'decisions/*.yaml' 2>/dev/null || \
   true)\n\
   if [ -n \"$staged\" ]; then\n\
  \  for f in $staged; do\n\
  \    if ! mathc validate \"$f\" >/dev/null; then\n\
  \      echo \"mathc: validate failed for $f\" >&2\n\
  \      exit 1\n\
  \    fi\n\
  \  done\n\
   fi\n\
   mathc self-check\n"

let install_pre_commit_hook ~root =
  let dir = Filename.concat root ".githooks" in
  let path = Filename.concat dir "pre-commit" in
  (try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let oc = open_out path in
  output_string oc pre_commit_hook_body;
  close_out oc;
  Unix.chmod path 0o755

(* --- CI workflow -------------------------------------------------- *)

(* Walk up from the binary's directory looking for
 * `templates/ci.yml`. The binary lives at
 * `<src>/_build/<ctx>/bin/mathc.exe`; the source is at
 * `<src>/templates/ci.yml`. The walk covers both the
 * default-context path and the install-context path
 * (`_build/install/default/bin/mathc.exe`, 4 levels up),
 * and falls back to None when running from a release
 * tarball that does not bundle templates/. *)
let[@warning "-32"] find_source_ci_workflow () : string option =
  let exe = Sys.executable_name in
  let rec walk dir =
    if dir = "/" || dir = "." || dir = "" then None
    else begin
      let candidate =
        Filename.concat (Filename.concat dir "templates") "ci.yml"
      in
      if Sys.file_exists candidate then Some candidate
      else walk (Filename.concat dir "..")
    end
  in
  walk (Filename.dirname exe)

(* Install the CI workflow file. The template is embedded in
   the binary (`Templates_embedded.ci_yml`); no filesystem walk
   is needed. When the caller passes `--allow-fs-templates`, the
   filesystem walk is still attempted first (kernel developers
   editing the source want their edits to land in downstream
   `init` runs without rebuilding). *)
let[@warning "-32"] install_ci_workflow ~root : bool =
  let dir = Filename.concat root ".github" in
  let wf_dir = Filename.concat dir "workflows" in
  let dst = Filename.concat wf_dir "ci.yml" in
  (try Unix.mkdir dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  (try Unix.mkdir wf_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  if Sys.file_exists dst then begin
    Printf.printf
      "  ci workflow: %s already exists, skipping (remove it first to \
       regenerate)\n"
      dst;
    false
  end
  else begin
    let contents =
      match find_source_ci_workflow () with
      | Some src when Sys.getenv_opt "MATH_CODING_USE_FS_TEMPLATES" <> None ->
          read_file_text src
      | _ -> Templates_embedded.ci_yml
    in
    write_file ~path:dst ~contents;
    Printf.printf "  ci workflow: wrote %s (from embedded template)\n" dst;
    true
  end

(* --- applicability envelope (spec/algebra-3.2.md §28) -------------- *)

(* The envelope is default-on per decision `solo-default-on-2026-10@1`:
   `mathc init` installs the kernel for any project expected to outlive
   the next refactor — a single maintainer included. To skip, the project
   must be throwaway, and the rationale goes where a reader finds it.
   `init` cannot observe team size, agent count, or audit obligations —
   it is one process with one writer, and the project may be empty — so
   it prints the envelope it assumed rather than guessing a path. The
   operator raises or lowers the floor in the project's own
   `policies.yaml` (`lib/policy.ml::mode_floor`); with no such file the
   kernel falls back to `default_policy.mode_floor = Tiny`. *)
let print_applicability_envelope () : unit =
  print_endline
    "  applicability envelope (spec/algebra-3.2.md \xC2\xA728, default-on):\n\
    \    path: Path A. Installed by default, a single maintainer included.\n\
    \      To skip, the project must be throwaway \xE2\x80\x94 prototype,\n\
    \      MVP, spike, one-day hackathon \xE2\x80\x94 and the rationale goes\n\
    \      in the README, per \xC2\xA723.\n\
    \    signals that lift the ceremony above the light floor:\n\
    \      - two or more AI agents (or humans) editing this repository\n\
    \      - regulatory or contractual audit needs a tamper-evident trail\n\
    \      - three or more maintainers on a five-or-more-year horizon\n\
    \      - an AI agent writes into the repository (one human is enough)\n\
    \    the one Path C class:\n\
    \      - prototype / MVP / spike / throwaway: no expected continuity\n\
    \    floor: no policies.yaml here, so the kernel uses its lowest rung\n\
    \      (Tiny). Declare mode_floor in the project's policies.yaml to\n\
    \      match reality. `mathc init` sees one writer and cannot detect\n\
    \      the signals above; they are yours to declare."

(* --- scaffold ----------------------------------------------------- *)

let[@warning "-32"] mkdir_p path =
  let rec loop p =
    if p = "" || p = "/" || p = "." then ()
    else if Sys.file_exists p then ()
    else begin
      loop (Filename.dirname p);
      try Unix.mkdir p 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
    end
  in
  loop path

let scaffold ~root =
  let dec_dir = Filename.concat root (Path_config.resolve_decisions_dir ()) in
  let att_dir =
    Filename.concat root (Path_config.resolve_attestations_dir ())
  in
  let dec_yaml = Filename.concat root (Path_config.resolve_policy_path ()) in
  if Sys.file_exists dec_yaml then `Refuse_existing dec_yaml
  else begin
    mkdir_p dec_dir;
    mkdir_p att_dir;
    try
      write_file ~path:dec_yaml ~contents:master_policy_template;
      `Ok
    with e -> `Io (Printexc.to_string e)
  end

(* --- top-level init ------------------------------------------------ *)

let check_brownfield (opts : options) : unit =
  match detect_brownfield ~root:opts.root with
  | Empty -> ()
  | _ when opts.merge -> ()
  | bf ->
      Printf.eprintf
        "mathc init: refusing to init in brownfield project (detected %s); \
         pass --merge to proceed or use `mathc import-adr` to import existing \
         ADR files\n"
        (string_of_brownfield bf);
      exit 3

let check_scaffold ~merge (root : string) : unit =
  match scaffold ~root with
  | `Ok -> ()
  | `Refuse_existing p when merge ->
      (* --merge: existing decision.yaml stays untouched; the rest of
         init (per-repo skill, .githooks, decisions/, attestations/) is
         still wired. Print a note so the maintainer knows. *)
      Printf.printf "mathc init: keeping existing %s (--merge); proceeding\n" p
  | `Refuse_existing p ->
      Printf.eprintf
        "mathc init: refusing to overwrite existing %s; remove it or pass \
         --merge\n"
        p;
      exit 3
  | `Io m ->
      Printf.eprintf "mathc init: scaffold I/O error: %s\n" m;
      exit 3

let maybe_install_hook (opts : options) : unit =
  if not opts.no_install then (
    try install_pre_commit_hook ~root:opts.root
    with e ->
      Printf.eprintf "mathc init: pre-commit hook install failed: %s\n"
        (Printexc.to_string e);
      exit 3)

let print_summary (opts : options) : unit =
  Printf.printf "mathc init: created %s/%s, %s/%s\n" opts.root
    (Path_config.resolve_decisions_dir ())
    opts.root
    (Path_config.resolve_attestations_dir ());
  Printf.printf
    "  decision.yaml: schema math-coding/3.2, scope paths editable\n";
  if not opts.no_install then
    Printf.printf "  pre-commit hook: installed at .githooks/pre-commit\n"
  else Printf.printf "  pre-commit hook: skipped (--no-install)\n";
  if opts.with_ci_workflow then
    Printf.printf
      "  ci workflow: installed at .github/workflows/ci.yml (see \
       `install_ci_workflow` notes above)\n";
  print_applicability_envelope ();
  begin match opts.from_adr with
  | None -> ()
  | Some _ ->
      Printf.eprintf
        "mathc init: --from-adr is not yet implemented in this slice; run \
         `mathc import-adr <path>` separately (decision \
         ux-3-import-adr-subcommand-2026-10).\n"
  end

(* --- per-user agent skill install ---------------------------------- *)

(* Per `install-tooling-2026-10@1`, the per-user opencode skill
 * lives at ${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/
 * math-coding/SKILL.md. The source for the skill is the
 * in-repo `.opencode/skills/math-coding/SKILL.md` file
 * (decision `ux-3-repo-tracked-opencode-skill-2026-10@1`).
 *
 * `mathc init --agent opencode` copies the source to the
 * per-user path. We resolve the source relative to the
 * running binary: for an in-tree build at
 * `_build/default/bin/mathc.exe`, the source is at
 * `<binary_dir>/../../.opencode/skills/math-coding/SKILL.md`.
 * For an installed binary (via `install.sh`), the source is
 * NOT bundled with the binary; the per-user install is
 * already covered by `install.sh --user-skill`, so we
 * print an instruction.
 *
 * Other agent values (claude-code, cursor, continue, generic)
 * are TODO in this slice. We print a one-liner pointing at
 * the relevant platform install. *)

let xdg_config_home () : string =
  match Sys.getenv_opt "XDG_CONFIG_HOME" with
  | Some p when p <> "" -> p
  | _ -> (
      match Sys.getenv_opt "HOME" with
      | Some h -> Filename.concat h ".config"
      | None -> Filename.concat (Sys.getcwd ()) ".config")

let find_source_skill () : string option =
  (* Walk up from the binary's directory looking for the
   * in-repo `.opencode/skills/math-coding/SKILL.md`. The binary
   * lives at `<src>/_build/<ctx>/bin/mathc.exe`; the source
   * is at `<src>/.opencode/skills/math-coding/SKILL.md`. The
   * walk also covers the case where the binary is at
   * `<src>/_build/install/default/bin/mathc.exe` (4 levels up)
   * and an installed-binary case (no source found). *)
  let exe = Sys.executable_name in
  let rec walk dir =
    if dir = "/" || dir = "." || dir = "" then None
    else begin
      let candidate =
        Filename.concat
          (Filename.concat dir ".opencode")
          (Filename.concat "skills" (Filename.concat "math-coding" "SKILL.md"))
      in
      if Sys.file_exists candidate then Some candidate
      else walk (Filename.concat dir "..")
    end
  in
  walk (Filename.dirname exe)

let per_user_opencode_skill () : string =
  let xdg = xdg_config_home () in
  Filename.concat
    (Filename.concat (Filename.concat xdg "opencode") "skills")
    (Filename.concat "math-coding" "SKILL.md")

let maybe_install_agent_skill (opts : options) : unit =
  match opts.agent with
  | Generic -> ()
  | Opencode ->
      let src = find_source_skill () in
      let dst = per_user_opencode_skill () in
      begin match src with
      | Some s ->
          mkdir_p (Filename.dirname dst);
          let ic = open_in s in
          let n = in_channel_length ic in
          let content = really_input_string ic n in
          close_in ic;
          let oc = open_out dst in
          output_string oc content;
          close_out oc;
          Printf.printf "  per-user opencode skill: installed at %s\n" dst
      | None ->
          Printf.eprintf
            "mathc init: --agent opencode: source skill not found; run \
             \xC2\xABinstall.sh --user-skill\xC2\xBB to install the per-user \
             skill (or use a math-coding source build where \
             \xC2\xAB.opencode/skills/math-coding/SKILL.md\xC2\xBB is present).\n"
      end
  | ClaudeCode ->
      Printf.eprintf
        "mathc init: --agent claude-code: per-user install is TODO; copy \
         \xC2\xABdist/adoption/claude-code/instructions.md\xC2\xBB from a \
         math-coding release tarball to your \xC2\xAB.claude/\xC2\xBB \
         directory.\n"
  | Cursor ->
      Printf.eprintf
        "mathc init: --agent cursor: per-user install is TODO; copy \
         \xC2\xABdist/adoption/cursor/rules.md\xC2\xBB from a math-coding \
         release tarball to \xC2\xAB.cursor/rules/math-coding.md\xC2\xBB.\n"
  | Continue ->
      Printf.eprintf
        "mathc init: --agent continue: Continue does not have a per-user rules \
         directory; the skill is per-repo \
         (\xC2\xAB.opencode/skills/math-coding/SKILL.md\xC2\xBB).\n"

let maybe_install_ci_workflow (opts : options) : unit =
  if opts.with_ci_workflow then (
    try
      let _installed = install_ci_workflow ~root:opts.root in
      ()
    with e ->
      Printf.eprintf "mathc init: ci workflow install failed: %s\n"
        (Printexc.to_string e);
      exit 3)

let run (opts : options) : unit =
  check_brownfield opts;
  check_scaffold ~merge:opts.merge opts.root;
  maybe_install_hook opts;
  maybe_install_ci_workflow opts;
  print_summary opts;
  maybe_install_agent_skill opts
