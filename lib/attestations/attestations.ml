(* lib/attestations/attestations.ml — filesystem-backed attestation
 * store for the kernel gate evaluator + 3.2-ideal algebra
 * extensions for substrate fingerprinting and multi-CI
 * aggregation (algebra §13, §14).
 *
 * The store loader walks a directory of JSON files matching
 * `schemas/attestation.json` (or its current incarnation) and
 * returns the typed list. Malformed files are skipped (the
 * kernel never crashes on a malformed store entry).
 *
 * Pure-data interface: `Attestations.load` takes a `reader`
 * callback (path -> string) and a `root` (the directory path). It
 * performs no I/O at module top level. The CLI is the only caller
 * of `Sys.readdir`; in tests, `reader` can be a fake.
 *
 * Rule (OCAML_BEST_PRACTICES §1.3): no `Printf.printf`, no
 * `Unix.*` in the loader. The clock helpers
 * (`parse_iso8601_to_float`, `current_at`) touch `Unix.time`
 * and the SHA helpers touch `Digest`, both pulled from the
 * mathcoding_core library; they live next to the public
 * algebra helpers and are not used inside the loader itself.
 *
 * Rule (OCAML_BEST_PRACTICES §10.1): adapters live in their own
 * subdirectory with their own dune. The kernel
 * (`lib/mathcoding_core`) is unchanged. The kernel gate evaluator
 * (`lib/gate.ml`) consumes the typed `Domain.attestation list`
 * directly; the filtering helpers live in the kernel, not here.
 *
 * Pure type:
 *   type attestation = Domain.attestation
 *   type t = attestation list
 *
 *   val load : reader:(string -> string) -> root:string -> t
 *
 * 3.2-ideal algebra additions (algebra §13, §14):
 *   - compute_substrate_digest / compute_substrate_fingerprint
 *   - parse_environment_class_level / parse_environment_class_label
 *   - parse_iso8601_to_float
 *   - current_at / decisive_for
 *   - ci_aggregation type and aggregate_obligation
 *   - obligation_result
 *   - attestations_by_ci / blocking_cis_default
 *)

type attestation = Domain.attestation
type t = attestation list

(* -----------------------------------------------------------------
 * Substrate fingerprint (algebra §13, §16).
 *
 *   substrate_digest = sha256(kernel.ver || ocaml.ver || dep.digests)
 *   substrate_fingerprint = 𝓢.id, a human-readable identifier
 *                           built from dependency names.
 *
 * The substrate fingerprint is consumed by the gate evaluator
 * to decide whether two attestations are comparable (algebra §14).
 * Both helpers are pure: they take pre-composed inputs and
 * return deterministic strings. *)

(* -------------------------------------------------------------------------
 * Compute substrate digest per algebra §13.
 *
 * Input: combined string of (kernel.ver || ocaml.ver || dep.digests).
 * Output: hex SHA-256 of the combined string.
 *
 * Pure helper. Delegates to `Digest.sha256_hex` from
 * mathcoding_core; the underlying implementation is RFC 6234
 * (lib/digest.ml). *)
let compute_substrate_digest combined = Digest.sha256_hex combined

(* -------------------------------------------------------------------------
 * Compute substrate fingerprint id per algebra §13.
 *
 * Input: list of dependency names (e.g. ["ocaml-5.5"; "dune-3.23"]).
 * Output: human-readable id, names joined with "+".
 *
 * Pure helper. Used by attestation producers to declare the
 * substrate an attestation was produced against. *)
let compute_substrate_fingerprint deps = String.concat "+" deps

(* -----------------------------------------------------------------
 * Environment-class parsers (algebra §13).
 *
 * Per the schema (`schemas/common.json#/definitions/...`):
 *   environment_class_level : integer 0..4
 *   environment_class_label : "dev" | "staging"
 *                           | "staging-integration"
 *                           | "prod-mirror" | "prod"
 *
 * These take a `Jsonl.value` (e.g. the value at the
 * `environment_class_level` or `environment_class_label` key)
 * and return the typed option. Out-of-range or malformed values
 * map to None; the kernel never crashes on a malformed
 * attestation. *)

(* -------------------------------------------------------------------------
 * Parse environment_class_level from a JSON value.
 *
 * Accepts JSON integers in [0, 4]. Returns `None` for any other
 * shape (string, float, object, out-of-range int). *)
let[@warning "-32"] parse_environment_class_level v =
  match v with Jsonl.Int i when i >= 0 && i <= 4 -> Some i | _ -> None

(* -------------------------------------------------------------------------
 * Parse environment_class_label from a JSON value.
 *
 * Accepts JSON strings matching the enum; returns the matching
 * polymorphic variant. *)
let[@warning "-32"] parse_environment_class_label v =
  match v with
  | Jsonl.String s -> (
      match s with
      | "dev" -> Some `Dev
      | "staging" -> Some `Staging
      | "staging-integration" -> Some `StagingIntegration
      | "prod-mirror" -> Some `ProdMirror
      | "prod" -> Some `Prod
      | _ -> None)
  | _ -> None

(* -----------------------------------------------------------------
 * ISO-8601 timestamp parsing (algebra §14).
 *
 * Per `schemas/common.json#/definitions/timestamp`:
 *   "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
 *
 * We accept the strict UTC form (suffix 'Z'). Anything else
 * maps to None; the kernel never crashes on a malformed
 * timestamp. *)

(* -------------------------------------------------------------------------
 * Days-from-civil (Howard Hinnant, public domain).
 *
 * Returns the number of days from 1970-01-01 (UNIX epoch) to the
 * given civil date. Used by `parse_iso8601_to_float` to compute
 * seconds-since-epoch without depending on the local timezone
 * or `Unix.timegm` (which is not exposed by the OCaml stdlib).
 *
 * Reference:
 *   http://howardhinnant.github.io/date_algorithms.html#days_from_civil *)
let[@warning "-32"] days_from_civil y m d =
  let y = if m <= 2 then y - 1 else y in
  let era = if y >= 0 then y / 400 else (y - 399) / 400 in
  let yoe = y - (era * 400) in
  let m_prime = if m > 2 then m - 3 else m + 9 in
  let doy = (((153 * m_prime) + 2) / 5) + d - 1 in
  let doe = (yoe * 365) + (yoe / 4) - (yoe / 100) + doy in
  (era * 146097) + doe - 719468

(* -------------------------------------------------------------------------
 * Parse a strict ISO-8601 UTC timestamp to seconds-since-epoch.
 *
 * Accepts "YYYY-MM-DDTHH:MM:SSZ" (length 20). Returns None on
 * length mismatch or any parse error. The returned float is
 * the wall-clock instant in UTC; compare against
 * `Unix.time ()` to decide whether an attestation is current. *)
let[@warning "-32"] parse_iso8601_to_float s =
  let len = String.length s in
  if len < 20 then None
  else
    try
      let year = int_of_string (String.sub s 0 4) in
      let month = int_of_string (String.sub s 5 2) in
      let day = int_of_string (String.sub s 8 2) in
      let hour = int_of_string (String.sub s 11 2) in
      let minute = int_of_string (String.sub s 14 2) in
      let second = int_of_string (String.sub s 17 2) in
      let days = days_from_civil year month day in
      let secs = (days * 86400) + (hour * 3600) + (minute * 60) + second in
      Some (Float.of_int secs)
    with _ -> None

(* -----------------------------------------------------------------
 * Multi-CI aggregation (algebra §14).
 *
 *   current(a)    ≔ a.issued_at ≤ now ≤ a.valid_until
 *   decisive(a,p) ≔ a.environment_class_level ≥ p.decisive_threshold(ob)
 *
 *   result(ob) =
 *     | Pass          if ∀ a ∈ attestations(c) with ob:
 *                        a.result = Pass ∧ current(a)
 *     | Fail          if ∃ a ∈ attestations(c) with ob:
 *                        a.result = Fail ∧ decisive(a)
 *     | Inconclusive  otherwise
 *
 * The four-variant `ci_aggregation` type exposes the gate's
 * intermediate classification. `obligation_result` collapses it
 * back to the three algebra-level results (Pass | Fail | Inconclusive).
 *
 * `Still_running` distinguishes the "some CIs haven't reported
 * yet" case from a flat Inconclusive: at least one current
 * attestation is `Inconclusive`, but no current decisive failure
 * has arrived. *)

(* -------------------------------------------------------------------------
 * Four-state multi-CI aggregation verdict for a single obligation.
 *
 *   All_blocking_passed : every blocking CI is current and reports Pass
 *   Some_blocking_failed: at least one blocking CI is current,
 *                         decisive, and reports Fail
 *   Still_running       : at least one current Inconclusive, no
 *                         current decisive failure, not all-pass
 *   Inconclusive        : no current decisive failure, no current
 *                         Inconclusive, but not all-pass either
 *                         (e.g. all-decisive-fail-passed, all
 *                         stale, or empty after non-vacuous cases) *)
type ci_aggregation =
  | All_blocking_passed
  | Some_blocking_failed
  | Still_running
  | Inconclusive

(* -------------------------------------------------------------------------
 * current(a, now) per algebra §14.
 *
 * Returns true iff `issued_at <= now` and `now <= valid_until`.
 * A missing `valid_until` is treated as +infinity: an attestation
 * without an explicit expiry is current forever. The function is
 * total: it never raises on a malformed timestamp; `parse_iso8601_to_float`
 * returns None for those and `current_at` then returns false
 * (the "absence is not Pass" principle from §0). *)
let[@warning "-32"] current_at (a : Domain.attestation) now =
  let issued = parse_iso8601_to_float a.issued_at in
  let valid_until =
    match a.valid_until with
    | None -> infinity
    | Some s -> (
        match parse_iso8601_to_float s with Some t -> t | None -> neg_infinity)
  in
  match issued with None -> false | Some i -> i <= now && now <= valid_until

(* -------------------------------------------------------------------------
 * decisive(a, threshold) per algebra §14.
 *
 * Returns true iff `a.environment_class_level >= threshold`.
 * An attestation without a recorded environment_class_level
 * is treated as non-decisive (returns false): absence is not
 * decisive, per the honest-uncertainty principle (§0). *)
let[@warning "-32"] decisive_for (a : Domain.attestation) threshold =
  match a.environment_class_level with
  | Some lvl -> lvl >= threshold
  | None -> false

(* -------------------------------------------------------------------------
 * aggregate_obligation : list of attestations for an obligation ->
 *                       four-state ci_aggregation.
 *
 * Per algebra §14:
 *   - All_blocking_passed iff every attestation is current and Pass.
 *   - Some_blocking_failed iff not all-pass and at least one
 *     attestation is current, Fail, and decisive.
 *   - Still_running iff not all-pass and not some-blocking-failed,
 *     but at least one current attestation is Inconclusive.
 *   - Inconclusive otherwise (non-decisive Fail, stale passes,
 *     mixed inconclusive-and-fail, etc.). *)
let[@warning "-32"] aggregate_obligation
    (attestations : Domain.attestation list) threshold =
  let now = Unix.time () in
  let all_pass =
    List.for_all
      (fun (a : Domain.attestation) ->
        a.result = Domain.Pass && current_at a now)
      attestations
  in
  if all_pass then All_blocking_passed
  else
    let any_decisive_fail =
      List.exists
        (fun (a : Domain.attestation) ->
          a.result = Domain.Fail && decisive_for a threshold)
        attestations
    in
    if any_decisive_fail then Some_blocking_failed
    else
      let any_current_pending =
        List.exists
          (fun (a : Domain.attestation) ->
            a.result = Domain.Inconclusive && current_at a now)
          attestations
      in
      if any_current_pending then Still_running else Inconclusive

(* -------------------------------------------------------------------------
 * obligation_result : collapse ci_aggregation to Domain.result.
 *
 * Maps All_blocking_passed -> Pass, Some_blocking_failed -> Fail,
 * and both Still_running and Inconclusive -> Inconclusive. *)
let[@warning "-32"] obligation_result attestations threshold =
  match aggregate_obligation attestations threshold with
  | All_blocking_passed -> Domain.Pass
  | Some_blocking_failed -> Domain.Fail
  | Still_running -> Domain.Inconclusive
  | Inconclusive -> Domain.Inconclusive

(* -------------------------------------------------------------------------
 * attestations_by_ci : per-CI accessor.
 *
 * Returns the subset of attestations whose `producer_identity`
 * contains the given ci name as a substring. The producer
 * identity encodes the CI: "ci:<kind>:<name>" (e.g.
 * "ci:fixture:cli-gate"), and substring matching lets callers
 * filter by either kind or name.
 *
 * This is the accessor the gate uses to compute per-CI
 * sub-results before aggregating across the blocking set. *)
let[@warning "-32"] string_contains s sub =
  let slen = String.length s in
  let nlen = String.length sub in
  if nlen = 0 then true
  else if nlen > slen then false
  else
    let[@warning "-32"] rec loop i =
      if i + nlen > slen then false
      else
        let rec eq j =
          if j >= nlen then true
          else if String.unsafe_get s (i + j) = String.unsafe_get sub j then
            eq (j + 1)
          else false
        in
        if eq 0 then true else loop (i + 1)
    in
    loop 0

let[@warning "-32"] attestations_by_ci attestations ci_name =
  List.filter
    (fun a -> string_contains a.Domain.producer_identity ci_name)
    attestations

(* -------------------------------------------------------------------------
 * Default list of blocking CIs.
 *
 * The kernel waits for all blocking CIs by default (algebra §14
 * default). For the math-coding CI farm this list is
 * "payments-ci", "orders-ci", and "integration-ci". Custom
 * projects override this via `decisions/*.yaml` policy rows;
 * the default is the fallback when no policy is declared. *)
let[@warning "-32"] blocking_cis_default =
  [ "payments-ci"; "orders-ci"; "integration-ci" ]

(* -----------------------------------------------------------------
 * Store loader (existing code, unchanged). *)

let[@warning "-32"] empty = []

(* Read a single file via the caller-supplied reader. The reader
 * contract: empty string means "missing or empty". We return None
 * for that and for parse/decode failures, never raise. *)
let[@warning "-32"] read_one reader path =
  let raw = reader path in
  if raw = "" then None
  else
    try
      match Jsonl.parse raw with
      | v -> (
          match Codec.parse_attestation v with Some a -> Some a | None -> None)
    with Jsonl.Parse_error _ -> None

(* Enumerate the files at `root`. Returns [] when the directory
 * does not exist. The caller passes the relative path; we attempt
 * to list it directly. Files without the .json extension are
 * ignored. The "files" returned by this helper are bare names;
 * the caller composes the full path with `root`.
 *
 * This is the one place that touches the filesystem via
 * `Sys.readdir`. It is invoked from `load` (the boundary). *)
let[@warning "-32"] list_files root =
  if not (Sys.file_exists root) then []
  else if not (Sys.is_directory root) then []
  else
    try
      let entries = Sys.readdir root in
      Array.to_list entries
    with _ -> []

let[@warning "-32"] load ~reader ~root =
  match list_files root with
  | [] -> []
  | files ->
      List.filter_map
        (fun name ->
          let sfx = Filename.extension name in
          if sfx = ".json" then
            let path = Filename.concat root name in
            read_one reader path
          else None)
        files
