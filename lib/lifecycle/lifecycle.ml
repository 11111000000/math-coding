(* lib/lifecycle/lifecycle.ml — `mathc decision-state <id> <action>`
   implementation.

   The subcommand performs a targeted YAML edit on a single
   decision file: it rewrites the `state:` field and (when the
   action is `mark-superseded --by=<id>@<rev>`) adds the
   `superseded_by:` relation. The kernel parser
   (lib/decision.ml) is unchanged; the dispatcher in
   bin/Mathc.ml parses argv, calls `Lifecycle.transition` to
   produce the new YAML, writes the result back to disk, and
   runs `mathc validate` on the rewritten file. Exit codes
   follow OCAML_BEST_PRACTICES.md §4.3: 0 on accept, 1 on
   reject, 2 on input error.

   Pure module: no I/O. The dispatcher controls all filesystem
   access. The kebab-case id validator mirrors the one in
   lib/new_decision/new_decision.ml so the user gets an
   identical diagnostic for ill-formed ids.

   Decision (lifecycle-commands-2026-10): the user-facing
   names "obsolete" and "archive" are explicitly NOT accepted
   here. The 4-state enum in lib/codec.ml is normative per
   algebra §7; widening it for a single use case sets a
   precedent that grows unbounded. The CLI translates the
   user-facing idea to `Retired` / `Superseded` internally. *)

(* --- id validation ----------------------------------------------- *)

(* Matches schemas/decision.json pattern `^[a-z0-9][a-z0-9._-]{0,127}$`
   so the user-facing diagnostic matches the kernel's accept/reject.
   Note: the user's "kebab-case" mental model usually implies only
   `[a-z0-9-]`, but the live schema also allows `.` (used in
   semantic-versioning-style ids like `1-foo` and
   `schema-string-bump-3.0-alpha-to-3.3-2026-10`). The validator
   follows the schema, not the looser mental model. *)
let is_id_char c =
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '-' || c = '.'

let is_id_start c = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')

let validate_id id =
  let len = String.length id in
  if len = 0 then Error "decision id is empty"
  else if len > 128 then Error "decision id exceeds 128 chars"
  else if not (is_id_start id.[0]) then
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

(* --- input parsing --------------------------------------------- *)

(* The four-state enum (algebra §7). The user-facing name
   "obsolete" maps to Retired and "archive" to Superseded, but
   the CLI surface rejects those aliases (see the file
   preamble). The dispatcher only accepts `active | draft |
   retired | superseded` as user input. *)
type target_state = [ `Draft | `Active | `Retired | `Superseded ]

let state_to_string (s : target_state) =
  match s with
  | `Draft -> "draft"
  | `Active -> "active"
  | `Retired -> "retired"
  | `Superseded -> "superseded"

type action =
  | MarkSuperseded of { by : string }
  | MarkRetired
  | SetState of target_state

(* Compute the post-transition state from an action and the
   current state. Idempotent re-issue is a reject (exit 1),
   not a pass — this is the cram test case (c). The dispatcher
   surfaces the `AlreadyInState` error verbatim. *)
let next_state ~(current : target_state) (action : action) :
    (target_state, [> `AlreadyInState of target_state ]) result =
  match action with
  | MarkRetired ->
      if current = `Retired then Error (`AlreadyInState `Retired)
      else Ok `Retired
  | MarkSuperseded _ ->
      if current = `Superseded then Error (`AlreadyInState `Superseded)
      else Ok `Superseded
  | SetState s -> if s = current then Error (`AlreadyInState s) else Ok s

(* Parse the `--by=<id>@<rev>` argument. The grammar is one
   kebab-case decision id, then `@`, then a positive integer
   revision. Trailing whitespace is stripped. Returns the
   reconstructed string `id@rev` on success. *)
let parse_by_arg arg =
  let s = String.trim arg in
  match String.index_opt s '@' with
  | None -> Error ("--by=<id>@<rev> format: missing '@' separator in " ^ arg)
  | Some i -> (
      let id_part = String.sub s 0 i in
      let rev_part = String.sub s (i + 1) (String.length s - i - 1) in
      let validate_rev r =
        let len = String.length r in
        let rec loop j =
          if j >= len then Ok r
          else if r.[j] >= '0' && r.[j] <= '9' then loop (j + 1)
          else
            Error
              (Printf.sprintf
                 "--by=<id>@<rev> format: revision not an integer in %s" arg)
        in
        if len = 0 then
          Error
            (Printf.sprintf "--by=<id>@<rev> format: empty revision in %s" arg)
        else loop 0
      in
      match validate_id id_part with
      | Error m -> Error ("--by=<id>@<rev> format: " ^ m)
      | Ok id_str -> (
          match validate_rev rev_part with
          | Error m -> Error m
          | Ok rev_str -> Ok (id_str ^ "@" ^ rev_str)))

(* --- text-level YAML patcher ----------------------------------- *)

(* Replace the value of a top-level `state: <value>` line in
   raw YAML. We do not reformat whitespace or rewrite the
   front-matter — the line is searched line-by-line, and only
   the first `state:` at column 0 is replaced. The patched text
   preserves the original line ending and indentation, so the
   kernel validator (lib/decision.ml::body_canonical_sha256)
   recomputes a digest against a byte-faithful rewrite. *)
let[@warning "-32"] set_state_line (raw_state : string) (raw : string) : string
    =
  let target = Printf.sprintf "state: %s" raw_state in
  let lines = String.split_on_char '\n' raw in
  let rec scan acc replaced = function
    | [] -> String.concat "\n" (List.rev acc)
    | line :: rest ->
        if
          (not replaced)
          && String.length line >= 6
          && String.sub line 0 6 = "state:"
        then scan (target :: acc) true rest
        else scan (line :: acc) replaced rest
  in
  scan [] false lines

(* Add a `superseded_by:` block under the `relations:`
   section. If the section is absent, append a minimal one at
   the end. If the section exists and already has a
   `superseded_by:` line, that line is replaced in place.

   The dispatcher validates the post-condition via
   `mathc validate`. Idempotent re-issue is rejected upstream
   by `next_state`, so this function does not need to handle
   duplicate-`superseded_by` specially.

   Algorithm:
     1. Find the `relations:` line at column 0.
     2. Insert `  superseded_by:` + `    - <by>` lines
        immediately after `relations:`. The kernel accepts
        relations children in any order, so the position
        (first or last) does not affect acceptance.
     3. If a `superseded_by:` line is already present in the
        block, replace it instead of inserting.
     4. If `relations:` is absent, append a minimal
        `relations: ...` block at the end. *)
let[@warning "-32"] inject_superseded_by (by : string) (raw : string) : string =
  let head = "  superseded_by:" in
  let body = Printf.sprintf "    - %s" by in
  let lines = String.split_on_char '\n' raw in
  let rec find_relations (acc : string list) = function
    | [] -> None
    | line :: rest ->
        if line = "relations:" then Some (List.rev acc, line, rest)
        else find_relations (line :: acc) rest
  in
  match find_relations [] lines with
  | None ->
      (* No `relations:` section. Append a minimal one. The
         trailing newline on `lines` is preserved by
         `String.concat "\n"`. *)
      let tail = [ ""; "relations:"; head; body ] in
      String.concat "\n" lines ^ String.concat "\n" tail
  | Some (before, relations_line, after) ->
      (* `before` is the lines BEFORE the `relations:` line;
         `after` is the children (or empty). Insert our two
         lines right after `relations:` regardless of whether
         `after` already has a `superseded_by:`. If it does,
         we replace the existing one with the new head/body
         and drop any pre-existing `- <by>` line that follows
         it. *)
      let has_existing =
        List.exists
          (fun line ->
            String.length line >= String.length head
            && String.sub line 0 (String.length head) = head)
          after
      in
      let cleaned_after =
        if not has_existing then after
        else
          let rec drop acc = function
            | [] -> List.rev acc
            | line :: rest ->
                if
                  String.length line >= String.length head
                  && String.sub line 0 (String.length head) = head
                then begin
                  (* Drop the `superseded_by:` line AND the
                     immediately-following indented `- ...`
                     entry, if any. Stop at the next
                     relations-child line. *)
                  let rec drop_body acc = function
                    | [] -> List.rev acc
                    | line' :: rest' ->
                        let len = String.length line' in
                        if len > 0 && line'.[0] = ' ' && line'.[1] = ' ' then
                          drop_body acc rest'
                        else List.rev acc @ (line' :: rest')
                  in
                  drop (drop_body [] rest) []
                end
                else drop (line :: acc) rest
          in
          drop [] after
      in
      let new_after =
        match cleaned_after with
        | [] -> [ relations_line; head; body ]
        | first :: rest -> first :: head :: body :: rest
      in
      String.concat "\n" before ^ "\n" ^ String.concat "\n" new_after

(* --- transition ----------------------------------------------- *)

type result =
  | Transitioned of {
      new_state : target_state;
      new_yaml : string;
      diff_summary : string;
    }
  | Rejected of { reason : string; verdict_exit : int }

(* Compute the new YAML given an entry's source and an action.

   The function is pure: same source + same current + same
   action -> same result. No filesystem access, no Sys.*
   calls. The dispatcher writes the returned `new_yaml` to
   disk and runs `mathc validate` to confirm the kernel
   accepts the rewrite. *)
let transition ~(source : string) ~(current : target_state) (action : action) :
    result =
  match next_state ~current action with
  | Error (`AlreadyInState s) ->
      Rejected
        {
          reason =
            Printf.sprintf
              "decision already in state %s; no-op transitions are rejected"
              (state_to_string s);
          verdict_exit = 1;
        }
  | Ok new_state ->
      let new_yaml_str, summary =
        match action with
        | MarkSuperseded { by } ->
            ( inject_superseded_by by (set_state_line "superseded" source),
              Printf.sprintf "set state=superseded; added superseded_by: %s" by
            )
        | MarkRetired -> (set_state_line "retired" source, "set state=retired")
        | SetState s ->
            ( set_state_line (state_to_string s) source,
              Printf.sprintf "set state=%s" (state_to_string s) )
      in
      Transitioned
        { new_state; new_yaml = new_yaml_str; diff_summary = summary }
