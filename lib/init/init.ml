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
}

(* --- brownfield detection ----------------------------------------- *)

let exists_as_dir root sub =
  let p = Filename.concat root sub in
  Sys.file_exists p && Sys.is_directory p

let detect_brownfield ~root : brownfield =
  let has_arc42 = exists_as_dir root "docs/arc42" in
  let has_madr =
    exists_as_dir root "docs/adr"
    && not (exists_as_dir root "docs/arc42")
  in
  let has_adr_tools =
    exists_as_dir root "adr"
  in
  match has_arc42, has_madr, has_adr_tools with
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
   commitment: |\n\
   \  Replace the placeholder paths in `scope.paths` with the\n\
   \  directories that hold your kernel, scripts, and specs.\n\
   \  The kernel is offline and side-effect-free; everything\n\
   \  outside `scope.paths` is untracked by `mathc self-check`.\n\
   scope:\n\
   \  paths:\n\
   \    - \"src/**\"\n\
   \    - \"lib/**\"\n\
   \    - \"bin/**\"\n\
   \    - \"scripts/**\"\n\
   \    - \"spec/**\"\n\
   \    - \"schemas/**\"\n\
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
   relations:\n\
   \  addresses: []\n\
   \  supersedes: []\n\
   \  superseded_by: []\n"

(* --- pre-commit hook ---------------------------------------------- *)

let pre_commit_hook_body =
  "#!/usr/bin/env bash\n\
   # math-coding pre-commit hook (installed by `mathc init`).\n\
   #\n\
   # Runs `mathc validate` on every staged decisions/*.yaml, then\n\
   # `mathc self-check`. Exits non-zero on any failure; the\n\
   # commit is blocked.\n\
   set -eu\n\
   staged=$(git diff --cached --name-only -- 'decisions/*.yaml' 2>/dev/null || true)\n\
   if [ -n \"$staged\" ]; then\n\
   \  for f in $staged; do\n\
   \    if ! mathc validate \"$f\" >/dev/null; then\n\
   \      echo \"mathc: validate failed for $f\" >&2\n\
   \      exit 1\n\
   \    fi\n\
   \  done\n\
   fi\n\
   mathc self-check\n\
   "

let install_pre_commit_hook ~root =
  let dir = Filename.concat root ".githooks" in
  let path = Filename.concat dir "pre-commit" in
  (try Unix.mkdir dir 0o755 with
   | Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let oc = open_out path in
  output_string oc pre_commit_hook_body;
  close_out oc;
  Unix.chmod path 0o755

(* --- scaffold ----------------------------------------------------- *)

let write_file ~path ~contents =
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let scaffold ~root =
  let dec_dir = Filename.concat root "decisions" in
  let att_dir = Filename.concat root "attestations" in
  let dec_yaml = Filename.concat dec_dir "decision.yaml" in
  if Sys.file_exists dec_yaml then
    `Refuse_existing dec_yaml
  else begin
    (try Unix.mkdir dec_dir 0o755 with
     | Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    (try Unix.mkdir att_dir 0o755 with
     | Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    try
      write_file ~path:dec_yaml ~contents:master_policy_template;
      `Ok
    with
    | e -> `Io (Printexc.to_string e)
  end

(* --- top-level init ------------------------------------------------ *)

let check_brownfield (opts : options) : unit =
  match detect_brownfield ~root:opts.root with
  | Empty -> ()
  | _ when opts.merge -> ()
  | bf ->
      Printf.eprintf
        "mathc init: refusing to init in brownfield project (detected %s); \
         pass --merge to proceed or use `mathc import-adr` to import \
         existing ADR files\n"
        (string_of_brownfield bf);
      exit 3

let check_scaffold (root : string) : unit =
  match scaffold ~root with
  | `Ok -> ()
  | `Refuse_existing p ->
      Printf.eprintf
        "mathc init: refusing to overwrite existing %s; remove it or \
         pass --merge\n" p;
      exit 3
  | `Io m ->
      Printf.eprintf "mathc init: scaffold I/O error: %s\n" m;
      exit 3

let maybe_install_hook (opts : options) : unit =
  if not opts.no_install then
    try install_pre_commit_hook ~root:opts.root with
    | e ->
        Printf.eprintf
          "mathc init: pre-commit hook install failed: %s\n"
          (Printexc.to_string e);
        exit 3

let print_summary (opts : options) : unit =
  Printf.printf "mathc init: created %s/decisions, %s/attestations\n"
    opts.root opts.root;
  Printf.printf
    "  decision.yaml: schema math-coding/3.2, scope paths editable\n";
  if not opts.no_install then
    Printf.printf "  pre-commit hook: installed at .githooks/pre-commit\n"
  else
    Printf.printf "  pre-commit hook: skipped (--no-install)\n";
  begin match opts.from_adr with
  | None -> ()
  | Some _ ->
      Printf.eprintf
        "mathc init: --from-adr is not yet implemented in this slice; \
         run `mathc import-adr <path>` separately (decision \
         ux-3-import-adr-subcommand-2026-10).\n"
  end

let run (opts : options) : unit =
  check_brownfield opts;
  check_scaffold opts.root;
  maybe_install_hook opts;
  print_summary opts
