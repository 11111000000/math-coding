(* lib/waiver.ml — waiver loader and query.
 *
 * Waivers are first-class math-coding artifacts. A waiver is an
 * explicit, scoped, authorized, expiring acceptance of one
 * AssuranceGap (constitution.md §Waivers; spec/semantics.md §Waiver).
 * The decision is recorded in a `decisions/waivers/*.yaml` file
 * (or `decisions/*.waiver.yaml`) that matches the
 * `math-coding/waiver-3.0-alpha` schema. The kernel parser
 * (Codec.parse_waiver) already understands the format; this
 * module adds:
 *
 *   - load: enumerate and parse all waivers under a root path
 *   - covers: pick the active waiver for a
 *     (subject, obligation, now) triple, bounded by the class the
 *     waiver declares (`rule`), the scope it names, and the one gap
 *     it identifies (`unverified_obligation`)
 *   - retain_covering: narrow a subject's waiver list to the
 *     waivers whose declared class matches the class of the gap
 *     they name
 *   - effective_at: predicate — is the waiver still in effect?
 *
 * The module is pure: load takes a `reader` callback so the
 * caller (bin/Mathc.ml or a test) controls I/O. No Sys.readdir
 * here; that lives in `list_files` below and is the single
 * filesystem touchpoint, mirroring lib/attestations/attestations.ml.
 *
 * Per OCAML_BEST_PRACTICES.md §1.3 the kernel stays offline. The
 * `reader` contract is "empty string means missing or empty";
 * any file that fails to parse is silently dropped (best-effort
 * load — the gate never crashes on a malformed waiver, just
 * reports it as not covering anything). *)

(* Re-export the Domain.waiver type under a local alias so callers
   can refer to the record fields by their domain names. *)
type t = Domain.waiver

(* List waiver files under `root`. A waiver file is any file
   with the .yaml or .yml extension in the immediate directory.
   The root is typically `decisions/waivers/`. We also accept
   `decisions/*.waiver.yaml` (sibling waiver files outside the
   waivers/ subdir) by accepting a second root; for the common
   case the caller passes just one path.

   Single filesystem touchpoint: Sys.readdir. Mirrors
   lib/attestations/attestations.ml:391. Returns [] on a
   non-existent or non-directory path. *)
let[@warning "-32"] list_files root =
  if not (Sys.file_exists root) then []
  else if not (Sys.is_directory root) then []
  else try Sys.readdir root |> Array.to_list with _ -> []

(* Enumerate candidate paths. Two patterns:
   1. root contains .yaml/.yml files directly (root = decisions/waivers/)
   2. root is a directory; we look for *.waiver.yaml AND *.waiver.yml
      alongside the regular decisions (sibling-waiver pattern)

   For the canonical layout (`decisions/waivers/`), pattern 1
   applies. For the sibling layout, the caller would pass a
   different filter; we keep this module simple and accept the
   caller-supplied root as the "all waivers" directory. *)
let[@warning "-32"] waiver_paths ~root =
  let names = list_files root in
  List.filter
    (fun n ->
      let sfx = Filename.extension n in
      sfx = ".yaml" || sfx = ".yml")
    names
  |> List.map (fun n -> Filename.concat root n)

(* Parse a single raw YAML string into a waiver. The kernel
   parser (Codec.parse_waiver) already understands the format;
   this wrapper applies our loader (front-matter stripping,
   block-scalar support) first so the same function works
   across the YAML and JSON forms the conformance corpus uses.
   Returns None on any parse / schema failure.

   Exposed publicly so unit tests can exercise the parser
   without touching the filesystem; `load` calls this in a
   list_map below. *)
let[@warning "-32"] parse raw =
  if raw = "" then None
  else
    let v = Codec.load_yaml_string raw in
    match Codec.parse_waiver v with Some w -> Some w | None -> None

(* Read and parse one file via the caller-supplied reader.
   Empty string -> None. Parse failure -> None. The parser
   (Codec.parse_waiver) returns None for any missing required
   field per schemas/waiver.json. *)
let[@warning "-32"] read_one reader path =
  let raw = reader path in
  parse raw

(* Load every waiver file under `root`. Pure: the `reader`
   callback handles I/O. Returns the empty list when `root`
   does not exist or holds no .yaml/.yml files.

   `root` is the absolute or project-relative path to a single
   directory of waivers. Callers that need the sibling-waiver
   pattern can call `load` twice. *)
let[@warning "-32"] load ~reader ~root =
  match waiver_paths ~root with
  | [] -> []
  | paths -> List.filter_map (fun p -> read_one reader p) paths

(* Time ordering. The schema enforces strict ISO-8601 UTC
   timestamps of identical length (`YYYY-MM-DDTHH:MM:SSZ`,
   20 chars). Under that constraint a plain lexicographic
   compare IS a temporal compare: zero-padding and fixed
   width mean "2026-10-06" < "2026-11-06" both as strings
   and as dates. We avoid a parser dep on mathcoding_attestations
   to keep waiver.ml inside mathcoding_core; correctness is
   guaranteed by the schema's strict regex. *)
let[@warning "-32"] iso_le a b = String.compare a b <= 0
let[@warning "-32"] iso_lt a b = String.compare a b < 0

(* Determine whether a waiver is in effect at the given moment.
   `now` must be a strict-ISO-8601 UTC timestamp as emitted by
   `bin/Mathc.ml:now_iso`.

   The validity interval is half-open on the expiry side:

     issued_at <= now < expires_at

   The upper endpoint is EXCLUSIVE, and it is exclusive because the
   constitution says so, not because of a preference:

     constitution.md Invariant 14c: "a verdict `Open_with_waiver`
     that produces exit 0 MUST reference a waiver whose
     `expires_at` is strictly greater than the evaluation time
     and whose scope covers every gap in the verdict."

   `strictly greater than the evaluation time` is `expires_at >
   now`; an inclusive comparison implements `expires_at >= now`,
   which is a different predicate. The previous code read
   `issued_at <= now <= expires_at` and justified the closed
   interval with constitution.md §Waivers ("MAY permit a gate"),
   which is not a statement about endpoints: it says a waiver MAY
   open a gate, not that it survives its expiry second. Under the
   closed reading a waiver whose `expires_at` equals the evaluation
   time produced `Open_with_waiver` and exit 0 — a green verdict
   held by a waiver the constitution calls expired, which is the
   "MUST NOT outlive its expiry" rule of §Waivers defeated by one
   second of lexicographic comparison.

   The lower endpoint stays INCLUSIVE. No normative text requires
   `issued_at < now`: Invariant 14c constrains only `expires_at`,
   and §Waivers requires the issue time to be identified, not to
   be exclusive. Note the asymmetry is deliberate, and it mirrors
   attestation currency (spec/kernel-contract.md §14, `current(a) ≔
   a.issued_at ≤ now ≤ a.valid_until`, closed on both ends): a
   waiver is an interval whose START is a grant and whose END is a
   deadline. Do not "harmonise" the two by closing the waiver
   interval; §14 governs attestations, Invariant 14c governs
   waivers, and the two documents say different things on purpose.

   Consequence of the strict bound, stated so it is not a
   surprise: a waiver is effective on `[issued_at, expires_at)`
   — 24h to the second for a hotfix waiver, minus the single
   expiry second. A waiver with `expires_at == issued_at` is
   therefore never effective, which is the correct reading of "a
   waiver MUST NOT outlive its expiry". *)
let[@warning "-32"] effective_at w ~now =
  iso_le w.Domain.issued_at now && iso_lt now w.Domain.expires_at

(* --- gap classes ------------------------------------------------------- *)
(* The class of an AssuranceGap is what a waiver declares in its
   `rule` field (schemas/waiver.json). The vocabulary lives HERE, in
   the module that owns the waiver contract, because `lib/gate.ml`
   depends on this module and this module must not depend on it: the
   gate's gap kind is mapped onto these three classes by the caller
   (bin/Mathc.ml), which is the only place that sees both.

   The three classes are exactly the three waivable gap kinds of
   lib/gate.ml (`MissingEvidence`, `StaleEvidence`, `Unknown`). A
   decisive failure and a missing required review are NOT classes
   here: constitution.md §Waivers says a waiver "MUST NOT convert
   `fail`, `unknown` or `missing` into `pass`", and the gate already
   refuses to waive a `FailedEvidence` gap. A waiver that names any
   other class — or no class the kernel can read — names no gap the
   kernel can check, and covers nothing. *)

type gap_class = Missing_evidence | Stale_evidence | Inconclusive_evidence

let[@warning "-32"] rule_of_class : gap_class -> string = function
  | Missing_evidence -> "obligation-missing-attestation"
  | Stale_evidence -> "obligation-stale-attestation"
  | Inconclusive_evidence -> "obligation-inconclusive-attestation"

let[@warning "-32"] class_of_rule : string -> gap_class option = function
  | "obligation-missing-attestation" -> Some Missing_evidence
  | "obligation-stale-attestation" -> Some Stale_evidence
  | "obligation-inconclusive-attestation" -> Some Inconclusive_evidence
  | _ -> None

(* --- scope ------------------------------------------------------------- *)
(* The subject's scope is the set of paths its decision governs
   (`scope.paths`, carried by lib/memory.ml::decision_entry). A
   waiver's scope must stay INSIDE it: a waiver that claims a path
   the decision does not govern is accepting a gap that is not the
   decision's gap. `Policy.path_matches` is the kernel's own glob
   matcher for `scope.paths` ("does this scope pattern cover this
   path"), used here in the direction the decision declares and the
   waiver claims.

   A `capability` or `interface` scope target cannot be checked
   against the subject's paths, and the decision entry the kernel
   carries does not name the subject's capabilities. A waiver that
   declares one is therefore NOT applied: the kernel does not grant
   relief it cannot bound. (Follow-up: carry the subject's
   capabilities in the memory entry, then the check becomes
   decidable. Recorded in decisions/exit-honesty-waivers-2026-10.) *)

let[@warning "-32"] path_target_covered ~subject_paths ~path ~match_ =
  List.exists
    (fun s ->
      match match_ with
      | `Exact -> Policy.path_matches s path
      | `Tree ->
          (* The waiver claims the whole tree rooted at `path`; the
             subject covers it when one of its scope paths covers
             that path or names something inside that tree. *)
          Policy.path_matches s path
          || String.length s >= String.length path
             && String.sub s 0 (String.length path) = path)
    subject_paths

let[@warning "-32"] scope_within ?subject_paths (w : Domain.waiver) =
  match w.Domain.scope with
  | [] ->
      (* No scope declared. `scope` is OPTIONAL in schemas/waiver.json,
         so an absent scope is not a lie about the subject: it is the
         absence of a path restriction. The waiver's remaining bounds
         — the named obligation, the declared class, the validity
         interval — still apply. *)
      true
  | targets -> (
      match subject_paths with
      | None ->
          (* The caller did not determine the subject's scope; the
             scope check cannot be made here. *)
          true
      | Some paths ->
          List.for_all
            (fun (t : Domain.scope_target) ->
              match t with
              | Domain.PathTarget { path; match_ } ->
                  path_target_covered ~subject_paths:paths ~path ~match_
              | Domain.CapabilityTarget _ | Domain.InterfaceTarget _ -> false)
            targets)

(* --- the predicate ----------------------------------------------------- *)
(* A waiver names the gap it accepts. constitution.md §Waivers: "A
   waiver ... MUST identify one gap". A waiver whose
   `unverified_obligation` is absent names NO gap, and a waiver that
   names no gap covers nothing.

   The legacy form — a waiver without `unverified_obligation`
   covering every obligation of its decision — was a backward
   compatibility shim (decisions/plan-2026-10-improvements/t3-2.yaml)
   for waivers whose YAML front-matter expressed the field as a LIST.
   The schema declares the field a STRING, so the parser read those
   files as naming nothing, and the shim made each of them accept
   every obligation of its decision: 8 waivers, 37 gaps, one named
   gap each (measured; see decisions/exit-honesty-waivers-2026-10).
   The shim is revoked here; the migration is in that decision. *)

let[@warning "-32"] names_gap (w : Domain.waiver) ~obligation_id =
  match w.Domain.unverified_obligation with
  | Some obl_id -> String.equal obl_id obligation_id
  | None -> false

(* The declared class must match the class of the gap. `gap_class` is
   the class of the gap the caller asks about; a caller that does not
   determine it (the gate's pure aggregation) gets the "the rule
   names a class the kernel can read" half of the check only, and the
   caller that DOES determine it gets the whole check. *)

let[@warning "-32"] declares_class ?gap_class (w : Domain.waiver) =
  match class_of_rule w.Domain.rule with
  | None -> false
  | Some declared -> (
      match gap_class with None -> true | Some c -> declared = c)

(* Find a waiver that covers the given (decision, obligation) pair at
   the given moment, and covers a gap of the given class within the
   subject's scope.

   The four bounds, all of them required:

     - subject: the waiver's `subject` is the decision that owns the
       gap;
     - interval: `effective_at w ~now` (issued_at <= now < expires_at);
     - the named gap: the waiver names THIS obligation
       (`names_gap`);
     - the declared class and scope: `declares_class` and
       `scope_within`.

   Returns the first matching waiver; the kernel does not require
   the most-recent or most-specific — any one covering the
   (subject, obligation) pair is sufficient for the
   open-with-waiver disposition (constitution.md §Waivers).
   Returns None when no waiver matches.

   The explicit `(w : Domain.waiver)` annotation disambiguates
   `w.Domain.subject` from `Domain.gap.subject` and
   `Domain.diagnostic.subject`, both of which have type
   `id option`. Without the annotation OCaml's structural
   row polymorphism picks the wrong one (OCAML_BEST_PRACTICES
   §11.18). *)
let[@warning "-32"] covers ?gap_class ?subject_paths waivers ~decision_id
    ~obligation_id ~now =
  List.find_opt
    (fun (w : Domain.waiver) ->
      String.equal w.Domain.subject decision_id
      && effective_at w ~now && names_gap w ~obligation_id
      && declares_class ?gap_class w
      && scope_within ?subject_paths w)
    waivers

(* Keep the waivers of ONE subject that may cover the gaps of that
   subject, given the class of each of its gaps.

   `gaps` is the `(obligation_id, gap_class)` list of the subject's
   gaps; a waiver whose named obligation is not among them, or whose
   declared class differs from the class of that obligation's gap, is
   dropped. What survives is what the aggregation that follows may
   apply.

   This is the class check in the form the CLI needs it: the gap's
   class is a RUNTIME property of the (decision, obligation) pair —
   it is read out of the attestation store — so it is known where the
   gaps are computed, and not inside the pure aggregation that
   consults the waivers. *)
let[@warning "-32"] retain_covering (waivers : t list)
    ~(gaps : (string * gap_class) list) ~subject_paths ~decision_id ~now =
  List.filter
    (fun (w : Domain.waiver) ->
      match w.Domain.unverified_obligation with
      | None -> false
      | Some obl_id -> (
          match List.assoc_opt obl_id gaps with
          | None -> false
          | Some c ->
              Option.is_some
                (covers [ w ] ~gap_class:c ~subject_paths ~decision_id
                   ~obligation_id:obl_id ~now)))
    waivers
