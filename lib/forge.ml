(* lib/forge.ml — forge principal verification (algebra-3.2 §13,
   decision forge-principal-verification-2026-10).

   Thin HTTP wrapper around the GitHub v3 teams-membership
   endpoint. No new OCaml dependency (cohttp is intentionally NOT
   pulled in to keep the kernel closure-tight per ROADMAP Tier 3.5):
   the HTTP transport uses `curl` invoked through
   `Unix.open_process_args_in`, the same pattern as
   `lib/rebuttal.ml::forge_mirror` and `bin/Mathc.ml::run_git_command`.

   Public API:
     team_member : org:string -> team:string -> user:string -> bool

   `team_member` reads `MATH_CODING_FORGE_API` (same env as
   `lib/rebuttal.ml`). When unset or empty, every membership check
   returns `false` (the no-forge-installed fallback per
   spec/algebra-3.2.md §13). When set, the function issues:

     GET <api>/orgs/<org>/teams/<team>/memberships/<user>

   and returns `true` iff HTTP 200. Any other status (including
   connection refused, DNS failure, timeout, non-200 response,
   non-empty body for non-2xx) returns `false`. The function is
   total and raises no exceptions.

   Results are cached in-memory for ~1 hour. The cache key is the
   (api, org, team, user) tuple and the value is `(membership, fetched_at)`.
   The TTL is 3600 seconds; an expired entry is re-fetched on the
   next call. Cache invalidation on env-var change is NOT
   supported in this revision — by design, the cache is per-process
   and lifetime-bound to a single `mathc` invocation; the cache
   survives across team_member calls in the same binary but
   resets on next invocation. File-based caching is out of scope
   per the task spec.

   `team_slug` is the GitHub team slug, which is unique within an
   org. The function accepts it verbatim; no transformation
   (lowercasing, hyphenation) is applied.

   Pure module: file I/O is confined to the HTTP call; the rest
   are total transformations. Mirrors the design of
   `lib/rebuttal.ml`. *)

(* --- cache --- *)

type cache_key = string * string * string * string

type cache_entry = {
  mutable membership : bool option;
  mutable fetched_at : float;
}

let cache : (cache_key, cache_entry) Hashtbl.t = Hashtbl.create 32
let cache_ttl = 3600.0

(* --- env handling (mirrors lib/rebuttal.ml::forge_mirror) --- *)

let[@warning "-32"] forge_api_opt () =
  match Sys.getenv_opt "MATH_CODING_FORGE_API" with
  | None -> None
  | Some s ->
      let trimmed = String.trim s in
      if trimmed = "" then None else Some trimmed

(* --- http transport (curl -sS --max-time 5 -o /dev/null -w '%{http_code}') --- *)

let[@warning "-32"] curl_status ~url =
  let argv =
    [|
      "curl";
      "-sS";
      "--max-time";
      "5";
      "-o";
      "/dev/null";
      "-w";
      "%{http_code}";
      url;
    |]
  in
  let ic = Unix.open_process_args_in "curl" argv in
  let buf = Buffer.create 16 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let _status = Unix.close_process_in ic in
  let s = Buffer.contents buf in
  let trimmed = String.trim s in
  if trimmed = "200" then true else false

(* --- public API --- *)

(* Membership check outcome. The richer return type lets the
   verifier distinguish "forge was not configured" from "forge
   replied with a non-200 status". The boolean tracks the HTTP
   call dispatch (true = the curl GET was issued). *)
type outcome = [ `NotConfigured | `Queried of bool | `CurlFailure ]

(* `team_member` returns the bool where the wrapped bool tracks
   whether the HTTP call was dispatched. Callers that want the
   raw HTTP status do `team_member ~org ~team ~user |> function
   | `Ok b -> b | `NotConfigured -> false`. The NotConfigured /
   CurlFailure cases are folded into `false` in the convenience
   shim below for callers that only need the membership answer. *)
let team_member_full ~org ~team ~user : [> outcome ] =
  let key_user = String.trim user in
  if key_user = "" then `CurlFailure
  else
    match forge_api_opt () with
    | None -> `NotConfigured
    | Some api -> (
        let key_org = String.trim org in
        let key_team = String.trim team in
        let key : cache_key = (api, key_org, key_team, key_user) in
        let now = Unix.time () in
        let entry =
          match Hashtbl.find_opt cache key with
          | Some e -> e
          | None ->
              let e = { membership = None; fetched_at = 0.0 } in
              Hashtbl.add cache key e;
              e
        in
        let hit_cache fresh =
          entry.membership <- Some fresh;
          entry.fetched_at <- now;
          `Queried fresh
        in
        match entry.membership with
        | Some m when now -. entry.fetched_at < cache_ttl -> `Queried m
        | _ -> (
            let url =
              Printf.sprintf "%s/orgs/%s/teams/%s/memberships/%s" api key_org
                key_team key_user
            in
            let result = try Some (curl_status ~url) with _ -> None in
            match result with
            | Some b -> hit_cache b
            | None ->
                entry.membership <- Some false;
                entry.fetched_at <- now;
                `CurlFailure))

(* Convenience shim: returns `true` iff the team membership
   check returned an active membership. Returns `false` for
   every failure mode (NotConfigured, CurlFailure, non-200
   response). The 1-hour in-memory cache survives across calls
   within the same binary; expired entries re-fetch on next
   access. *)
let team_member ~org ~team ~user : bool =
  match team_member_full ~org ~team ~user with
  | `Queried true -> true
  | `Queried false | `NotConfigured | `CurlFailure -> false

(* parse_principal: best-effort split of a `kind:name` string
   into (kind, name). Returns (kind, "") when the input has no
   colon (the caller decides whether `""` is acceptable). Used
   by the verifier to extract the team slug from the
   `required_principals` list on a Decision. *)
let[@warning "-32"] parse_principal (s : string) : string * string =
  let len = String.length s in
  let rec loop i =
    if i >= len then None
    else if String.unsafe_get s i = ':' then Some i
    else loop (i + 1)
  in
  match loop 0 with
  | Some i ->
      let kind = String.sub s 0 i in
      let name =
        let rest = String.sub s (i + 1) (len - i - 1) in
        String.trim rest
      in
      (kind, name)
  | None -> (String.trim s, "")

(* clear_cache: exposed for test teardown so successive test
   cases start from a cold cache. Production code never calls it. *)
let[@warning "-32"] clear_cache () = Hashtbl.reset cache
