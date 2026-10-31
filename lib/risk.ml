(* lib/risk.ml — math-coding 3.2-ideal risk function.
 *
 * Implements spec/algebra-3.2.md §2:
 *
 *   risk(c) = impact(c) · probability(c) · irreversibility(c)
 *
 *   impact(c)           = max{classify(p)        : p ∈ c.files}
 *   probability(c)      = 0.5 + 0.5 · policy_override_probability(c)
 *   irreversibility(c)  = max{marker(p)          : p ∈ c.files}
 *   mode(c)             = max(risk_to_mode(risk(c)), mode_floor(c))
 *
 * Pure module: no I/O, no exceptions, safe defaults on empty input.
 *
 * `policy_override_probability` and `mode_floor` are wired to
 * `lib/policy.ml` (per-path policy parsing, union + transitive
 * composition per algebra §9); see decision
 * `risk-policy-driven-floor-2026-10`. Probability is the spec
 * default (0.5) and mode_floor is the policy default
 * (`policies.yaml` at the repo root).
 *
 * Path matching is normalised before prefix comparison:
 *
 *   "./tests/foo.ml"     -> "tests/foo.ml"
 *   "/abs/tests/foo.ml"  -> "abs/tests/foo.ml"
 *   "tests/foo.ml"       -> "tests/foo.ml"
 *
 * so all three classify as 0.0 (tests/...). Without this
 * normalisation the spec's tests/... glob would only fire when
 * `path` is the tests directory itself, missing every file inside
 * it. *)

(* ---------- path normalisation ---------- *)

(* Strip a leading "./" and a leading "/" from `p`. After this
   transform all three forms above reduce to the same prefix. *)
let normalize_path p =
  let n = String.length p in
  let p =
    if n >= 2 && String.unsafe_get p 0 = '.' && String.unsafe_get p 1 = '/' then
      String.sub p 2 (n - 2)
    else p
  in
  let n = String.length p in
  if n >= 1 && String.unsafe_get p 0 = '/' then String.sub p 1 (n - 1) else p

(* True iff `p` starts with `prefix` (after `p` has been
   normalised). O(|prefix|), no allocation. *)
let has_prefix p prefix =
  let pn = String.length p in
  let qn = String.length prefix in
  pn >= qn && String.sub p 0 qn = prefix

(* True iff `needle` appears in `hay` as a complete path segment,
   i.e. bounded by '/' on both sides, or at a string boundary.
   Used for token markers like `data-mig` and `schema-break` that
   are not anchored to the start of the path. *)
let path_contains_segment hay needle =
  let hn = String.length hay in
  let nn = String.length needle in
  let rec loop i =
    if i + nn > hn then false
    else if String.sub hay i nn = needle then
      let left_ok = i = 0 || String.unsafe_get hay (i - 1) = '/' in
      let right_ok = i + nn = hn || String.unsafe_get hay (i + nn) = '/' in
      left_ok && right_ok
    else loop (i + 1)
  in
  loop 0

(* ---------- classify (algebra §2, 12-entry taxonomy) ---------- *)

(* classify: 𝓟 → [0, 1].
   Order matters: more-specific prefixes must be tested before
   less-specific ones (lib/utils at 0.2 before lib/security at 0.8,
   lib/core / bin at 0.5 between them, etc.). *)
let classify path =
  let p = normalize_path path in
  if has_prefix p "tests/" || p = "tests" then 0.0
  else if has_prefix p "docs/" || p = "docs" then 0.05
  else if has_prefix p "site/" || p = "site" then 0.2
  else if has_prefix p "scripts/" || p = "scripts" then 0.3
  else if has_prefix p "schemas/" || p = "schemas" then 0.3
  else if has_prefix p "lib/utils/" then 0.2
  else if has_prefix p "lib/core/" || has_prefix p "bin/" then 0.5
  else if has_prefix p "lib/security/" then 0.8
  else if has_prefix p "axioms/" || p = "axioms" then 0.95
  else if has_prefix p "migrations/" || p = "migrations" then 0.95
  else 0.5

(* ---------- impact ---------- *)

(* impact(c) = max{classify(p) : p ∈ c.files}.
   Empty file list returns 0.5 (the unclassified default); the
   spec's `max` over an empty set has no defined value, and the
   unclassified default is the conservative choice (it does not
   silently drop the commit below the floor). *)
let impact files =
  match files with
  | [] -> 0.5
  | _ -> List.fold_left (fun acc f -> max acc (classify f)) 0.0 files

(* ---------- probability ---------- *)

(* policy_override_probability(c) ∈ [-1, 1] from policies.yaml,
   algebra §2. Default 0 ⇒ probability(c) = 0.5. Backed by
   `Policy.policy_override_of_files` (per decision
   `risk-policy-driven-floor-2026-10`). *)
let policy_override_probability files =
  Policy.policy_override_of_files_cached files

let probability files = 0.5 +. (0.5 *. policy_override_probability files)

(* ---------- irreversibility (algebra §2) ---------- *)

(* Path-level irreversibility marker. Returns the marker value if
   `path` carries an irreversibility annotation, else None.

   The markers are SEGMENT tokens, not this repository's directory
   names: a path segment called `data-mig` is a data migration and a
   segment called `schema-break` is a breaking schema change, whoever
   owns the tree. That is why they stay while the three
   project-specific directory prefixes are gone.

   The three branches that named `migrations/`, `pci/` and
   `payments/` were removed in the 2026-11 tranche (decision
   `risk-and-scaffold-honesty-2026-11`). None of the three
   directories exists in this repository, so no path in the tree
   could ever carry the marker: a branch that cannot fire protects
   nothing, and it made the printed irreversibility look like a
   measure when it was a constant. Their absence changed no mode:
   `risk_to_mode` was already `Tiny` for every input this
   repository can produce (the maximum risk is 0.0475 against a
   first threshold of 0.05), so the mode of every change came from
   the floor `policies.yaml` declares, not from the risk.

   The irreversibility axis is therefore still inert here - the two
   surviving tokens fire on no tracked path either - and the honest
   repair for that is a DECLARED marker vocabulary in
   `policies.yaml`, not more hardcoded paths. *)
let path_marker path =
  let p = normalize_path path in
  if path_contains_segment p "data-mig" then Some 0.7
  else if path_contains_segment p "schema-break" then Some 0.95
  else None

(* irreversibility(c) = max{marker(p) : p ∈ c.files}.
   Empty file list returns 0.1 (the no-marker default). *)
let irreversibility files =
  match files with
  | [] -> 0.1
  | _ -> (
      let markers = List.filter_map path_marker files in
      match markers with [] -> 0.1 | xs -> List.fold_left max 0.0 xs)

(* ---------- mode_floor ---------- *)

(* mode_floor(c) = max{mode_floor(policy(p)) : p ∈ c.files ∪
                       transitive_paths(c)}, algebra §2. Backed by
   `Policy.mode_floor_of_cached` (per decision
   `risk-policy-driven-floor-2026-10`). *)
let mode_floor (files : string list) : Domain.mode =
  Policy.mode_floor_of_cached files

(* ---------- mode arithmetic ---------- *)

(* Mode ordering: Tiny < Light < [Considered == Standard] < Strict < Exhaustive.
   `Considered` carries the same kernel-rules assurance strength
   as `Standard` per `decisions/antithesis-mode-considered-2026-10`,
   so both rank to the same integer. The dialectic `antithesis`
   slot requirement is enforced separately in the validator, not
   in the integer rank. Used only by max_mode. *)
let rank (m : Domain.mode) : int =
  match m with
  | `Tiny -> 0
  | `Light -> 1
  | `Standard | `Considered -> 2
  | `Strict -> 3
  | `Exhaustive -> 4

let max_mode (a : Domain.mode) (b : Domain.mode) : Domain.mode =
  if rank a >= rank b then a else b

(* ---------- risk_to_mode ---------- *)

(* Map risk ∈ [0, 1] to the smallest mode whose bucket covers it.
   The spec writes `⌈risk(c)⌉`; threshold buckets implement the
   same intent directly and produce stable, debuggable boundaries.
   Defaults to Exhaustive at r ≥ 0.90 so a single high-risk file
   cannot silently stay below the strict floor. *)
let risk_to_mode (r : float) : Domain.mode =
  if r < 0.05 then `Tiny
  else if r < 0.20 then `Light
  else if r < 0.60 then `Standard
  else if r < 0.90 then `Strict
  else `Exhaustive

(* ---------- risk ---------- *)

(* risk(c) = impact(c) · probability(c) · irreversibility(c).
   All three factors are in [0, 1] by construction, so risk(c) ∈
   [0, 1]. *)
let risk files =
  let i = impact files in
  let p = probability files in
  let x = irreversibility files in
  i *. p *. x

(* ---------- mode ---------- *)

(* mode(c) = max(risk_to_mode(risk(c)), mode_floor(c)),
   algebra §2. *)
let mode (files : string list) : Domain.mode =
  max_mode (risk_to_mode (risk files)) (mode_floor files)
