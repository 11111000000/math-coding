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

(* Three-tier precedence:
     1. env-var, if set: wins unconditionally (no filesystem check).
     2. default, if it exists on disk: kept (do not migrate).
     3. fallback, if it exists on disk: kept (backward-compat for
        pre-3.4 projects).
     4. else: synthesise the default. A fresh project running
        `mathc init` against an empty directory has neither the
        default nor the fallback on disk; the resolver returns
        the default so init creates the new layout instead of
        the legacy one. This matches the verification
        expectation that `ls -a` after first init shows
        `.math-coding/` and no `decisions/`.
*)
let resolve_with env_var ~default ~fallback () : string =
  match Sys.getenv_opt env_var with
  | Some "" ->
      (* empty env-var == unset; fall through *)
      if Sys.file_exists default then default
      else if Sys.file_exists fallback then fallback
      else default
  | Some p -> p
  | None ->
      if Sys.file_exists default then default
      else if Sys.file_exists fallback then fallback
      else default

(* --- public API --------------------------------------------------- *)

let[@warning "-32"] resolve_decisions_dir () : string =
  resolve_with "MATH_CODING_DECISIONS_DIR" ~default:default_decisions_dir
    ~fallback:legacy_decisions_dir ()

let[@warning "-32"] resolve_attestations_dir () : string =
  resolve_with "MATH_CODING_ATTESTATIONS_DIR" ~default:default_attestations_dir
    ~fallback:legacy_attestations_dir ()

let[@warning "-32"] resolve_policy_path () : string =
  resolve_with "MATH_CODING_POLICY" ~default:default_policy_path
    ~fallback:legacy_policy_path ()
