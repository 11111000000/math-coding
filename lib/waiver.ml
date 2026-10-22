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
 *     (subject, obligation, now) triple; strict matching when the
 *     waiver carries `unverified_obligation`, legacy global coverage
 *     when the field is absent
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
   attestation currency (spec/algebra-3.2.md §14, `current(a) ≔
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

(* Find a waiver that covers the given (decision, obligation)
   pair at the given moment. Strict matching when the waiver
   carries an `unverified_obligation`; legacy global coverage
   when the waiver omits that field.

   Returns the first matching waiver; the kernel does not require
   the most-recent or most-specific — any one covering the
   (subject, obligation) pair is sufficient for the
   open-with-waiver disposition (constitution.md §Waivers).
   Returns None when no waiver matches.

   Strict matching rule (constitution.md §Self-application
   item 11 "Waiver bounds: a waiver MUST apply only to its
   named gap, scope" and spec/semantics.md §Waiver language
   on "named obligation"):

     - When `unverified_obligation = Some obl_id`, the waiver
       covers ONLY the gap whose `(decision, obligation)` pair
       equals `(w.subject, obl_id)`. A waiver named for
       obligation A of decision D does NOT cover obligation B
       of decision D, nor any obligation of decision E.

     - When `unverified_obligation = None`, the waiver covers
       EVERY obligation of its named decision (legacy global
       behaviour). This preserves backward compatibility with
       pre-existing waivers in `decisions/waivers/*.yaml` that
       ship without `unverified_obligation` (the YAML front-
       matter expresses it as a list; the JSON parser returns
       None for non-scalar values, so the kernel reads these
       as global).

   The explicit `(w : Domain.waiver)` annotation disambiguates
   `w.Domain.subject` from `Domain.gap.subject` and
   `Domain.diagnostic.subject`, both of which have type
   `id option`. Without the annotation OCaml's structural
   row polymorphism picks the wrong one (OCAML_BEST_PRACTICES
   §11.18). *)
let[@warning "-32"] covers waivers ~decision_id ~obligation_id ~now =
  List.find_opt
    (fun (w : Domain.waiver) ->
      String.equal w.Domain.subject decision_id
      && effective_at w ~now
      &&
      match w.Domain.unverified_obligation with
      | None -> true
      | Some obl_id -> String.equal obl_id obligation_id)
    waivers
