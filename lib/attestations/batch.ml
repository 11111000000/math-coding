(* lib/attestations/batch.ml — pure logic for `mathc attest-batch`.
 *
 * The CLI subcommand `attest-batch` reads a TSV manifest
 * (`decision_id<TAB>obligation_id<TAB>kind_<TAB>producer_identity[<TAB>result]`)
 * or walks `decisions/` for every obligation, and emits one attestation
 * JSON per row into `MATH_CODING_ATTESTATIONS_DIR` (default
 * `.math-coding/attestations/`).
 *
 * The output schema mirrors `scripts/generate-attestations.py` (the
 * math-coding source-repo bootstrap script) byte-for-byte at the
 * digest boundary. The file-level key order is sorted alphabetically
 * (per `Jsonl.stringify`'s `Object` branch in `lib/jsonl.ml:262-271`),
 * which differs from the Python script's insertion-order emission;
 * this difference is irrelevant because the loader
 * (`lib/attestations/attestations.ml::read_one`) parses the file
 * with `Jsonl.parse` and the parsed `Jsonl.value` is order-agnostic.
 * What MUST match the Python script is the canonical JSON used as
 * SHA-256 input: `sort_keys=True, separators=(",", ":"),
 * ensure_ascii=False` (AGENTS.md / source-map line 280-282).
 *
 * Pure functions exposed to the CLI (no I/O here):
 *   parse_manifest : string -> (row list, parse_error) result
 *   make_attestation : decision:string -> obligation:string ->
 *                      kind_:string -> producer:string ->
 *                      result:string -> issued_at:string ->
 *                      candidate_tree:string -> materials_digest:string ->
 *                      Jsonl.value
 *   compute_id : Jsonl.value -> string
 *   with_id : Jsonl.value -> Jsonl.value
 *   serialize : Jsonl.value -> string
 *   filename_for : decision:string -> obligation:string -> string
 *   scan_decisions_for_obligations : reader:(string -> string) ->
 *                                    root:string ->
 *                                    (decision_id * obligation_id) list
 *
 * I/O lives in `bin/Mathc.ml::do_attest_batch` (mkdir -p, file
 * write, stdout/stderr). The module is pure: it can be unit-tested
 * via `dune test` without touching the disk. *)

(* ----------------------------------------------------------------------------
 * Manifest row: 4 required fields + 1 optional.
 *   (decision_id, obligation_id, kind_, producer_identity, result)
 * The result defaults to "pass" when the 5th column is absent.
 *)
type row = {
  decision : string;
  obligation : string;
  kind_ : string;
  producer : string;
  result : string;
}

(* Parse error: 1-based line number, offending line, reason.
   Surfaced to the user verbatim so they can fix and re-run. *)
type parse_error = { line : int; raw : string; reason : string }

(* Trim leading/trailing ASCII whitespace. TABs are kept (TSV uses
   TABs as separators, not as content). *)
let[@warning "-32"] trim_ws s =
  let len = String.length s in
  let rec left i =
    if i >= len then i
    else match s.[i] with ' ' | '\r' -> left (i + 1) | _ -> i
  in
  let rec right j =
    if j <= 0 then j
    else match s.[j - 1] with ' ' | '\r' -> right (j - 1) | _ -> j
  in
  let l = left 0 in
  let r = right len in
  if l >= r then "" else String.sub s l (r - l)

(* Split a string on TAB characters. Empty fields are kept
   (`a\t\tb` is 3 fields: "a", "", "b"). *)
let[@warning "-32"] split_tsv line =
  let len = String.length line in
  let buf = Buffer.create 16 in
  let flush acc =
    let s = Buffer.contents buf in
    Buffer.clear buf;
    s :: acc
  in
  let rec loop i acc =
    if i >= len then List.rev (flush acc)
    else if line.[i] = '\t' then
      let acc = flush acc in
      loop (i + 1) acc
    else begin
      Buffer.add_char buf line.[i];
      loop (i + 1) acc
    end
  in
  loop 0 []

(* The attestation schema's `kind_` enum
   (schemas/attestation.json:30). Checked here so a typo is a named
   parse error at the manifest boundary rather than a file the store
   will reject later. Decision `kernel-fixes-found-bugs-2026-10@1`. *)
let[@warning "-32"] valid_kinds =
  [ "test"; "review"; "build"; "analysis"; "observation" ]

(* Column names as documented in SKILL.md and USAGE.md. A manifest
   pasted out of a Markdown table carries its header; parsing it as
   data produced an attestation naming a decision `decision_id`
   (file `decision_id-obligation_id.json`) — garbage that silently
   lands in the store. A row whose first four fields are these names
   is a header and is skipped. *)
let[@warning "-32"] header_names =
  [ "decision_id"; "obligation_id"; "kind_"; "producer_identity" ]

let[@warning "-32"] lower_ascii s = String.lowercase_ascii (trim_ws s)

(* Parse one manifest line. The 5th column is optional; when present
   we accept it as-is (the kernel's attestation schema validates
   the enum; we don't pre-empt that). *)
let[@warning "-32"] parse_row raw =
  let fields = split_tsv raw in
  match fields with
  | [ d; o; k; p ] ->
      Ok
        {
          decision = d;
          obligation = o;
          kind_ = k;
          producer = p;
          result = "pass";
        }
  | [ d; o; k; p; r ] ->
      Ok { decision = d; obligation = o; kind_ = k; producer = p; result = r }
  | _ ->
      Error
        (Printf.sprintf "expected 4 or 5 TAB-separated fields, got %d"
           (List.length fields))

(* Header detection: `decision_id<TAB>obligation_id<TAB>kind_[TAB]producer_identity...` *)
let[@warning "-32"] is_header_row fields =
  match fields with
  | f0 :: f1 :: f2 :: f3 :: _ ->
      List.for_all2
        (fun got want -> lower_ascii got = want)
        [ f0; f1; f2; f3 ] header_names
  | _ -> false

(* Full validation of a parsed row: `kind_` must be in the schema
   enum, `result` must be pass|fail. Returned as a parse error so the
   CLI reports path, line number, and reason. *)
let[@warning "-32"] validate_row (row : row) : (row, string) result =
  if not (List.mem row.kind_ valid_kinds) then
    Error
      (Printf.sprintf "kind_ must be one of %s (got %s)"
         (String.concat "|" valid_kinds)
         row.kind_)
  else if row.result <> "pass" && row.result <> "fail" then
    Error (Printf.sprintf "result must be 'pass' or 'fail' (got %s)" row.result)
  else Ok row

(* Parse a full manifest body. Blank lines and lines starting with
   `#` are skipped, as is a header row (see `is_header_row`). The
   first malformed or invalid line produces an `Error` so the CLI
   can `exit 2` with a precise diagnostic; the batch-mode UX is to
   refuse rather than silently produce a partial set (the Python
   script's "skip malformed" rule is a bootstrap convenience that we
   replace with a stricter, named error here). *)
let[@warning "-32"] parse_manifest body =
  let lines = String.split_on_char '\n' body in
  let n = List.length lines in
  let arr = Array.of_list lines in
  let rec loop i acc =
    if i >= n then Ok (List.rev acc)
    else
      let raw = arr.(i) in
      let stripped = trim_ws raw in
      if stripped = "" || String.starts_with stripped ~prefix:"#" then
        loop (i + 1) acc
      else
        let fields = split_tsv raw in
        if is_header_row fields then loop (i + 1) acc
        else
          match parse_row raw with
          | Error reason -> Error { line = i + 1; raw; reason }
          | Ok row -> (
              match validate_row row with
              | Error reason -> Error { line = i + 1; raw; reason }
              | Ok row -> loop (i + 1) (row :: acc))
  in
  loop 0 []

(* Build the attestation body WITHOUT the `id` field. The keys are
   the same set as `scripts/generate-attestations.py::make_attestation`
   (8 entries, "schema" ... "issued_at"). Insertion order is
   irrelevant because `serialize` sorts them. *)
let[@warning "-32"] make_attestation ~evidence_digest ~decision ~obligation
    ~kind_ ~producer ~result ~issued_at ~candidate_tree ~materials_digest =
  (* `materials_digest` is the digest of the CONTENT of the files the
     decision's scope names (semantics A) — the same value the gate
     computes as its reference, so the two can actually be compared.
     It is "" only for a human review, which the attestation schema
     permits: an empty digest is legal exactly for {kind_: review}
     ("a human declaration without a runtime anchor"). For {test,
     build, observation, analysis} the schema requires it non-empty,
     and emitting a runtime kind with an empty digest is what
     MC-MATERIALS-DIGEST-EMPTY blocks at the gate.

     `evidence_digest` is a different thing and lives at the top
     level: it is the digest of what a `--run` command actually
     produced. Before semantics A the two were conflated — the run
     output digest was written into `materials_digest`, where the
     gate compared it against a digest of changed PATH NAMES. The
     two could never be equal, so the only attestation the freshness
     check ever accepted was the one carrying no evidence at all. *)
  let base =
    [
      ("schema", Jsonl.String "math-coding/attestation-3.3");
      ("kind", Jsonl.String "attestation");
      ( "subject",
        Jsonl.Object
          [
            ("decision", Jsonl.String decision);
            ("obligation", Jsonl.String obligation);
            ("candidate_tree", Jsonl.String candidate_tree);
            ("materials_digest", Jsonl.String materials_digest);
          ] );
      ("kind_", Jsonl.String kind_);
      ("producer", Jsonl.Object [ ("identity", Jsonl.String producer) ]);
      ("result", Jsonl.String result);
      ("issued_at", Jsonl.String issued_at);
    ]
  in
  match evidence_digest with
  | "" -> Jsonl.Object base
  | ed -> Jsonl.Object (("evidence_digest", Jsonl.String ed) :: base)

(* Serialize a Jsonl.value as canonical JSON. `Jsonl.stringify` in
   `lib/jsonl.ml:250-271` already does:
   - sorted keys for Object (alphabetic order)
   - no whitespace (comma + colon without spaces)
   - `Canonical.canonicalize_string` for strings, which escapes
     the JSON control chars but NOT non-ASCII characters
     (`lib/canonical.ml:3-25`). That matches Python's
     `json.dumps(..., ensure_ascii=False)`.
   Float rendering uses `%.17g` (Jsonl.stringify line 259), which
   differs from Python's repr for some values; the v3.3 attestation
   payload contains no floats so this is moot in practice. *)
let serialize v = Jsonl.stringify v

(* Compute `id` over the canonical JSON of `body` (no `id` field).
   Returns `"sha256:" + 64 lowercase hex digits`. The Python
   upstream applies the same rule: strip `id`, serialize, hash,
   prefix. *)
let compute_id body =
  let payload = serialize body in
  let hex = Digest.sha256_hex payload in
  "sha256:" ^ hex

(* Add the `id` field (computed by `compute_id`) to a body. The
   returned value is the full attestation ready for `serialize`. *)
let[@warning "-32"] with_id body =
  let id = compute_id body in
  match body with
  | Jsonl.Object ps -> Jsonl.Object (ps @ [ ("id", Jsonl.String id) ])
  | _ -> Jsonl.Object [ ("id", Jsonl.String id) ]

(* Filename: `<decision>-<obligation>.json`. Matches
   `scripts/generate-attestations.py::emit`. *)
let filename_for ~decision ~obligation = decision ^ "-" ^ obligation ^ ".json"

(* Extract (decision_id, obligation_id list) pairs from one YAML
   file. Returns `None` when the YAML is not a parseable decision
   (waivers, obligations aggregators, or unparseable input). The
   parser uses `Decision.parse_decision_yaml` which applies the
   full kernel rule set AND normalises YAML scalars (intent as
   block-scalar -> {source, text} object, scope as object ->
   JSON array). We DO NOT swallow the error: this function is for
   the CLI's `--from=decisions` path, where the operator wants to
   know if a YAML rejected (silent drops would let unparseable
   brownfield YAMLs leak through). The caller (CLI) prints the
   diagnostics. *)
let[@warning "-32"] obligations_of_yaml ~reader ~path =
  let raw = reader path in
  if raw = "" then None
  else
    try
      let v = Codec.load_yaml_string raw in
      match Decision.parse_decision_yaml v with
      | Some d ->
          let obls =
            List.filter_map
              (fun (o : Domain.obligation) ->
                if o.id = "" then None else Some o.id)
              d.obligations
          in
          Some (d.id, obls)
      | None -> None
    with _ -> None

(* Walk a directory and return (decision_id, obligation_id) pairs
   for every parseable *.yaml / *.yml. The reader is supplied by
   the caller so the loader stays pure (kernel rule §1.3).
   Files that do not parse as a decision are skipped silently —
   the kernel calls them "aggregate files" (waivers, obligations
   aggregators) and they have their own validate path; emitting
   attestations for them is not in scope here. *)
let[@warning "-32"] scan_decisions_for_obligations ~reader ~root =
  if not (Sys.file_exists root) then []
  else if not (Sys.is_directory root) then []
  else
    let entries = try Array.to_list (Sys.readdir root) with _ -> [] in
    List.concat_map
      (fun name ->
        let sfx = Filename.extension name in
        if sfx = ".yaml" || sfx = ".yml" then
          let path = Filename.concat root name in
          match obligations_of_yaml ~reader ~path with
          | Some (d, obls) -> List.map (fun o -> (d, o)) obls
          | None -> []
        else [])
      entries
