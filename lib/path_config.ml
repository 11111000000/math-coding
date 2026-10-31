(* lib/path_config.ml — Path resolver for math-coding filesystems.
 *
 * 3.3 → 3.4 contract (PLAN.md §0; AGENTS.md §worktree-first):
 *
 *   1. If the user sets the env-var (`MATH_CODING_DECISIONS_DIR`,
 *      `MATH_CODING_ATTESTATIONS_DIR`, `MATH_CODING_POLICY`), the
 *      env-var wins. No filesystem check.
 *
 *   2. Else, if the new-default path exists (`.math-coding/...`),
 *      the new-default wins. This is the forward path: a
 *      `mathc init` user gets `.math-coding/decisions/`,
 *      `.math-coding/attestations/`, `.math-coding/policy.yaml`.
 *
 *   3. Else, the legacy path (`decisions/`, `attestations/`,
 *      `decisions/decision.yaml`) is returned. This keeps every
 *      pre-3.4 project (which has `decisions/` and `attestations/`
 *      at the repo root) working without any config change.
 *
 * The functions return *relative* paths (no root prefix); callers
 * compose with `Filename.concat root ...` as before. The resolver
 * is intentionally pure (only `Sys.getenv_opt` and
 * `Sys.file_exists`) so unit tests are trivial.
 *
 * Why env-var lookup doesn't fail on bad paths: per PLAN.md §0.1
 * and AGENTS.md §worktree-first, the user owns the override. A
 * typo in `MATH_CODING_DECISIONS_DIR=foo/bar` resolves to
 * `foo/bar`; the kernel will surface the I/O error at the
 * call-site (mkdir / readdir), not here. The resolver does not
 * pretend to validate paths it doesn't own. *)

(* Default paths. Mirror PLAN.md §0.1. *)
let default_decisions_dir = ".math-coding/decisions"
let default_attestations_dir = ".math-coding/attestations"
let default_policy_path = ".math-coding/policy.yaml"

(* Legacy fallback paths. Pre-3.4 layout. *)
let legacy_decisions_dir = "decisions"
let legacy_attestations_dir = "attestations"
let legacy_policy_path = "decisions/decision.yaml"

(* --- public, parametric: env-var or filesystem-checked default ---- *)

(* Root-relative existence check. The three-tier precedence below is
   a question about *the project being operated on*, not about the
   process cwd: `mathc init /srv/app` run from `/home/me` must ask
   whether `/srv/app/.math-coding/decisions` exists, not whether
   `/home/me/.math-coding/decisions` does. Without this, `init`
   inherits the caller's layout and writes a legacy tree into a fresh
   project. Decision `kernel-fixes-found-bugs-2026-10@1`. *)
let[@warning "-32"] exists_under root rel =
  let p =
    match root with
    | Some r when r <> "" && r <> "." -> Filename.concat r rel
    | _ -> rel
  in
  Sys.file_exists p

(* The project root the question is asked about. An explicit `?root`
   wins (that is how `mathc init DIR` scopes itself). Otherwise
   $MATH_CODING_ROOT, when it names an existing directory. Otherwise
   the process cwd — `exists_under` treats `None` as cwd.

   Why the env var belongs here and not only in
   `bin/Mathc.ml::find_project_root`: that helper already anchors
   several code paths on $MATH_CODING_ROOT, but the resolver did
   not, so a caller with the var set and an unrelated cwd asked the
   resolver about a *different project* than the rest of the kernel
   used. Symptom: `MATH_CODING_ROOT=<repo> mathc gate` reported 0
   obligations against a repository holding 199 decisions, and six
   gate fixtures went red asserting a count they could no longer
   produce. Decision `kernel-fixes-found-bugs-2026-10@1`.

   The resolver requires only that the path exists and is a
   directory — unlike `find_project_root`, which additionally
   requires a `dune-project`, because the artifact layout exists
   with or without dune. *)
let[@warning "-32"] effective_root ?root () =
  match root with
  | Some r when String.trim r <> "" -> Some r
  | Some _ | None -> (
      match Sys.getenv_opt "MATH_CODING_ROOT" with
      | Some r
        when String.trim r <> "" && Sys.file_exists r && Sys.is_directory r ->
          Some r
      | _ -> None)

(* Layout choice, made ONCE per project. Three independent
   filesystem checks produced incoherent trees: a directory holding
   `decisions/` but no `decisions/decision.yaml` resolved the
   decisions dir to the legacy path and the policy to
   `.math-coding/policy.yaml`, so `mathc init` scaffolded half a
   project in each layout. The three paths are one layout decision
   (new forward layout, or legacy for a pre-3.4 tree); the env-vars
   still override each path individually and win outright.

   `New` wins when any `.math-coding/` artifact is present: that is
   the forward path and the legacy tree is left alone, not migrated.
   Decision `kernel-fixes-found-bugs-2026-10@1`. *)
type layout = New | Legacy

let[@warning "-32"] layout_of ?root () : layout =
  let root = effective_root ?root () in
  if
    exists_under root ".math-coding"
    || exists_under root default_policy_path
    || exists_under root default_decisions_dir
    || exists_under root default_attestations_dir
  then New
  else if
    exists_under root legacy_policy_path
    || exists_under root legacy_decisions_dir
    || exists_under root legacy_attestations_dir
  then Legacy
  else New

(* Two-tier precedence:
     1. env-var, if set (non-empty): wins unconditionally, no
        filesystem check. The operator owns the override.
     2. the project's layout, decided ONCE per project by
        `layout_of`: `New` yields the `.math-coding/` path, `Legacy`
        yields the pre-3.4 path. A fresh project has no artifacts,
        so `layout_of` returns `New` and `mathc init` creates the
        new layout instead of the legacy one — the behaviour the
        `ls -a` verification expectation describes.

   `?layout` lets a caller (and the unit tests, which resolve
   synthetic paths rather than the module constants) supply the
   decision instead of probing the filesystem. The existence checks
   in `layout_of` / `exists_under` are relative to `?root` when
   given, and to the process cwd when it is not. *)
let[@warning "-32"] resolve_with ?root ?layout env_var ~default ~fallback () :
    string =
  let root = effective_root ?root () in
  match Sys.getenv_opt env_var with
  | Some p when String.trim p <> "" -> p
  | _ -> (
      (match layout with Some l -> l | None -> layout_of ?root ()) |> function
      | New -> default
      | Legacy -> fallback)

(* --- public API --------------------------------------------------- *)

let[@warning "-32"] resolve_decisions_dir ?root () : string =
  resolve_with ?root "MATH_CODING_DECISIONS_DIR" ~default:default_decisions_dir
    ~fallback:legacy_decisions_dir ()

let[@warning "-32"] resolve_attestations_dir ?root () : string =
  resolve_with ?root "MATH_CODING_ATTESTATIONS_DIR"
    ~default:default_attestations_dir ~fallback:legacy_attestations_dir ()

let[@warning "-32"] resolve_policy_path ?root () : string =
  resolve_with ?root "MATH_CODING_POLICY" ~default:default_policy_path
    ~fallback:legacy_policy_path ()

(* The RISK-FLOOR policies file is a different artifact from the
   master policy, and the two were sharing one resolver.
*
*   master policy   the active protocol DECISION (bootstrap-v3@3);
*                   a decision document. Resolved by
*                   `resolve_policy_path`.
*   policies file   the multi-policy record that carries the
*                   per-path `mode_floor` (algebra §9): a YAML
*                   SEQUENCE of policy records. Resolved here.
*
* The collision was not cosmetic. `resolve_policy_path` returns
* `.math-coding/policy.yaml` when it exists and `decisions/decision.yaml`
* otherwise, and BOTH of those are decision documents: parsing either
* as a policy sequence yields an empty list, and the kernel's policy
* cache stays empty. So the `mode_floor` a project declares was never
* read: every path classified as `tiny`, the friction ladder had one
* rung, and `mathc mode` reported the silent baseline for a file whose
* policy said `standard`.
*
* The file the kernel actually wants is `policies.yaml` at the project
* root — the name `lib/policy.ml` already used, and the name this
* repository's own file has carried since the 3.0 bootstrap.
*
* Precedence:
*   1. `MATH_CODING_POLICIES` — the new, unambiguous name.
*   2. `MATH_CODING_POLICY` — the old name. It has always controlled
*      this file in the code (the master policy is located by id, not
*      by path), so it keeps working.
*   3. `policies.yaml` at the project root, if it is there.
*   4. `policies.yaml` anyway: the loader treats an absent file as
*      "no policy declared", which is algebra §9's default.
*
* Decision `record-proportionality-2026-10`. *)
let default_policies_path = "policies.yaml"

let[@warning "-32"] resolve_policies_path ?root () : string =
  match Sys.getenv_opt "MATH_CODING_POLICIES" with
  | Some p when String.trim p <> "" -> p
  | _ -> (
      match Sys.getenv_opt "MATH_CODING_POLICY" with
      | Some p when String.trim p <> "" -> p
      | _ -> default_policies_path)

(* Join a resolver answer with the project root. An ABSOLUTE answer is
   used as it is: `Filename.concat "/root" "/etc/policies.yaml"` is
   "/root//etc/policies.yaml", which is not the file the operator
   named. The env-var answers are absolute more often than not (a
   path in a CI job is usually absolute), and the old composition
   turned every one of them into a path that does not exist. *)
let[@warning "-32"] join_root ?root rel =
  if String.length rel > 0 && String.unsafe_get rel 0 = '/' then rel
  else
    match effective_root ?root () with
    | Some r when r <> "" && r <> "." -> Filename.concat r rel
    | _ -> rel

(* THE PROTECTED-PATH LIST.
 *
 * One file names the paths this project protects, and three consumers
 * read it: the gate (lib/gate.ml, through lib/protected_paths.ml), the
 * pre-commit hook (scripts/pre-commit/decision-fixture-co-commit.sh)
 * and the release-pending workflow. Before 2026-11 the three carried
 * three different lists, and `lib/` against `lib/*.ml` against `lib/*`
 * meant three gates protected three different sets of files.
 *
 * The path is resolved like the other project paths: the env-var wins
 * (the operator owns the override, and a test that needs a different
 * list must not have to edit the tree to get one), and the default is
 * the canonical location in the project.
 *
 * The default is NOT one of the `.math-coding/` artifacts: the
 * protected paths are this PROJECT's business, not part of the
 * protocol an adopter receives, and the plan that says so
 * (docs/plans/redundancy-and-portability-2026-11.md, T4.3) moves
 * these strings out of the kernel entirely. *)
let default_protected_paths_path = "scripts/protected-paths.txt"

let[@warning "-32"] resolve_protected_paths_path ?root () : string =
  match Sys.getenv_opt "MATH_CODING_PROTECTED_PATHS" with
  | Some p when String.trim p <> "" -> p
  | _ -> default_protected_paths_path

(* --- root-joined variants ------------------------------------------- *)
(* The functions above return *relative* paths; callers that already
   hold a project root compose with it themselves. Callers that do NOT
   (e.g. `import-adr --write`, which resolves against the process cwd)
   must use the `*_at` variants, which join the effective root — the
   explicit `?root` first, then $MATH_CODING_ROOT. Without them the
   resolver could answer "the target project uses .math-coding/" and
   then write the file relative to wherever the operator was standing.
   Decision `kernel-fixes-found-bugs-2026-10@1`. *)
let[@warning "-32"] at ?root rel =
  match effective_root ?root () with
  | Some r when r <> "" && r <> "." -> Filename.concat r rel
  | _ -> rel

let[@warning "-32"] decisions_dir_at ?root () : string =
  at ?root (resolve_decisions_dir ?root ())

let[@warning "-32"] attestations_dir_at ?root () : string =
  at ?root (resolve_attestations_dir ?root ())

let[@warning "-32"] policy_path_at ?root () : string =
  at ?root (resolve_policy_path ?root ())

(* --- verify-sandbox mode resolver (verify-sandbox-hardening@1) ---
 *
 * `mathc verify` (B1, add-verify-subcommand-2026-10) accepts a
 * `--sandbox=MODE` flag where MODE is one of none, minimal, strict.
 * The flag default is governed by the env var
 * MATH_CODING_VERIFY_SANDBOX so operators who run mathc verify
 * against third-party decision YAMLs can flip the default at the
 * process level without rewriting the decision file's verifier
 * strings.
 *
 * Returns one of `none | minimal | strict` as a plain string so
 * the value can flow through Arg.parse without conversion.
 * Unknown env-var values are coerced to `none` with a one-line
 * stderr warning; this matches the resolver's general policy of
 * "unknown env is benign default", preserved across
 * resolve_decisions_dir / resolve_attestations_dir /
 * resolve_policy_path.
 *
 * Default is `none` for back-compat with B1: v3.3.x callers that
 * pre-date this resolver see the same effective behaviour as the
 * pre-hardening mathc verify. The verify-sandbox-hardening
 * decision (commit a56c814) records the default-none trade-off
 * and the follow-up plan-2026-12 question of whether minimal
 * should become the new default after one or two release cycles.
 *)
let[@warning "-32"] resolve_sandbox_mode () : string =
  let env = "MATH_CODING_VERIFY_SANDBOX" in
  match Sys.getenv_opt env with
  | Some "none" -> "none"
  | Some "minimal" -> "minimal"
  | Some "strict" -> "strict"
  | Some s ->
      Printf.eprintf
        "warning: MATH_CODING_VERIFY_SANDBOX=%s is unknown; expected \
         none|minimal|strict; defaulting to none\n\
         %!"
        s;
      "none"
  | None -> "none"
